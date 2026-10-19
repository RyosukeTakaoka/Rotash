/**
 * Rotash「◯◯が今日の1枚を撮りました」の送り役（Google Apps Script のウェブアプリ）。
 *
 * Firebase の Cloud Functions は従量課金（Blaze）でないと動かせないので、その代わり。
 * Apps Script は Google アカウントだけで無料で動き、カードの登録も要らない。
 * 置き方の手順は docs/PUSH_RELAY_SETUP.md。
 *
 * 流れ:
 *   1. 今日の1枚を撮ってサーバーに上げた端末が、ここへ「撮った」と知らせる（PushRelay.swift）
 *      送ってくるのは { idToken, inviteCode, dayIndex } だけ
 *      グループのひとことを送ったときは { idToken, inviteCode, kind: "message", messageID }（2026-10-19）
 *   2. idToken（匿名ログインの身分証）が本物かを Firebase に確かめ、送ってきた人の uid を得る
 *   3. Firestore からそのグループを読み、本当にその人が今日その枠を撮ったかを確かめる
 *      （ここで確かめるので、URL を知っている他人が勝手に通知を飛ばすことはできない）
 *   4. 撮った人以外のメンバーの宛先（devices/{uid}）を読み、Firebase Cloud Messaging（無料）で送る
 *   5. 同じ枠では1回しか送らない（撮り直しや、同期のたびに知らせが来ても重ねて送らない）
 *
 * スクリプト プロパティ（プロジェクトの設定 → スクリプト プロパティ）に入れるもの:
 *   SERVICE_ACCOUNT_JSON … Firebase のサービスアカウントの鍵（JSON をまるごと）。**誰にも渡さない**
 *   FIREBASE_API_KEY     … Firebase のウェブ API キー（アプリの SyncConfig.firebaseAPIKey と同じ）
 */

const BUNDLE_ID = "app.takaoka.com.Rorash";
const SCOPES = "https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging";
/** 撮ってからこれより時間が経った写真については送らない（古い枠で何度も鳴らされないように）。 */
const MAX_PHOTO_AGE_MS = 36 * 60 * 60 * 1000;
/** 送ったことを覚えておく日数。 */
const SENT_MEMORY_DAYS = 9;
/** 送ってからこれより時間が経ったひとことについては送らない。 */
const MAX_MESSAGE_AGE_MS = 30 * 60 * 1000;
/** 通知に載せるひとことの長さ。 */
const MESSAGE_PREVIEW_LENGTH = 80;

// ---------------------------------------------------------------------------
// 入口

function doPost(e) {
  try {
    const request = JSON.parse((e && e.postData && e.postData.contents) || "{}");
    return json_(handle_(request));
  } catch (error) {
    console.error(error);
    return json_({ ok: false, error: String((error && error.message) || error) });
  }
}

/** ブラウザで URL を開いたときに、動いていることだけ分かるように。 */
function doGet() {
  return json_({ ok: true, service: "rotash-push-relay" });
}

function handle_(request) {
  const props = PropertiesService.getScriptProperties();
  const apiKey = props.getProperty("FIREBASE_API_KEY");
  const accountText = props.getProperty("SERVICE_ACCOUNT_JSON");
  if (!apiKey || !accountText) throw new Error("script properties are not set");
  const account = JSON.parse(accountText);

  const code = String(request.inviteCode || "").toUpperCase();
  const isMessage = request.kind === "message";
  const dayIndex = Number(request.dayIndex);
  const messageID = String(request.messageID || "").toUpperCase();
  const validTarget = isMessage ? /^[0-9A-F-]{36}$/.test(messageID) : (dayIndex >= 0 && dayIndex <= 6);
  if (!/^[A-Z0-9]{6}$/.test(code) || !validTarget || !request.idToken) {
    return { ok: false, error: "bad request" };
  }

  const uid = verifyIdToken_(String(request.idToken), apiKey);
  if (!uid) return { ok: false, error: "unauthorized" };

  const accessToken = accessToken_(account);
  const projectId = account.project_id;
  const group = readGroup_(projectId, code, accessToken);
  if (!group) return { ok: false, error: "no such group" };

  const plan = isMessage
    ? planMessageNotification(group, uid, messageID, Date.now())
    : planNotification(group, uid, dayIndex, Date.now());
  if (!plan) return { ok: true, sent: 0, reason: "nothing to send" };

  // 同じ枠（同じひとこと）で2回送らない。同時に2つ届いても片方だけが通るよう、鍵をかけて確かめる。
  const sentKey = isMessage
    ? "sent:msg:" + code + "|" + messageID
    : "sent:" + code + "|" + plan.weekStart + "|" + dayIndex;
  const lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    if (props.getProperty(sentKey)) return { ok: true, sent: 0, reason: "already sent" };
    props.setProperty(sentKey, String(Date.now()));
    forgetOldSends_(props);
  } finally {
    lock.releaseLock();
  }

  const devices = readDevices_(projectId, plan.recipients, accessToken);
  const sent = isMessage
    ? sendAll_(projectId, devices, function (language) {
        return groupMessageText(language, plan.groupName, plan.senderName, plan.text);
      }, { inviteCode: code, kind: "message" }, accessToken)
    : sendAll_(projectId, devices, function (language) {
        return messageText(language, plan.groupName, plan.photographerName);
      }, { inviteCode: code, dayIndex: String(plan.dayIndex) }, accessToken);
  return { ok: true, sent: sent };
}

// ---------------------------------------------------------------------------
// 何を送るか（Apps Script に依存しない。tools/push-relay.test.js で確かめている）

/** まだグループにいるか（アプリの Member.isActive と同じ。抜けたあとに入り直した人もいる側）。 */
function isActive(member) {
  if (!member.leftAt) return true;
  return !!member.joinedAt && Date.parse(member.joinedAt) > Date.parse(member.leftAt);
}

/** 写真がある枠か（アプリの Slot.isFilled と同じ。取り消された枠は写真なし）。 */
function isFilled(slot) {
  return !!slot && !slot.withdrawnAt && !!slot.photoURL;
}

/**
 * 送る中身と宛先。送るべきでなければ null。
 *   - 知らせてきた人（uid）がまだグループにいる
 *   - 今週のその枠に写真があり、撮ったのがその人
 *   - 撮ってから時間が経ちすぎていない
 * 宛先は、撮った人以外のまだいるメンバーのうち、uid を持っている人（新しい版のアプリの人）。
 */
function planNotification(group, uid, dayIndex, now) {
  const members = group.members || [];
  const photographer = members.find(function (m) { return m.uid === uid && isActive(m); });
  if (!photographer) return null;

  const week = group.currentWeek || {};
  const slot = (week.slots || []).find(function (s) { return s.dayIndex === dayIndex; });
  if (!isFilled(slot) || slot.takenByMemberID !== photographer.id) return null;
  const capturedAt = Date.parse(slot.capturedAt || "");
  if (!(now - capturedAt <= MAX_PHOTO_AGE_MS)) return null;

  const recipients = [];
  members.forEach(function (m) {
    if (isActive(m) && m.uid && m.id !== photographer.id && recipients.indexOf(m.uid) < 0) recipients.push(m.uid);
  });
  if (recipients.length === 0) return null;

  return {
    weekStart: week.startDate,
    groupName: group.name || "ROTASH",
    photographerName: photographer.name || null,
    dayIndex: dayIndex,
    recipients: recipients,
  };
}

/**
 * ひとことの通知の中身と宛先。送るべきでなければ null。
 *   - 知らせてきた人（uid）がまだグループにいる
 *   - そのひとことがグループの状態に載っていて、送ったのがその人
 *   - 送ってから時間が経ちすぎていない
 * 宛先は、送った人以外のまだいるメンバーのうち、uid を持っている人。
 */
function planMessageNotification(group, uid, messageID, now) {
  const members = group.members || [];
  const sender = members.find(function (m) { return m.uid === uid && isActive(m); });
  if (!sender) return null;

  const message = (group.messages || []).find(function (m) {
    return String(m.id || "").toUpperCase() === messageID;
  });
  if (!message || message.senderID !== sender.id) return null;
  const sentAt = Date.parse(message.sentAt || "");
  if (!(now - sentAt <= MAX_MESSAGE_AGE_MS)) return null;

  const recipients = [];
  members.forEach(function (m) {
    if (isActive(m) && m.uid && m.id !== sender.id && recipients.indexOf(m.uid) < 0) recipients.push(m.uid);
  });
  if (recipients.length === 0) return null;

  const text = String(message.text || "");
  return {
    groupName: group.name || "ROTASH",
    senderName: sender.name || null,
    text: text.length > MESSAGE_PREVIEW_LENGTH ? text.slice(0, MESSAGE_PREVIEW_LENGTH) + "…" : text,
    recipients: recipients,
  };
}

/** ひとことの通知の本文（「AKI: 今日の空きれい」）。 */
function groupMessageText(language, groupName, senderName, text) {
  const who = (senderName || "").toUpperCase();
  return { title: groupName, body: who ? who + ": " + text : text };
}

/** 端末の言語に合わせた本文。 */
function messageText(language, groupName, photographerName) {
  const who = (photographerName || "").toUpperCase();
  switch (language) {
    case "ja":
      return { title: groupName, body: who ? who + " が今日の1枚を撮りました" : "今日の1枚が撮られました" };
    case "ko":
      return { title: groupName, body: who ? who + " 님이 오늘의 한 장을 찍었어요" : "오늘의 한 장이 찍혔어요" };
    default:
      return { title: groupName, body: who ? who + " took today's photo" : "Today's photo is in" };
  }
}

// ---------------------------------------------------------------------------
// Firebase とのやりとり

/** 匿名ログインの身分証を Firebase に確かめて、uid を返す。偽物なら null。 */
function verifyIdToken_(idToken, apiKey) {
  const response = UrlFetchApp.fetch(
    "https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=" + encodeURIComponent(apiKey),
    {
      method: "post",
      contentType: "application/json",
      // API キーを「iOS アプリだけ」に制限していても通るように、アプリの名乗りを添える。
      headers: { "X-Ios-Bundle-Identifier": BUNDLE_ID },
      payload: JSON.stringify({ idToken: idToken }),
      muteHttpExceptions: true,
    }
  );
  if (response.getResponseCode() !== 200) return null;
  const users = JSON.parse(response.getContentText()).users || [];
  return users.length > 0 ? users[0].localId : null;
}

/** サービスアカウントの鍵で、Firestore と Cloud Messaging を使うための合鍵（1時間有効）を作る。 */
function accessToken_(account) {
  const cache = CacheService.getScriptCache();
  const cached = cache.get("access_token");
  if (cached) return cached;

  const now = Math.floor(Date.now() / 1000);
  const header = base64Url_(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url_(JSON.stringify({
    iss: account.client_email,
    scope: SCOPES,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = header + "." + claims;
  const signature = base64Url_(Utilities.computeRsaSha256Signature(unsigned, account.private_key));
  const response = UrlFetchApp.fetch("https://oauth2.googleapis.com/token", {
    method: "post",
    payload: {
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: unsigned + "." + signature,
    },
  });
  const token = JSON.parse(response.getContentText()).access_token;
  cache.put("access_token", token, 3000); // 50分（有効期限より少し短く）
  return token;
}

function base64Url_(value) {
  return Utilities.base64EncodeWebSafe(value).replace(/=+$/, "");
}

function documentsURL_(projectId) {
  return "https://firestore.googleapis.com/v1/projects/" + projectId + "/databases/(default)/documents/";
}

/** rotash/{招待コード} の payload（アプリの RemoteGroupState の JSON）を読む。 */
function readGroup_(projectId, code, accessToken) {
  const response = UrlFetchApp.fetch(documentsURL_(projectId) + "rotash/" + code, {
    headers: { Authorization: "Bearer " + accessToken },
    muteHttpExceptions: true,
  });
  if (response.getResponseCode() !== 200) return null;
  const fields = JSON.parse(response.getContentText()).fields || {};
  const payload = fields.payload && fields.payload.stringValue;
  if (!payload) return null;
  try {
    return JSON.parse(payload);
  } catch (error) {
    return null;
  }
}

/** 宛先の端末（devices/{uid} の token と language）。置いていない人は飛ばす。 */
function readDevices_(projectId, uids, accessToken) {
  const requests = uids.map(function (uid) {
    return {
      url: documentsURL_(projectId) + "devices/" + encodeURIComponent(uid),
      headers: { Authorization: "Bearer " + accessToken },
      muteHttpExceptions: true,
    };
  });
  const responses = requests.length > 0 ? UrlFetchApp.fetchAll(requests) : [];
  const devices = [];
  responses.forEach(function (response, index) {
    if (response.getResponseCode() !== 200) return;
    const fields = JSON.parse(response.getContentText()).fields || {};
    const token = fields.token && fields.token.stringValue;
    if (!token) return;
    devices.push({
      uid: uids[index],
      token: token,
      language: (fields.language && fields.language.stringValue) || "en",
    });
  });
  return devices;
}

/**
 * Cloud Messaging で送る。もう使われていない宛先（アプリを消した等）は消しておく。送れた数を返す。
 * textFor(language) は { title, body } を返す。data は通知に添える値（アプリが開いたときに使う）。
 */
function sendAll_(projectId, devices, textFor, data, accessToken) {
  if (devices.length === 0) return 0;
  const requests = devices.map(function (device) {
    const text = textFor(device.language);
    return {
      url: "https://fcm.googleapis.com/v1/projects/" + projectId + "/messages:send",
      method: "post",
      contentType: "application/json",
      headers: { Authorization: "Bearer " + accessToken },
      muteHttpExceptions: true,
      payload: JSON.stringify({
        message: {
          token: device.token,
          notification: text,
          apns: { payload: { aps: { sound: "default" } } },
          data: data,
        },
      }),
    };
  });
  let sent = 0;
  const stale = [];
  UrlFetchApp.fetchAll(requests).forEach(function (response, index) {
    const status = response.getResponseCode();
    if (status === 200) {
      sent += 1;
    } else if (status === 404 || response.getContentText().indexOf("UNREGISTERED") >= 0) {
      stale.push(devices[index].uid);
    } else {
      console.warn("FCM " + status + ": " + response.getContentText());
    }
  });
  stale.forEach(function (uid) {
    UrlFetchApp.fetch(documentsURL_(projectId) + "devices/" + encodeURIComponent(uid), {
      method: "delete",
      headers: { Authorization: "Bearer " + accessToken },
      muteHttpExceptions: true,
    });
  });
  return sent;
}

/** 送った記録のうち、古いものを消す（スクリプト プロパティには容量の上限があるので）。 */
function forgetOldSends_(props) {
  const all = props.getProperties();
  const limit = Date.now() - SENT_MEMORY_DAYS * 24 * 60 * 60 * 1000;
  Object.keys(all).forEach(function (key) {
    if (key.indexOf("sent:") === 0 && Number(all[key]) < limit) props.deleteProperty(key);
  });
}

function json_(value) {
  return ContentService.createTextOutput(JSON.stringify(value)).setMimeType(ContentService.MimeType.JSON);
}

// ---------------------------------------------------------------------------
// 手で確かめる用（エディタで選んで ▶ 実行）。鍵が正しく入っていれば、合鍵が作れて "OK" と出る。

function checkSetup() {
  const props = PropertiesService.getScriptProperties();
  const account = JSON.parse(props.getProperty("SERVICE_ACCOUNT_JSON"));
  const token = accessToken_(account);
  console.log(token ? "OK: " + account.project_id : "NG");
}

// Rotash の Cloud Functions（第2世代）。docs/FIREBASE_SETUP.md の手順でデプロイする。
//
// 今日の1枚が撮られたら、撮った人以外のメンバーへ「◯◯が今日の1枚を撮りました」を送る。
// アプリはグループの状態を rotash/{招待コード} に JSON 1個（payload）で書くので、
// 書き換わるたびに前後を比べ、新しく写真が入った枠だけを知らせる（newPhotos.js）。
//
// 宛先は devices/{uid}（アプリが置く FCM トークン）。uid はメンバーの uid（匿名ログイン）。

const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const { parsePayload, newlyFilledSlots, notificationFor, messageText } = require("./newPhotos");

admin.initializeApp();

exports.notifyNewPhoto = onDocumentWritten(
  { document: "rotash/{code}", region: "asia-northeast1" },
  async (event) => {
    const beforeDoc = event.data && event.data.before;
    const afterDoc = event.data && event.data.after;
    if (!afterDoc || !afterDoc.exists) return;

    const before = beforeDoc && beforeDoc.exists ? parsePayload(beforeDoc.get("payload")) : null;
    const after = parsePayload(afterDoc.get("payload"));
    if (!after) return;

    const slots = newlyFilledSlots(before, after);
    if (slots.length === 0) return;

    const db = admin.firestore();
    for (const slot of slots) {
      const note = notificationFor(after, slot);
      if (note.recipients.length === 0) continue;

      const devices = await Promise.all(note.recipients.map((uid) => db.collection("devices").doc(uid).get()));
      const messages = devices
        .filter((doc) => doc.exists && doc.get("token"))
        .map((doc) => {
          const text = messageText(doc.get("language"), note.groupName, note.photographerName);
          return {
            token: doc.get("token"),
            notification: text,
            apns: { payload: { aps: { sound: "default" } } },
            data: { inviteCode: event.params.code, dayIndex: String(note.dayIndex) },
          };
        });
      if (messages.length === 0) continue;

      const result = await admin.messaging().sendEach(messages);
      // もう使われていないトークン（アプリを消した等）は消しておく。
      await Promise.all(
        result.responses.map((response, index) => {
          const code = response.error && response.error.code;
          if (code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token") {
            const uid = devices.filter((doc) => doc.exists && doc.get("token"))[index].id;
            return db.collection("devices").doc(uid).delete();
          }
          return null;
        })
      );
      logger.info("notified", { code: event.params.code, day: note.dayIndex, sent: result.successCount });
    }
  }
);

// 書き換わる前と後のグループの状態から、「新しく撮られた枠」を取り出す。
// Firebase に依存しない純粋な関数にしてあるので、node --test でそのまま確かめられる（newPhotos.test.js）。
//
// 状態はアプリの RemoteGroupState を JSON にしたもの（payload）。日付は ISO8601 の文字列。

/** payload の文字列を読む。読めなければ null。 */
function parsePayload(text) {
  if (typeof text !== "string") return null;
  try {
    return JSON.parse(text);
  } catch (e) {
    return null;
  }
}

/** 写真がある枠か（アプリの Slot.isFilled と同じ。取り消された枠は写真なし）。 */
function isFilled(slot) {
  return !!slot && !slot.withdrawnAt && !!slot.photoURL;
}

/**
 * 今週のうち、前は写真が無く、後で写真が入った枠。
 * 週が切り替わった（startDate が違う）ときは、前の週の枠と比べない（新しい週の枠は全部まだ空のはず）。
 * 撮り直し（同じ枠に新しい写真）は数えない。最初の1枚だけを知らせる。
 */
function newlyFilledSlots(before, after) {
  if (!after || !after.currentWeek) return [];
  const afterWeek = after.currentWeek;
  const beforeWeek =
    before && before.currentWeek && before.currentWeek.startDate === afterWeek.startDate
      ? before.currentWeek
      : null;
  const beforeSlots = new Map(((beforeWeek && beforeWeek.slots) || []).map((s) => [s.dayIndex, s]));
  return (afterWeek.slots || []).filter((slot) => isFilled(slot) && !isFilled(beforeSlots.get(slot.dayIndex)));
}

/** まだグループにいるか（アプリの Member.isActive と同じ。抜けたあとに入り直した人もいる側）。 */
function isActive(member) {
  if (!member.leftAt) return true;
  return !!member.joinedAt && Date.parse(member.joinedAt) > Date.parse(member.leftAt);
}

/**
 * 1枚ぶんの知らせの宛先と中身。
 * 宛先は、まだ抜けていないメンバーのうち、撮った本人以外で、uid を持っている人。
 */
function notificationFor(group, slot) {
  const members = group.members || [];
  const photographer = members.find((m) => m.id === slot.takenByMemberID);
  const recipients = members
    .filter((m) => isActive(m) && m.uid && m.id !== slot.takenByMemberID)
    .map((m) => m.uid);
  return {
    recipients: Array.from(new Set(recipients)),
    groupName: group.name || "ROTASH",
    photographerName: photographer ? photographer.name : null,
    dayIndex: slot.dayIndex,
  };
}

/** 端末の言語に合わせた本文。 */
function messageText(language, groupName, photographerName) {
  const who = (photographerName || "").toUpperCase();
  switch (language) {
    case "ja":
      return { title: groupName, body: who ? `${who} が今日の1枚を撮りました` : "今日の1枚が撮られました" };
    case "ko":
      return { title: groupName, body: who ? `${who} 님이 오늘의 한 장을 찍었어요` : "오늘의 한 장이 찍혔어요" };
    default:
      return { title: groupName, body: who ? `${who} took today's photo` : "Today's photo is in" };
  }
}

module.exports = { parsePayload, isFilled, isActive, newlyFilledSlots, notificationFor, messageText };

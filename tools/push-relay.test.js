// tools/push-relay.gs の「何を送るか」の部分を Node で確かめる（Apps Script の外でも動く関数だけ）。
//   node --test tools/push-relay.test.js
const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const context = {};
vm.createContext(context);
vm.runInContext(fs.readFileSync(path.join(__dirname, "push-relay.gs"), "utf8"), context);
const { planNotification, planMessageNotification, groupMessageText, messageText, isActive } = context;

const now = Date.parse("2026-10-15T12:00:00Z");
const group = (slots, members) => ({
  name: "友達",
  members,
  currentWeek: { startDate: "2026-10-12T00:00:00Z", slots },
});
const members = [
  { id: "A", name: "aki", uid: "uA" },
  { id: "B", name: "ben", uid: "uB" },
  { id: "C", name: "cho", uid: "uC", leftAt: "2026-10-10T00:00:00Z" },
  { id: "D", name: "dan" },
  { id: "E", name: "eri", uid: "uE", leftAt: "2026-10-10T00:00:00Z", joinedAt: "2026-10-13T00:00:00Z" },
];
const photo = (extra) => Object.assign(
  { dayIndex: 3, photoURL: "https://x", takenByMemberID: "A", capturedAt: "2026-10-15T09:00:00Z" }, extra);

test("the photographer's friends who are still in the group get it", () => {
  const plan = planNotification(group([photo()], members), "uA", 3, now);
  assert.deepStrictEqual(Array.from(plan.recipients), ["uB", "uE"]);
  assert.strictEqual(plan.photographerName, "aki");
  assert.strictEqual(plan.weekStart, "2026-10-12T00:00:00Z");
});

test("someone else cannot ring the bell for a photo they did not take", () => {
  assert.strictEqual(planNotification(group([photo()], members), "uB", 3, now), null);
  assert.strictEqual(planNotification(group([photo()], members), "unknown", 3, now), null);
});

test("no photo, a withdrawn photo, or an old photo sends nothing", () => {
  assert.strictEqual(planNotification(group([{ dayIndex: 3 }], members), "uA", 3, now), null);
  assert.strictEqual(planNotification(group([photo({ withdrawnAt: "2026-10-15T10:00:00Z" })], members), "uA", 3, now), null);
  assert.strictEqual(planNotification(group([photo({ capturedAt: "2026-10-12T09:00:00Z" })], members), "uA", 3, now), null);
  assert.strictEqual(planNotification(group([photo()], members), "uA", 4, now), null);
});

test("someone who left cannot send", () => {
  assert.strictEqual(planNotification(group([photo({ takenByMemberID: "C" })], members), "uC", 3, now), null);
});

test("people who rejoined after leaving count as members", () => {
  assert.strictEqual(isActive(members[4]), true);
  assert.strictEqual(isActive(members[2]), false);
});

test("text follows the device language", () => {
  assert.strictEqual(messageText("ja", "G", "aki").body, "AKI が今日の1枚を撮りました");
  assert.strictEqual(messageText("ko", "G", "aki").body, "AKI 님이 오늘의 한 장을 찍었어요");
  assert.strictEqual(messageText("fr", "G", null).body, "Today's photo is in");
});

// グループのひとこと（2026-10-19）
const messageID = "0F8E6A2C-1B3D-4E5F-8A9B-0C1D2E3F4A5B";
const withMessages = (messages) => Object.assign(group([], members), { messages });
const message = (extra) => Object.assign(
  { id: messageID, senderID: "A", text: "今日の空きれい", sentAt: "2026-10-15T11:50:00Z" }, extra);

test("a message goes to everyone else who is still in the group", () => {
  const plan = planMessageNotification(withMessages([message()]), "uA", messageID, now);
  assert.deepStrictEqual(Array.from(plan.recipients), ["uB", "uE"]);
  assert.strictEqual(plan.senderName, "aki");
  assert.strictEqual(plan.text, "今日の空きれい");
});

test("someone else cannot ring the bell for a message they did not send", () => {
  assert.strictEqual(planMessageNotification(withMessages([message()]), "uB", messageID, now), null);
  assert.strictEqual(planMessageNotification(withMessages([message({ senderID: "C" })]), "uC", messageID, now), null);
});

test("an unknown, missing or old message sends nothing", () => {
  assert.strictEqual(planMessageNotification(withMessages([message()]), "uA", "00000000-0000-0000-0000-000000000000", now), null);
  assert.strictEqual(planMessageNotification(group([], members), "uA", messageID, now), null);
  assert.strictEqual(planMessageNotification(withMessages([message({ sentAt: "2026-10-15T10:00:00Z" })]), "uA", messageID, now), null);
});

test("a long message is cut in the notification", () => {
  const plan = planMessageNotification(withMessages([message({ text: "あ".repeat(120) })]), "uA", messageID, now);
  assert.strictEqual(plan.text.length, 81);
  assert.strictEqual(groupMessageText("ja", "G", "aki", "hi").body, "AKI: hi");
});

const test = require("node:test");
const assert = require("node:assert");
const { newlyFilledSlots, notificationFor, messageText } = require("./newPhotos");

const week = (start, slots) => ({ startDate: start, slots });
const members = [
  { id: "A", name: "aki", uid: "uA" },
  { id: "B", name: "ben", uid: "uB" },
  { id: "C", name: "cho", uid: "uC", leftAt: "2026-10-10T00:00:00Z" },
  { id: "D", name: "dan" },
];

test("a slot that just got its first photo is reported", () => {
  const before = { currentWeek: week("W", [{ dayIndex: 2 }]) };
  const after = { currentWeek: week("W", [{ dayIndex: 2, photoURL: "x", takenByMemberID: "A" }]) };
  assert.deepStrictEqual(newlyFilledSlots(before, after).map((s) => s.dayIndex), [2]);
});

test("a retake or an unchanged photo is not reported again", () => {
  const before = { currentWeek: week("W", [{ dayIndex: 2, photoURL: "x" }]) };
  const after = { currentWeek: week("W", [{ dayIndex: 2, photoURL: "y" }]) };
  assert.strictEqual(newlyFilledSlots(before, after).length, 0);
});

test("withdrawn photos are not photos", () => {
  const before = { currentWeek: week("W", [{ dayIndex: 2 }]) };
  const after = { currentWeek: week("W", [{ dayIndex: 2, photoURL: "x", withdrawnAt: "t" }]) };
  assert.strictEqual(newlyFilledSlots(before, after).length, 0);
});

test("a new week is compared with nothing", () => {
  const before = { currentWeek: week("W1", [{ dayIndex: 0, photoURL: "x" }]) };
  const after = { currentWeek: week("W2", [{ dayIndex: 0, photoURL: "z" }]) };
  assert.deepStrictEqual(newlyFilledSlots(before, after).map((s) => s.dayIndex), [0]);
});

test("recipients exclude the photographer, people who left, and people without a uid", () => {
  const n = notificationFor({ name: "G", members }, { dayIndex: 1, takenByMemberID: "A" });
  assert.deepStrictEqual(n.recipients, ["uB"]);
  assert.strictEqual(n.photographerName, "aki");
});

test("text follows the device language", () => {
  assert.strictEqual(messageText("ja", "G", "aki").body, "AKI が今日の1枚を撮りました");
  assert.strictEqual(messageText("fr", "G", null).body, "Today's photo is in");
});

test("someone who left and joined again gets notified again", () => {
  const rejoined = [
    { id: "A", name: "aki", uid: "uA" },
    { id: "C", name: "cho", uid: "uC", leftAt: "2026-10-10T00:00:00Z", joinedAt: "2026-10-12T09:00:00Z" },
  ];
  const n = notificationFor({ name: "G", members: rejoined }, { dayIndex: 1, takenByMemberID: "A" });
  assert.deepStrictEqual(n.recipients, ["uC"]);
});

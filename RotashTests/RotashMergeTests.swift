import XCTest
@testable import Rotash

/// 同期の突き合わせ。いちばん壊れてほしくないところ（写真を落とさない・端末どうしで同じ答えになる）。
final class RotashMergeTests: XCTestCase {

    private let a = UUID()
    private let b = UUID()

    func testPhotoOnOnlyOneSideIsKept() {
        let photo = Fixture.photo(day: 0, by: a, at: Fixture.date(day: 0, hour: 9))
        let merged = RotashMerge.merge(local: Fixture.week([photo]), remote: Fixture.week([Slot(dayIndex: 0)]))
        XCTAssertEqual(merged.slot(at: 0)?.photoURL, photo.photoURL)

        let mergedOther = RotashMerge.merge(local: Fixture.week([Slot(dayIndex: 0)]), remote: Fixture.week([photo]))
        XCTAssertEqual(mergedOther.slot(at: 0)?.photoURL, photo.photoURL)
    }

    func testEarlierPhotoWinsOnBothDevices() {
        let early = Fixture.photo(day: 1, by: a, at: Fixture.date(day: 1, hour: 9), url: "early")
        let late = Fixture.photo(day: 1, by: b, at: Fixture.date(day: 1, hour: 10), url: "late")
        XCTAssertEqual(RotashMerge.merge(local: Fixture.week([early]), remote: Fixture.week([late])).slot(at: 1)?.photoURL, "early")
        XCTAssertEqual(RotashMerge.merge(local: Fixture.week([late]), remote: Fixture.week([early])).slot(at: 1)?.photoURL, "early")
    }

    func testRetakeOfTheSameShotWins() {
        let first = Fixture.photo(day: 2, by: a, at: Fixture.date(day: 2, hour: 9), url: "first")
        var retaken = first
        retaken.photoURL = "retaken"
        retaken.retakeCount = 1
        XCTAssertEqual(RotashMerge.merge(local: Fixture.week([first]), remote: Fixture.week([retaken])).slot(at: 2)?.photoURL, "retaken")
    }

    func testWithdrawnMarkWinsOverAPhotoOnEitherSide() {
        let photo = Fixture.photo(day: 3, by: a, at: Fixture.date(day: 3, hour: 9))
        let withdrawn = RotashMerge.withdrawn(photo, at: Fixture.date(day: 4, hour: 9))

        for (local, remote) in [(photo, withdrawn), (withdrawn, photo)] {
            let merged = RotashMerge.merge(local: Fixture.week([local]), remote: Fixture.week([remote])).slot(at: 3)
            XCTAssertNotNil(merged?.withdrawnAt)
            XCTAssertNil(merged?.photoURL)
            XCTAssertFalse(merged?.isFilled ?? true)
        }
    }

    func testNewerAssignmentWins() {
        var old = Slot(dayIndex: 4)
        old.assigneeID = a
        old.assignedAt = Fixture.date(day: 0, hour: 0)
        var new = Slot(dayIndex: 4)
        new.assigneeID = b
        new.assignedAt = Fixture.date(day: 1, hour: 0)
        XCTAssertEqual(RotashMerge.merge(local: Fixture.week([old]), remote: Fixture.week([new])).slot(at: 4)?.assigneeID, b)
        XCTAssertEqual(RotashMerge.merge(local: Fixture.week([new]), remote: Fixture.week([old])).slot(at: 4)?.assigneeID, b)
    }

    func testTieIsBrokenTheSameWayOnBothDevices() {
        let at = Fixture.date(day: 0, hour: 0)
        var x = Slot(dayIndex: 5)
        x.assigneeID = a
        x.assignedAt = at
        var y = Slot(dayIndex: 5)
        y.assigneeID = b
        y.assignedAt = at
        let one = RotashMerge.merge(local: Fixture.week([x]), remote: Fixture.week([y])).slot(at: 5)?.assigneeID
        let other = RotashMerge.merge(local: Fixture.week([y]), remote: Fixture.week([x])).slot(at: 5)?.assigneeID
        XCTAssertEqual(one, other)
    }

    func testJoinTimeUIDAndLeftMarkSurviveAnOlderAppWritingBack() {
        let joinedAt = Fixture.date(day: 2, hour: 12)
        let me = Member(id: a, name: "aki", joinedAt: joinedAt, uid: "uid-a")
        let friend = Member(id: b, name: "ben", leftAt: Fixture.date(day: 3, hour: 8))
        let local = RotashGroup(name: "G", inviteCode: "ABC234", members: [me, friend], myMemberID: a,
                                currentWeek: Fixture.fullWeek(assignees: [a, b]))

        // 古い版のアプリは joinedAt・uid・leftAt を知らないので、書き戻すと消えている。
        var remote = RemoteGroupState(group: local)
        remote.members = [Member(id: a, name: "aki"), Member(id: b, name: "ben")]

        let merged = RotashMerge.merge(local: local, remote: remote)
        XCTAssertEqual(merged.me?.joinedAt, joinedAt)
        XCTAssertEqual(merged.me?.uid, "uid-a")
        XCTAssertNotNil(merged.member(withID: b)?.leftAt)
    }

    func testRejoinedMemberStaysActiveWhenAnotherDeviceStillHasTheLeftMark() {
        let leftAt = Fixture.date(day: 1, hour: 9)
        let rejoinedAt = Fixture.date(day: 3, hour: 9)
        // 入り直した本人の端末が、新しい名前と入った時刻でサーバーに載せた状態。
        let rejoined = RotashGroup(name: "G", inviteCode: "ABC234",
                                   members: [Member(id: a, name: "aki"),
                                             Member(id: b, name: "ben2", joinedAt: rejoinedAt, uid: "uid-b")],
                                   myMemberID: b, currentWeek: Fixture.fullWeek(assignees: [a, b]))
        // まだ「抜けた」印しか知らない友達の端末。
        let friend = RotashGroup(name: "G", inviteCode: "ABC234",
                                 members: [Member(id: a, name: "aki"),
                                           Member(id: b, name: "—", leftAt: leftAt, uid: "uid-b")],
                                 myMemberID: a, currentWeek: Fixture.fullWeek(assignees: [a, b]))

        let onFriend = RotashMerge.merge(local: friend, remote: RemoteGroupState(group: rejoined))
        XCTAssertTrue(onFriend.member(withID: b)?.isActive ?? false)
        XCTAssertNil(onFriend.member(withID: b)?.leftAt)

        // 友達の端末が古い印を書き戻しても、入り直した本人の端末では本人のまま（名前も今回のもの）。
        var stale = RemoteGroupState(group: friend)
        stale.members = [Member(id: a, name: "aki"), Member(id: b, name: "—", leftAt: leftAt, uid: "uid-b")]
        let onRejoined = RotashMerge.merge(local: rejoined, remote: stale)
        XCTAssertTrue(onRejoined.me?.isActive ?? false)
        XCTAssertEqual(onRejoined.me?.name, "ben2")
        XCTAssertEqual(onRejoined.me?.joinedAt, rejoinedAt)
    }

    func testPhotoTakenAfterAWithdrawalOnTheSameDayIsKept() {
        let old = Fixture.photo(day: 2, by: a, at: Fixture.date(day: 2, hour: 9), url: "old")
        let tombstone = RotashMerge.withdrawn(old, at: Fixture.date(day: 2, hour: 10))
        // 取り消された日の番が入った人に渡り、その人が撮った。
        var fresh = Fixture.photo(day: 2, by: b, at: Fixture.date(day: 2, hour: 11), url: "fresh")
        fresh.withdrawnAt = nil

        for (local, remote) in [(fresh, tombstone), (tombstone, fresh)] {
            let merged = RotashMerge.merge(local: Fixture.week([local]), remote: Fixture.week([remote])).slot(at: 2)
            XCTAssertEqual(merged?.photoURL, "fresh")
            XCTAssertNil(merged?.withdrawnAt)
        }
        // 古い端末が持っていた取り消し前の写真は、戻らない。
        let merged = RotashMerge.merge(local: Fixture.week([old]), remote: Fixture.week([tombstone])).slot(at: 2)
        XCTAssertNil(merged?.photoURL)
    }

    func testWithdrawingMarksEverySlotOfThatPersonOnly() {
        var week = Fixture.week([
            Fixture.photo(day: 0, by: a, at: Fixture.date(day: 0, hour: 9)),
            Fixture.photo(day: 1, by: b, at: Fixture.date(day: 1, hour: 9)),
        ])
        week.slots.append(Slot(dayIndex: 2))
        let group = RotashGroup(name: "G", inviteCode: "ABC234",
                                members: [Member(id: a, name: "aki"), Member(id: b, name: "ben")],
                                myMemberID: a, currentWeek: week)
        var remote = RemoteGroupState(group: group)
        XCTAssertEqual(remote.slotsTaken(by: a), 1)

        remote.withdrawPhotos(of: a, at: Fixture.date(day: 3, hour: 9))
        XCTAssertEqual(remote.slotsTaken(by: a), 0)
        XCTAssertNotNil(remote.currentWeek.slot(at: 0)?.withdrawnAt)
        XCTAssertTrue(remote.currentWeek.slot(at: 1)?.isFilled ?? false)
    }

    func testWeekWithOnlyWithdrawnMarksIsKeptButNotShown() {
        let photo = Fixture.photo(day: 0, by: a, at: Fixture.date(day: 0, hour: 9))
        let week = Fixture.week([RotashMerge.withdrawn(photo, at: Fixture.date(day: 1, hour: 9))])
        // 取り消しの印しか残っていない週も、データとしては捨てない（捨てると古い端末から写真が戻る）。
        XCTAssertTrue(week.isWorthKeeping)
        XCTAssertEqual(week.filledCount, 0)

        var group = RotashGroup(name: "G", inviteCode: "ABC234", members: [Member(id: a, name: "aki")],
                                myMemberID: a, currentWeek: Fixture.fullWeek(assignees: [a]))
        group.archive = [week]
        // でも Memories には出さない。
        XCTAssertTrue(group.memories.isEmpty)
    }
}

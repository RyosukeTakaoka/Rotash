import XCTest
@testable import Rotash

/// 招待リンクと、貼り付けたコードの読み取り。
final class RotashLinkTests: XCTestCase {

    func testCustomSchemeStillWorks() {
        XCTAssertEqual(RotashLink.destination(for: URL(string: "rotash://join/ABC234")!), .join(code: "ABC234"))
    }

    func testWebLinksAreIgnored() {
        XCTAssertNil(RotashLink.destination(for: URL(string: "https://example.com/j/ABC234")!))
    }

    func testPastedInviteMessageGivesTheCode() {
        XCTAssertEqual(RotashLink.code(fromPasted: "Rotash で一緒に写真を撮ろう。\n招待コード XYZ789"), "XYZ789")
        XCTAssertEqual(RotashLink.code(fromPasted: "Join my group on Rotash.\nInvite code XYZ789"), "XYZ789")
        // App Store のリンクが添えられた招待の文章（公開後）。
        XCTAssertEqual(RotashLink.code(fromPasted: "Rotash で一緒に写真を撮ろう。\n招待コード XYZ789\nアプリ: https://apps.apple.com/jp/app/rotash/id6700000000"), "XYZ789")
        XCTAssertEqual(RotashLink.code(fromPasted: "rotash://join/XYZ789"), "XYZ789")
        XCTAssertEqual(RotashLink.code(fromPasted: " xyz789 "), "XYZ789")
        XCTAssertNil(RotashLink.code(fromPasted: "こんにちは"))
    }
}

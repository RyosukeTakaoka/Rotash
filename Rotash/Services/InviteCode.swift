import Foundation

enum InviteCode {
    /// 見間違えやすい文字（0/O, 1/I など）を除いた 6 桁。
    private static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func generate(length: Int = 6) -> String {
        String((0..<length).map { _ in alphabet.randomElement() ?? "A" })
    }

    static func normalize(_ raw: String) -> String {
        raw.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .filter { alphabet.contains($0) }
    }

    static func isValid(_ raw: String) -> Bool {
        normalize(raw).count == 6
    }
}

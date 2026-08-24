import SwiftUI

/// まだ Rotash が無いときの横向き。
struct LandscapeEmptyView: View {
    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: 18) {
                Text("ROTASH")
                    .font(Typo.wordmark(28))
                    .tracking(10)
                    .foregroundStyle(Palette.text)
                Text("縦にして Rotash をはじめる")
                    .rotashLabel(11, color: Palette.dim, tracking: 2)
            }
        }
    }
}

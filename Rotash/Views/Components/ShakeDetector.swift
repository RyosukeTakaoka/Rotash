import SwiftUI
import UIKit

extension Notification.Name {
    /// スマホを振った。横画面の7分割はこれで作品ごと裏返る（`ThisWeekView`）。
    static let rotashDeviceShaken = Notification.Name("rotash.deviceShaken")
}

extension UIWindow {
    /// 振ったことを、画面のどこからでも受け取れるように知らせる。
    /// SwiftUI には「振った」を受け取る仕組みが無いので、いちばん外側の窓で拾う。
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .rotashDeviceShaken, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

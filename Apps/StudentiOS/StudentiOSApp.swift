import MobileShell
import SwiftUI

/// Bản iOS (`vn.io.nt0.examsuite.ios`). Chỉ chứa điểm vào; mọi giao diện nằm trong Packages/MobileFeatures. Target này
/// không link AuthoringFeature.
@main
struct StudentiOSApp: App {
    var body: some Scene {
        MobileScenes()
    }
}

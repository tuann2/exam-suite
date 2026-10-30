import SwiftUI

/// Màn gốc của bản iOS. Bước I0 của docs/product/plan-ios-v1.md: khung trống, chưa có chữ giao diện; màn Thư viện thật
/// (library.md) thay view này ở bước I2.
public struct RootView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            List {}
                .accessibilityIdentifier("root.list")
        }
    }
}

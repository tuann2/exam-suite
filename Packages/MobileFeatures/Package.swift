// swift-tools-version: 6.0
// Giao diện iPhone của Exam Suite (bản Học viên trên iOS, docs/product/plan-ios-v1.md Phần 3). Package riêng vì
// `platforms` của SwiftPM áp cho cả package: target chỉ build cho iOS đặt trong ExamFeatures thì `swift test` trên macOS
// cũng phải biên dịch nó. Chỉ build bằng `xcodebuild` với đích iOS (simulator hoặc iPhone), không bằng `swift build`.
// Không phụ thuộc AuthoringFeature, AuthoringData, ExamImport (ADR 0003, kiểm bằng scripts/check_boundaries.py).
//
// Bước I0: khung, chưa có phụ thuộc. Bước I1 thêm package dùng chung Packages/SharedFeatures (LibraryData, InterfaceCore,
// SessionModel); bước I2 thêm giao diện thật và test.
import PackageDescription

let package = Package(
    name: "MobileFeatures",
    defaultLocalization: "vi",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "MobileShell", targets: ["MobileShell"]),
    ],
    targets: [
        // Màn hình iPhone.
        .target(
            name: "MobileFeature",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Scene của app và màn gốc.
        .target(
            name: "MobileShell",
            dependencies: ["MobileFeature"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)

// swift-tools-version: 6.0
// Giao diện iPhone của Exam Suite (bản Học viên trên iOS, docs/product/plan-ios-v1.md Phần 3). Package riêng vì
// `platforms` của SwiftPM áp cho cả package: target chỉ build cho iOS đặt trong ExamFeatures thì `swift test` trên macOS
// cũng phải biên dịch nó. Chỉ build bằng `xcodebuild` với đích iOS (simulator hoặc iPhone), không bằng `swift build`.
// Không phụ thuộc AuthoringFeature, AuthoringData, ExamImport (ADR 0003, kiểm bằng scripts/check_boundaries.py).
//
// Phần dùng chung với bản macOS (LibraryData, InterfaceCore, SessionModel) ở Packages/SharedFeatures (bước I1);
// MobileFeature phụ thuộc cả ba nên bản build iOS của `verify_local.sh` biên dịch chúng cho iOS. Bước I2 thêm giao diện
// thật.
import PackageDescription

let package = Package(
    name: "MobileFeatures",
    defaultLocalization: "vi",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "MobileShell", targets: ["MobileShell"]),
    ],
    dependencies: [
        .package(path: "../ExamKit"),
        .package(path: "../SharedFeatures"),
    ],
    targets: [
        // Màn hình iPhone.
        .target(
            name: "MobileFeature",
            dependencies: [
                .product(name: "LibraryData", package: "SharedFeatures"),
                .product(name: "InterfaceCore", package: "SharedFeatures"),
                .product(name: "SessionModel", package: "SharedFeatures"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Scene của app và màn gốc.
        .target(
            name: "MobileShell",
            dependencies: [
                "MobileFeature",
                .product(name: "InterfaceCore", package: "SharedFeatures"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Phần chỉ của iOS, chạy trên simulator (`xcodebuild test`, scheme ExamSuiteiOS): kho thư viện, đề mẫu,
        // bookmark khi thư mục đổi chỗ (thay cho container đổi đường dẫn sau khi cập nhật app). Logic dùng chung đã có
        // test ở LibraryDataTests (macOS); test ở đây chỉ chứng minh nó chạy được trên iOS.
        .testTarget(
            name: "MobileFeatureTests",
            dependencies: [
                .product(name: "LibraryData", package: "SharedFeatures"),
                .product(name: "ExamKit", package: "ExamKit"),
                .product(name: "ExamFile", package: "ExamKit"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)

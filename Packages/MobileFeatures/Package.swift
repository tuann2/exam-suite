// swift-tools-version: 6.0
// Giao diện iPhone của Exam Suite (bản Học viên trên iOS, docs/product/plan-ios-v1.md Phần 3). Package riêng vì
// `platforms` của SwiftPM áp cho cả package: target chỉ build cho iOS đặt trong ExamFeatures thì `swift test` trên macOS
// cũng phải biên dịch nó. Chỉ build bằng `xcodebuild` với đích iOS (simulator hoặc iPhone), không bằng `swift build`.
// Không phụ thuộc AuthoringFeature, AuthoringData, ExamImport (ADR 0003, kiểm bằng scripts/check_boundaries.py).
//
// Phần dùng chung với bản macOS (LibraryData, InterfaceCore, SessionModel) ở Packages/SharedFeatures; MobileFeature
// dùng cả ba (bước I2: Thư viện, phiên thi), nên bản build iOS của `verify_local.sh` biên dịch chúng cho iOS.
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
        // Snapshot test iPhone (ADR 0010): CHỈ test target MobileSnapshotTests được dùng; không target nào trong Sources,
        // không vào app (scripts/check_boundaries.py, check_bundle_boundary.sh kiểm). Cùng bản với ExamFeatures.
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.19.6"),
    ],
    targets: [
        // Màn hình iPhone: Thư viện, Trước khi thi, làm bài, Kết quả, Xem lại bài; điều phối phiên thi; file nhận từ
        // app khác. Chữ giao diện qua `localized(_:)` của target (String Catalog của target).
        .target(
            name: "MobileFeature",
            dependencies: [
                .product(name: "LibraryData", package: "SharedFeatures"),
                .product(name: "InterfaceCore", package: "SharedFeatures"),
                .product(name: "SessionModel", package: "SharedFeatures"),
                .product(name: "ExamKit", package: "ExamKit"),
                .product(name: "ExamFile", package: "ExamKit"),
            ],
            resources: [.process("Resources/Localizable.xcstrings")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Scene của app và màn gốc.
        .target(
            name: "MobileShell",
            dependencies: [
                "MobileFeature",
                .product(name: "InterfaceCore", package: "SharedFeatures"),
                .product(name: "LibraryData", package: "SharedFeatures"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Phần chỉ của iOS, chạy trên simulator (`xcodebuild test`, scheme ExamSuiteiOS): kho thư viện, đề mẫu,
        // bookmark khi thư mục đổi chỗ (thay cho container đổi đường dẫn sau khi cập nhật app), file nhận từ app khác
        // (`Inbox`), điều phối phiên thi của iOS (xuống nền thì tạm dừng, Bỏ bài, nhận file lúc đang có bài). Logic
        // dùng chung đã có test ở SharedFeatures/ExamFeatures (macOS); không test lại.
        .testTarget(
            name: "MobileFeatureTests",
            dependencies: [
                "MobileFeature",
                .product(name: "LibraryData", package: "SharedFeatures"),
                .product(name: "InterfaceCore", package: "SharedFeatures"),
                .product(name: "SessionModel", package: "SharedFeatures"),
                .product(name: "ExamKit", package: "ExamKit"),
                .product(name: "ExamFile", package: "ExamKit"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Snapshot iPhone sáng/tối và cỡ chữ trợ năng (docs/product/plan-ios-v1.md Phần 5, ADR 0010), chạy trên simulator
        // cùng `MobileFeatureTests`; ảnh tham chiếu ở __Snapshots__/ (docs/process/snapshot-tests.md).
        .testTarget(
            name: "MobileSnapshotTests",
            dependencies: [
                "MobileFeature",
                .product(name: "LibraryData", package: "SharedFeatures"),
                .product(name: "InterfaceCore", package: "SharedFeatures"),
                .product(name: "SessionModel", package: "SharedFeatures"),
                .product(name: "ExamKit", package: "ExamKit"),
                .product(name: "ExamFile", package: "ExamKit"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            exclude: ["__Snapshots__"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)

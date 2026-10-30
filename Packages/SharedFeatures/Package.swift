// swift-tools-version: 6.0
// Phần dùng chung của bản macOS (Packages/ExamFeatures) và bản iOS (Packages/MobileFeatures): dữ liệu Thư viện và
// model trình bày không phụ thuộc AppKit, UIKit (docs/product/plan-ios-v1.md Phần 3, ADR 0013). Package riêng vì
// `platforms` của SwiftPM áp cho cả package: ExamFeatures chỉ khai báo macOS (export String Catalog build mọi target có
// catalog theo mọi nền tảng package khai báo, mà LibraryFeature, SessionFeature import AppKit), MobileFeatures chỉ khai
// báo iOS. Module ở đây phải biên dịch cho cả hai nền: `verify_local.sh` build bản iOS (MobileFeature phụ thuộc cả ba
// module), nên lỡ import AppKit hay UIKit thì trình biên dịch chặn.
// Không phụ thuộc AuthoringFeature, AuthoringData, ExamImport (ADR 0003): cả hai bản Học viên dùng package này.
import PackageDescription

let package = Package(
    name: "SharedFeatures",
    // Tiếng Việt là ngôn ngữ nguồn của chữ giao diện (docs/product/accessibility-localization.md); quy ước ở AGENTS.md,
    // mục "Chuỗi giao diện", kiểm bằng scripts/check_localization.py.
    defaultLocalization: "vi",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "LibraryData", targets: ["LibraryData"]),
        .library(name: "InterfaceCore", targets: ["InterfaceCore"]),
        .library(name: "SessionModel", targets: ["SessionModel"]),
    ],
    dependencies: [
        .package(path: "../ExamKit"),
    ],
    targets: [
        // Thư viện đề: SwiftData, nhập file, trạng thái file, đề mẫu, lần thi
        // (docs/product/library.md). Không SwiftUI, không AppKit; test bằng `swift test`.
        .target(
            name: "LibraryData",
            dependencies: [
                .product(name: "ExamKit", package: "ExamKit"),
                .product(name: "ExamFile", package: "ExamKit"),
            ],
            // Nội dung đề mẫu (mỗi đề một thư mục exam.json + media/), ghi ra Application
            // Support lần đầu mở app.
            resources: [.copy("Resources/Samples")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Phần giao diện không phụ thuộc nền tảng, tách từ LibraryFeature: tra chữ (`InterfaceStrings`), locale của
        // ngôn ngữ giao diện (`InterfaceLocale`, `.interfaceLocale()`), câu báo lỗi theo mã (`ErrorMessages`), định
        // dạng, bảng màu dạng số (`LibraryPalette`), kiểu và model của Thư viện (`LibraryModel`). Foundation + SwiftUI
        // (không AppKit, UIKit); phần của macOS (view, màu `NSColor`, Hiện trong Finder) ở lại LibraryFeature.
        .target(
            name: "InterfaceCore",
            dependencies: [
                "LibraryData",
                .product(name: "ExamKit", package: "ExamKit"),
                .product(name: "ExamFile", package: "ExamKit"),
            ],
            resources: [.process("Resources/Localizable.xcstrings")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Model trình bày của phiên thi, tách từ SessionFeature: Trước khi thi, làm bài, Kết quả, Xem lại bài, môi
        // trường của phiên thi (thư viện, cài đặt, đồng hồ) và định dạng (docs/product/exam-taking.md). Không biết
        // ReportFeature: phần xem lại của PDF kết quả (`ReportPreferences`) ở SessionFeature.
        .target(
            name: "SessionModel",
            dependencies: [
                "InterfaceCore",
                "LibraryData",
                .product(name: "ExamKit", package: "ExamKit"),
                .product(name: "ExamFile", package: "ExamKit"),
            ],
            resources: [.process("Resources/Localizable.xcstrings")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "LibraryDataTests",
            dependencies: [
                "LibraryData",
                .product(name: "ExamKit", package: "ExamKit"),
                .product(name: "ExamFile", package: "ExamKit"),
                .product(name: "LargeExamSupport", package: "ExamKit"),
            ],
            // Kho SwiftData v1 thật để test mở kho cũ (Fixtures/README.md).
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)

// swift-tools-version: 6.0
// Lõi của Exam Suite. Hai module ở đây chỉ dùng Foundation (+ ZIPFoundation cho
// ExamFile) để `swift test` chạy được trên cả macOS và Linux.
// Quy tắc ranh giới: docs/decisions/0008-loi-foundation-only.md,
// kiểm bằng scripts/check_boundaries.py.
import PackageDescription

let package = Package(
    name: "ExamKit",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "ExamKit", targets: ["ExamKit"]),
        .library(name: "ExamFile", targets: ["ExamFile"]),
        // Chỉ cho test và đo đạc (đề chuẩn có seed, đo thời gian; docs/product/large-exams.md). Không app nào
        // phụ thuộc product này.
        .library(name: "LargeExamSupport", targets: ["LargeExamSupport"]),
    ],
    dependencies: [
        // Thư viện ngoài duy nhất được duyệt: docs/decisions/0006-thu-vien-ngoai.md
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
    ],
    targets: [
        .target(
            name: "ExamKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "ExamFile",
            dependencies: [
                "ExamKit",
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Đề chuẩn để đo (bản Swift của scripts/gen_large_exam.py) và đo thời gian cho test `Timing` của cả hai
        // package. Chỉ Foundation + ExamKit + ExamFile như lõi, để chạy được trên Linux; riêng CommonCrypto (băm tên ảnh
        // nhanh ở Debug) chỉ trong `#if canImport(CommonCrypto)`, Linux dùng MediaNaming (kiểm bằng check_boundaries.py).
        .target(
            name: "LargeExamSupport",
            dependencies: ["ExamKit", "ExamFile"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "ExamKitTests",
            dependencies: ["ExamKit", "LargeExamSupport"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "ExamFileTests",
            dependencies: ["ExamFile", "LargeExamSupport"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)

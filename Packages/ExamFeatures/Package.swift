// swift-tools-version: 6.0
// Giao diện SwiftUI của Exam Suite. Hai "shell" quyết định bản app nào chứa gì:
// StudentShell KHÔNG được phụ thuộc AuthoringFeature, AuthoringData (hay ExamImport)
// (docs/decisions/0003-hai-ban-app-mot-codebase.md, kiểm bằng scripts/check_boundaries.py).
// LibraryData là phần dữ liệu của Thư viện (không giao diện), dùng chung cho cả hai bản app.
// Test target có thể dùng product LargeExamSupport của ExamKit (đề chuẩn có seed + đo thời gian cho test `Timing`,
// docs/product/large-exams.md); không target nào của app được phụ thuộc nó.
import PackageDescription

let package = Package(
    name: "ExamFeatures",
    // Tiếng Việt là ngôn ngữ nguồn của chữ giao diện (docs/product/accessibility-localization.md). Mỗi target có chữ
    // giao diện có Resources/Localizable.xcstrings (sourceLanguage vi) và hàm `localized(_:)` tra catalog đó
    // (bundle: .module); quy ước ở AGENTS.md, mục "Chuỗi giao diện", kiểm bằng scripts/check_localization.py.
    defaultLocalization: "vi",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "StudentShell", targets: ["StudentShell"]),
        .library(name: "AdminShell", targets: ["AdminShell"]),
    ],
    dependencies: [
        .package(path: "../ExamKit"),
        // Cùng thư viện, cùng phiên bản với ExamKit (ADR 0006); ExamImport đọc .docx (zip) theo import.md.
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
        // Snapshot test sáng/tối (ADR 0010): CHỈ test target ExamFeaturesSnapshotTests được dùng; không target
        // nào trong Sources, không app nào (scripts/check_boundaries.py kiểm).
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.19.6"),
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
        .target(
            name: "LibraryFeature",
            dependencies: [
                "LibraryData",
                .product(name: "ExamKit", package: "ExamKit"),
                .product(name: "ExamFile", package: "ExamKit"),
            ],
            resources: [.process("Resources/Localizable.xcstrings")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Báo cáo PDF dùng chung cho hai bản app (docs/product/export-print.md): model báo cáo thuần
        // (`ReportDocument`, `ResultsReport`), bộ dựng trang A4 bằng `ImageRenderer` → `CGContext` PDF, tên file gợi
        // ý, In qua PDFKit. Không biết SessionFeature (SessionFeature dựng `ResultsReport` từ Kết quả/Xem lại và gắn
        // nút xuất), không phụ thuộc module chỉ của bản Admin (ADR 0003): chỉ được ExamKit, ExamFile, LibraryData và
        // LibraryFeature (chỉ để tra chữ qua `InterfaceStrings`, như mọi target giao diện; kiểm bằng
        // scripts/check_boundaries.py). Chữ giao diện qua `localized(_:)` của target (String Catalog của target).
        .target(
            name: "ReportFeature",
            dependencies: ["LibraryFeature"],
            resources: [.process("Resources/Localizable.xcstrings")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Phiên thi: model trình bày (Trước khi thi, làm bài, Rà soát, Kết quả, Xem lại, điều phối phiên)
        // và giao diện (docs/product/exam-taking.md). Lần thi lưu qua LibraryData. Dùng LibraryFeature cho
        // bảng màu chung (LibraryPalette) và để nối Thư viện với phiên thi; LibraryFeature không biết
        // SessionFeature. Không phụ thuộc AuthoringFeature (ADR 0003): dùng chung cho cả hai bản app.
        .target(
            name: "SessionFeature",
            dependencies: [
                "LibraryData",
                "LibraryFeature",
                "ReportFeature",
                .product(name: "ExamKit", package: "ExamKit"),
                .product(name: "ExamFile", package: "ExamKit"),
            ],
            resources: [.process("Resources/Localizable.xcstrings")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Import đề từ .txt/.docx (docs/product/import.md): bộ chuyển đổi thuần, không SwiftUI/AppKit. Chỉ bản
        // Admin được phụ thuộc (ADR 0003, kiểm bằng scripts/check_boundaries.py).
        .target(
            name: "ExamImport",
            dependencies: [
                .product(name: "ExamKit", package: "ExamKit"),
                .product(name: "ExamFile", package: "ExamKit"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Mô hình chỉnh sửa đề của bản Admin (docs/product/authoring.md): thao tác trên Exam + ảnh,
        // thay đổi ngược cho Hoàn tác, ánh xạ lỗi kiểm đề → vị trí. Chỉ Foundation + ExamKit + ExamFile
        // (không SwiftUI/AppKit, kiểm bằng scripts/check_boundaries.py); chỉ AuthoringFeature phụ thuộc.
        .target(
            name: "AuthoringData",
            dependencies: [
                .product(name: "ExamKit", package: "ExamKit"),
                .product(name: "ExamFile", package: "ExamKit"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Cửa sổ soạn đề (docs/product/authoring.md): document, cây đề, trình soạn, xem trước (dùng lại cách hiện
        // câu của SessionFeature), thanh lỗi; Import đề… (hộp xác nhận, báo cáo; docs/product/import.md), Thử đề
        // này, và PDF/In đề (docs/product/export-print.md, mục Bản Admin: model đề → khối của ReportFeature; bộ dựng
        // trang, ghi file, hộp của macOS dùng chung với PDF kết quả). Chỉ AdminShell phụ thuộc (ADR 0003).
        .target(
            name: "AuthoringFeature",
            dependencies: [
                "AuthoringData",
                "ExamImport",
                "LibraryData",
                "LibraryFeature",
                "ReportFeature",
                "SessionFeature",
                .product(name: "ExamKit", package: "ExamKit"),
                .product(name: "ExamFile", package: "ExamKit"),
            ],
            resources: [.process("Resources/Localizable.xcstrings")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "StudentShell",
            dependencies: ["LibraryData", "LibraryFeature", "SessionFeature"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "AdminShell",
            dependencies: ["LibraryData", "LibraryFeature", "SessionFeature", "AuthoringFeature"],
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
        // Logic giao diện tách được khỏi view của Thư viện: trạng thái → biểu tượng + chữ, câu đọc
        // VoiceOver, gộp báo cáo thêm đề, thông báo + Hoàn tác, điều hướng lưới, luồng của LibraryModel.
        .testTarget(
            name: "LibraryFeatureTests",
            dependencies: [
                "LibraryFeature",
                "LibraryData",
                .product(name: "ExamKit", package: "ExamKit"),
                .product(name: "ExamFile", package: "ExamKit"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Bộ chuyển đổi import trên file tự soạn (tạo trong test): từng quy tắc của import.md, file hỏng, zip bomb.
        .testTarget(
            name: "ExamImportTests",
            dependencies: [
                "ExamImport",
                .product(name: "ExamKit", package: "ExamKit"),
                .product(name: "ExamFile", package: "ExamKit"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Thao tác soạn đề, Hoàn tác/Làm lại, ảnh, ghi rồi đọc lại gói, dấu vân tay câu, ánh xạ lỗi.
        .testTarget(
            name: "AuthoringDataTests",
            dependencies: [
                "AuthoringData",
                .product(name: "ExamKit", package: "ExamKit"),
                .product(name: "ExamFile", package: "ExamKit"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Bộ soạn đề không giao diện: Hoàn tác/Làm lại qua UndoManager thật, gộp gõ chữ, chọn dòng sau khi xoá,
        // thanh lỗi → dòng/trường, kéo thả trên cây đề, ghi rồi mở lại document (kể cả ảnh), kiểm đề chạy nền với
        // đề 2.000 câu, tương phản màu burgundy; luồng Import đề… (hộp xác nhận, huỷ, lỗi, báo cáo → câu) và Thử đề
        // này (lưu → đọc nghiêm → thêm vào Thư viện → Trước khi thi) với file và thư viện giả hoặc trong bộ nhớ;
        // PDF/In đề (model đề → khối, PDF đọc lại bằng PDFKit, luồng Xuất PDF/In với hộp của macOS giả).
        .testTarget(
            name: "AuthoringFeatureTests",
            dependencies: [
                "AuthoringFeature",
                "AuthoringData",
                "ExamImport",
                "LibraryData",
                "LibraryFeature",
                "ReportFeature",
                "SessionFeature",
                .product(name: "ExamKit", package: "ExamKit"),
                .product(name: "ExamFile", package: "ExamKit"),
                .product(name: "LargeExamSupport", package: "ExamKit"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Bộ dựng trang PDF đọc lại bằng PDFKit trên tài liệu nhỏ: chữ tiếng Việt (Đ không thành Ð), A4, tách khối
        // quá cao với "(tiếp)", chân trang mọi trang, Markdown, ảnh, huỷ, tiến độ, main actor không bị chặn; tên file
        // gợi ý; In ra file; catalog của module. PDF kết quả của đề chuẩn đo ở SessionFeatureTests (`Timing`).
        .testTarget(
            name: "ReportFeatureTests",
            dependencies: ["ReportFeature", "LibraryFeature"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Model trình bày của phiên thi với đồng hồ giả, thư viện giả và file đề thật trong thư mục tạm; phần
        // AppKit của phiên thi (hỏi khi đóng/thoát, delegate chen trước, menu Bài thi) với NSWindow không hiện.
        .testTarget(
            name: "SessionFeatureTests",
            dependencies: [
                "SessionFeature",
                "ReportFeature",
                "LibraryData",
                "LibraryFeature",
                .product(name: "ExamKit", package: "ExamKit"),
                .product(name: "ExamFile", package: "ExamKit"),
                .product(name: "LargeExamSupport", package: "ExamKit"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Snapshot test sáng/tối ở cửa sổ tối thiểu 960×640 (ADR 0010, plan giai đoạn 5 bước 3): làm bài (câu dài,
        // 8+ lựa chọn, ảnh lớn), Xem lại bài (hideAnswers, câu đã sửa), Kết quả nhiều phần, Thư viện (lưới,
        // danh sách), cửa sổ soạn đề (trình soạn câu, xem trước). Ảnh tham chiếu ở __Snapshots__/; ghi lại bằng
        // biến môi trường EXAMSUITE_SNAPSHOT_RECORD (docs/process/snapshot-tests.md).
        .testTarget(
            name: "ExamFeaturesSnapshotTests",
            dependencies: [
                "SessionFeature",
                "LibraryFeature",
                "LibraryData",
                "AuthoringFeature",
                "AuthoringData",
                // Import trực tiếp: báo cáo import (snapshot soạn đề, test đo cửa sổ xếp lát), PDF trang 1.
                "ExamImport",
                "ReportFeature",
                .product(name: "ExamKit", package: "ExamKit"),
                .product(name: "ExamFile", package: "ExamKit"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            exclude: ["__Snapshots__"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)

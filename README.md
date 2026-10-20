# Exam Suite cho macOS

> **English summary.** Exam Suite is a native macOS app for practising and taking multiple-choice exams, written in
> Swift 6 and SwiftUI for Apple silicon Macs running macOS 15 or later (deployment target; tested on macOS 26). One
> codebase builds two apps: **Exam Suite** (student build: exam library, practice, timed exams, results, answer review,
> PDF and printing of results) and **Exam Suite Admin** (everything above plus the exam editor and import from `.txt`,
> `.docx` and one common `.vce` variant, text-only questions). Exams are open `.exam` packages: a zip with `exam.json`
> ([JSON Schema](schema/exam-v1.schema.json)) and a `media/` folder. The interface is available in Vietnamese and
> English. Download the DMGs from [Releases](https://github.com/tuann2/exam-suite/releases); the apps are ad-hoc signed,
> so the first launch needs System Settings › Privacy & Security › Open Anyway ([install guide](docs/install.md), in
> Vietnamese). Licensed under the [Apache License 2.0](LICENSE). Documentation and code comments are mostly in
> Vietnamese.

Ứng dụng luyện tập và thi trắc nghiệm, dự án cá nhân của Nt0, viết bằng Swift 6 + SwiftUI cho Mac Apple silicon
(macOS 15 trở lên). Một codebase, hai bản app:

| Bản | Target | Bundle ID | Chức năng |
| --- | --- | --- | --- |
| Học viên | `ExamSuite` | `vn.io.nt0.examsuite` | Thư viện đề, Luyện tập, Thi, Kết quả, Xem lại bài, PDF và In kết quả |
| Admin | `ExamSuiteAdmin` | `vn.io.nt0.examsuite.admin` | Như trên, thêm Soạn đề, Import đề (`.txt`, `.docx`, `.vce`), PDF và In đề |

Bản Học viên không chứa code soạn đề ([ADR 0003](docs/decisions/0003-hai-ban-app-mot-codebase.md)). Đề thi là gói zip
đuôi `.exam` gồm `exam.json` (theo [schema/exam-v1.schema.json](schema/exam-v1.schema.json)) và thư mục `media/`
([định dạng](docs/product/exam-format.md)).

Điểm chính (chi tiết ở [docs/product/overview.md](docs/product/overview.md) và [CHANGELOG.md](CHANGELOG.md)):

- Thư viện đề: thêm file `.exam` (⌘O hoặc kéo thả), lưới hoặc danh sách, tìm, lọc, sắp xếp, hai đề mẫu, lịch sử thi.
- Luyện tập có Kiểm tra đáp án; Thi tính giờ (chọn câu ngẫu nhiên có seed, cảnh báo 5 và 1 phút, tạm dừng, rà soát và
  nộp); Kết quả theo thang 1000 và phần trăm, theo từng phần; Xem lại bài, Làm lại, Luyện lại câu sai.
- Xuất PDF và In kết quả (hai bản); PDF và In đề, có hoặc không có đáp án (bản Admin).
- Soạn đề (bản Admin): cửa sổ ba cột, ảnh, kiểm lỗi khi đang soạn, Hoàn tác/Làm lại, Thử đề này.
- Import đề (bản Admin) từ `.txt`, `.docx` và `.vce`. Với `.vce`, app đọc một biến thể phổ biến, câu chỉ có văn bản;
  ảnh, bảng, loại câu khác và phiên bản `.vce` khác chưa hỗ trợ, bị bỏ kèm báo cáo
  ([import.md](docs/product/import.md), [ADR 0009](docs/decisions/0009-doc-dinh-dang-vce.md)).
- Giao diện tiếng Việt và tiếng Anh; VoiceOver, Dark Mode, nền đọc cho vùng câu hỏi, cỡ chữ nội dung (⌘+ / ⌘− / ⌘0).

## Cài đặt

Tải `ExamSuite-<phiên bản>.dmg` (bản Học viên) hoặc `ExamSuiteAdmin-<phiên bản>.dmg` (bản Admin) ở trang
[Releases](https://github.com/tuann2/exam-suite/releases), rồi làm theo [docs/install.md](docs/install.md) (bản sao
trong mỗi DMG). App ký ad-hoc, chưa được Apple công chứng: lần mở đầu phải bấm **Vẫn mở** (Open Anyway) trong Cài đặt hệ
thống › Quyền riêng tư & Bảo mật. App chạy được từ macOS 15 (deployment target) nhưng mới được test tay trên macOS 26.
DMG trên trang Releases do CI của GitHub đóng từ đúng commit gắn tag (`scripts/make_dmg.sh`).

## Build từ mã nguồn

Cần Mac Apple silicon, macOS 15 trở lên, Xcode (repo đang build và test bằng Xcode 27, Swift 6) và
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (project Xcode sinh từ `project.yml`, không commit `.xcodeproj`).

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project ExamSuite.xcodeproj -scheme ExamSuite -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
# bản Admin: -scheme ExamSuiteAdmin
```

Hoặc mở `ExamSuite.xcodeproj` trong Xcode sau `xcodegen generate`. Lưu ý: bản Debug mang bundle ID thật nên dùng chung
thư viện, lịch sử thi và cài đặt với bản đã cài trên máy (AGENTS.md, mục Lệnh kiểm chứng).

Kiểm tra và đóng gói:

```bash
scripts/check.sh                                  # mọi kiểm tra không cần xcodebuild (cần Python jsonschema hoặc uv)
swift test --package-path Packages/ExamKit        # lõi thuần Foundation (chạy cả trên Linux)
swift test --package-path Packages/ExamFeatures   # giao diện, dữ liệu Thư viện, snapshot test (cần macOS, Xcode)
scripts/make_dmg.sh --out dist                    # đóng hai DMG từ tree sạch (build Release, ký ad-hoc, kiểm)
```

Agent và người đóng góp đọc [AGENTS.md](AGENTS.md) trước, rồi [docs/README.md](docs/README.md) (bản đồ tài liệu) và
[docs/process/review-and-merge.md](docs/process/review-and-merge.md). Kế hoạch đầy đủ:
[docs/product/plan-macos-v1.md](docs/product/plan-macos-v1.md). Repo public bắt đầu từ một commit (2026-10-20): số PR
(`#…`) và SHA nhắc trong `docs/plans/`, `docs/notes/` và CHANGELOG thuộc repo riêng trước đó, không mở được ở đây.

## Cấu trúc

```text
Apps/            Điểm vào của hai app (chỉ @main + cấu hình), XCUITest của hai bản
Packages/ExamKit       Lõi thuần Foundation: model, chấm điểm, phiên thi (ExamKit)
                       và đọc/ghi gói .exam (ExamFile). Test chạy được trên Linux.
Packages/ExamFeatures  Giao diện SwiftUI và dữ liệu: LibraryData, LibraryFeature, SessionFeature,
                       ReportFeature, AuthoringData, AuthoringFeature, ExamImport; StudentShell, AdminShell
schema/          JSON Schema của exam.json
fixtures/        Đề tự soạn (hợp lệ và không hợp lệ) dùng cho test
scripts/         Kiểm tra: schema, ranh giới module, chuỗi giao diện; đóng gói .exam và DMG
docs/            Sản phẩm, quyết định (ADR), exec-plan, quy trình review, hướng dẫn cài đặt
project.yml      Khai báo Xcode project cho XcodeGen
```

## Giấy phép

Copyright 2026 Nt0. Phát hành theo giấy phép [Apache License 2.0](LICENSE); xem thêm [NOTICE](NOTICE). Giấy phép của
thư viện bên thứ ba: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Ghi công

- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) (MIT) đọc/ghi gói `.exam` và `.docx`; là thư viện duy nhất
  link vào app ([ADR 0006](docs/decisions/0006-thu-vien-ngoai.md)).
- [repository-harness](https://github.com/hoangnb24/repository-harness) (MIT): hướng dẫn và công cụ cho AI agent trong
  repo (`.harness-core/`, `.agents/skills/`, `docs/WORKFLOW.md`…; [ADR 0007](docs/decisions/0007-harness-ai-agent.md)),
  không có trong app.
- Ý tưởng UX và quy tắc chấm điểm lấy cảm hứng từ [Open Exam Suite](https://github.com/bolorundurowb/Open-Exam-Suite)
  (GPLv3), chỉ dùng làm đặc tả: không chép mã nguồn hay đề mẫu từ đó
  ([ADR 0001](docs/decisions/0001-viet-moi-swiftui-khong-chep-gpl.md)).

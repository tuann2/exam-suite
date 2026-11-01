# Thông báo bên thứ ba (Third-party notices)

Exam Suite (Copyright 2026 Nt0, giấy phép Apache-2.0, xem LICENSE và NOTICE) dùng các thành phần mã nguồn mở dưới
đây. Phiên bản thư viện theo `Package.resolved` của repo; `scripts/make_dmg.sh` kiểm phiên bản và giấy phép của
ZIPFoundation bản vừa build khớp mục dưới.

Exam Suite uses the open-source components below. Only ZIPFoundation is compiled into the apps; the test-only packages
are not distributed, and the vendored agent harness files live in the repository only.

## Đi kèm trong các app (Included in the apps)

### ZIPFoundation 0.9.20

- Nguồn (source): https://github.com/weichsel/ZIPFoundation
- Giấy phép (license): MIT
- Dùng trong (used in): module ExamFile (đọc/ghi gói `.exam`) của hai bản app macOS và bản iOS; module ExamImport (đọc
  `.docx`) của bản Admin.

```text
MIT License

Copyright (c) 2017-2025 Thomas Zoechling (https://www.peakstep.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Chỉ dùng khi chạy test, không phân phối (Test-only, not distributed)

Các gói dưới đây chỉ ở test target `ExamFeaturesSnapshotTests` và `MobileSnapshotTests` (swift-snapshot-testing, ADR
0006 và 0010) hoặc được `Package.resolved` ghim vì manifest của swift-snapshot-testing khai báo. Không gói nào được biên
dịch hay link vào app, và không có trong DMG (`scripts/check_bundle_boundary.sh` kiểm hai app macOS và app iOS).

These packages are used only by the test targets `ExamFeaturesSnapshotTests` and `MobileSnapshotTests` or are pinned
because the swift-snapshot-testing manifest declares them. None of them is compiled into or shipped with the apps.

- swift-snapshot-testing 1.19.6 (https://github.com/pointfreeco/swift-snapshot-testing): MIT, Copyright (c) 2019
  Point-Free, Inc.
- swift-custom-dump 1.7.3 (https://github.com/pointfreeco/swift-custom-dump): MIT, Copyright (c) 2021 Point-Free, Inc.
- swift-issue-reporting 2.1.2 (https://github.com/pointfreeco/swift-issue-reporting): MIT, Copyright (c) 2021
  Point-Free, Inc.
- swift-syntax 604.0.0 (https://github.com/swiftlang/swift-syntax): Apache-2.0 with Runtime Library Exception,
  Copyright (c) Apple Inc. and the Swift project authors.

## Đi kèm trong repo, không trong app (Included in the repository, not in the apps)

### repository-harness 0.1.10

- Nguồn (source): https://github.com/hoangnb24/repository-harness (tag `harness-v0.1.10`)
- Giấy phép (license): MIT
- Dùng trong (used in): hướng dẫn và công cụ cho AI agent, chép từ upstream và theo dõi trong
  `.harness-core/manifest.json` (`core_version` 0.1.10): `.harness-core/**`, `.agents/skills/**`, phần harness của
  `AGENTS.md`, `docs/WORKFLOW.md`, `docs/patterns/encoding-invariants.md`, `docs/templates/*`, các file `README.md` của
  `docs/`, `docs/product/`, `docs/decisions/`, `docs/plans/`, `docs/plans/active/`, `docs/plans/completed/`
  ([ADR 0007](docs/decisions/0007-harness-ai-agent.md)). Không có trong app hay DMG.

```text
MIT License

Copyright (c) 2025 Hoang Nguyen

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

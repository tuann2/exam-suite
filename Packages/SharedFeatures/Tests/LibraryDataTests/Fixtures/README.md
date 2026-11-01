# Fixture kho Thư viện

- `Library-v1.store`: kho SwiftData thật, tạo bằng `LibrarySchemaV1` qua đúng đường ghi của app
  (`LibraryPersistence.makeContainer` + `SwiftDataLibraryRepository`). Gồm 3 mục (một đề mẫu, một mục có
  lần mở gần nhất, một mục "cần app mới hơn"), mỗi mục có bookmark, và 3 lần thi có payload (một lần của đề
  đã xoá khỏi thư viện). Dữ liệu ở `LibraryV1Fixture` trong `LibraryV1FixtureTests.swift`. WAL đã được gộp
  vào file chính nên chỉ có một file.
- `LibraryV1FixtureTests` chép file này vào thư mục tạm và:
  - mở bằng code hiện tại, khẳng định đọc đủ dữ liệu, không có `storeIssue`, không có file `.broken-…`. Đỏ khi
    sửa `LibrarySchemaV1` làm kho cũ bị dời đi hoặc mất dữ liệu (đổi tên, đổi kiểu, bỏ thuộc tính). Không đỏ khi
    chỉ thêm thuộc tính tuỳ chọn, vì CoreData tự chuyển đổi được;
  - so `NSStoreModelVersionHashes` trong metadata của file này với kho vừa tạo bằng `LibrarySchemaV1` hiện tại.
    Đỏ với mọi thay đổi model V1, kể cả thêm thuộc tính tuỳ chọn.

**Không sửa, không tạo lại file này** sau khi đã có schema mới hơn: nó đại diện cho kho mà người dùng đang có.
Lần tạo lại duy nhất từ khi có fixture: 2026-10-20, cho bản public (đường dẫn đề mẫu theo bundle ID hiện hành; cùng
schema, mục, lần thi, payload và hash model; Nt0 duyệt). So bản cũ và bản mới bằng sqlite3: chỉ khác đường dẫn đề mẫu,
`Z_PK` của mục (thứ tự chèn), UUID kho và thời điểm của bảng lịch sử (`ATRANSACTION.ZTIMESTAMP`).
Đổi schema thì thêm `LibrarySchemaV2` cùng bước chuyển đổi, thêm fixture `Library-v2.store` (generator mới),
và giữ test mở `Library-v1.store` (giờ là test chuyển đổi v1 → v2).

Tạo lại (chỉ khi V1 còn là schema mới nhất):

```bash
REGENERATE_LIBRARY_V1_FIXTURE=1 swift test --package-path Packages/SharedFeatures \
    --filter LibraryV1FixtureTests/regenerateV1Fixture
```

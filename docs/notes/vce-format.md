# Ghi chú định dạng `.vce`

Date: 2026-10-16 (spike giai đoạn 4, bước 3 và 6); rút gọn 2026-10-20 khi công khai repo (Nt0 chốt: giữ tính năng, rút
gọn tài liệu; ADR 0009).

Thẩm quyền: [ADR 0009](../decisions/0009-doc-dinh-dang-vce.md), [import.md](../product/import.md) mục `.vce`.

Bản Admin đọc được **một biến thể phổ biến** của định dạng `.vce` (biến thể của các file mẫu dùng khi làm). Bộ đọc viết
mới, chỉ Foundation, trong module `ExamImport` (`VceImporter`, `VceBinary`, `RVFReader`); chi tiết cấu trúc nằm ở mã
nguồn và ở bộ dựng file thử `VceTestWriter` của test.

- **Cách tìm hiểu định dạng:** phân tích file mẫu tại máy, đối chiếu với bản xuất Word của cùng đề, và đặc tả RVF công
  khai của TRichView (<https://trichview.com/help/rvf_specification.html>) cho văn bản của câu. Không đọc mã nguồn của
  công cụ chuyển đổi VCE nào, không dùng khoá hay code của bên thứ ba, không dịch ngược phần mềm của hãng, không dùng
  công cụ dịch ngược.
- **Nội dung file** không dùng khoá bí mật và không nén; văn bản của đề bài, lựa chọn, giải thích lưu dạng RVF.
- **Phạm vi và giới hạn** (import.md mục `.vce`): câu chỉ có văn bản; ảnh, bảng, kiểu chữ, loại câu khác và phiên bản
  `.vce` khác chưa hỗ trợ, bị bỏ kèm báo cáo; file hỏng (cắt cụt, sai kích thước, sai mã kiểm tra) chỉ ra lỗi có mã, không
  crash hay treo (`VceImportTests`).
- **Thử tại máy** trên file thật (không vào git): mẫu VCE 1 (40 câu, đáp án khớp bản Word), mẫu VCE 2 (600 câu), mẫu
  VCE 3 (419 câu); cả ba 0 câu bỏ.

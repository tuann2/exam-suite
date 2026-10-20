# 0007 Harness cho AI agent: repository-harness + ba cơ chế từ ai-workflow-template

Date: 2026-10-15

## Status

Accepted

## Context

AI agent viết toàn bộ code; một người điều phối, duyệt PR và test tay. Cần quy
trình đủ chặt để lỗi không lọt mà không nặng như quy trình nhiều vai.

## Decision

- Nền: [repository-harness](https://github.com/hoangnb24/repository-harness)
  v0.1.10 (`AGENTS.md`, `docs/WORKFLOW.md`, exec-plan, decision, `$encode-invariant`),
  cập nhật bằng `scripts/bin/harness update`.
- Mượn từ [ai-workflow-template](https://github.com/tuann2/ai-workflow-template):
  (1) bằng chứng gắn commit: merge chỉ khi CI xanh trên đúng SHA; (2) review độc
  lập bằng phiên agent mới cho vùng rủi ro cao; (3) giới hạn quyền: nhánh
  `feature/*`, không push `main`, không tự merge, không thêm thư viện khi chưa có ADR.
  Chi tiết: docs/process/review-and-merge.md.
- Lệnh kiểm chứng duy nhất cho máy: `scripts/check.sh` (CI gọi cùng script).

## Alternatives Considered

1. ai-workflow-template toàn bộ: chặt hơn nhưng gắn Node/npm, 4 vai, quá nặng cho 1–2 người.
2. Không harness, chỉ CLAUDE.md: thiếu nơi lưu quyết định và kế hoạch bền.

## Consequences

Positive:

- Nhẹ, không phụ thuộc stack; dễ nâng cấp.

Tradeoffs:

- Review độc lập và branch protection phụ thuộc kỷ luật người điều phối.

## Follow-Up

- Chuyển sang ai-workflow-template nếu nhiều người/agent làm song song.

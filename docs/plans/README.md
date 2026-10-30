# Execution Plans

Execution plans are Git-native working memory for complex tasks. They preserve
enough context for another agent or human to resume work without reconstructing
intent from chat history or a partial diff.

## When To Create A Plan

Use an ephemeral plan for bounded, single-session work.

Create one durable plan when work spans sessions, coordinates contributors, has
meaningful dependencies or ordering, requires recovery steps, or would be unsafe
to resume from the diff alone.

Use `docs/templates/exec-plan.md` and place the file under `active/`.
For an explicitly authorized baseline-to-rerun Harness experiment, use
`docs/templates/harness-improvement.md` instead.

## Lifecycle

```text
docs/plans/active/<slug>.md
  -> update progress and decisions during implementation
  -> record final validation and result
  -> move to docs/plans/completed/<slug>.md
```

The plan is the primary task artifact. Promote a lasting product or architecture
decision into `docs/decisions/`; keep task-local choices in the plan.

## Active Plans

Mỗi giai đoạn trong lộ trình (docs/product/plan-macos-v1.md) là một exec-plan.
Agent chỉ làm mục trong plan đang active; mỗi PR một mục.

Lộ trình v1 của bản macOS đã xong (giai đoạn 6 đóng 2026-10-19, qua G3; bản phát hành riêng là v0.1.0, gắn tag theo
Result của plan giai đoạn 6). Repo công khai từ 2026-10-21 với bản 0.1.1 (plan cong-khai-repo.md). Hiện không có plan
active.

Việc tiếp theo lập plan mới ở `active/` khi Nt0 quyết (bản Android v1.1: `android-v1.1.md` ở bước B1 của
docs/product/plan-android-v1.md; bản iOS: docs/product/plan-ios-v1.md).

Đã hoàn thành:

- [completed/giai-doan-0-chuan-bi.md](completed/giai-doan-0-chuan-bi.md) (2026-10-15)
- [completed/giai-doan-1-loi-dinh-dang.md](completed/giai-doan-1-loi-dinh-dang.md) (2026-10-15, qua G1)
- [completed/giai-doan-2-thu-vien.md](completed/giai-doan-2-thu-vien.md) (2026-10-15)
- [completed/giai-doan-3-lam-bai.md](completed/giai-doan-3-lam-bai.md) (tạm đóng 2026-10-16, G2 hoãn)
- [completed/giai-doan-4-soan-de.md](completed/giai-doan-4-soan-de.md) (tạm đóng 2026-10-17, G2 do Nt0 chạy trên bản cài)
- [completed/giai-doan-5-hoan-thien.md](completed/giai-doan-5-hoan-thien.md) (2026-10-18, không có cổng; test tay gom vào G3)
- [completed/giai-doan-6-beta-rieng.md](completed/giai-doan-6-beta-rieng.md) (2026-10-19, qua G3; DMG, nền đọc, dự án cá
  nhân của Nt0, bản phát hành riêng v0.1.0)
- [completed/cong-khai-repo.md](completed/cong-khai-repo.md) (2026-10-21; repo public một commit, giấy phép Apache-2.0,
  Release v0.1.1)
- [completed/android-v1.md](completed/android-v1.md) (2026-10-23, qua GA2, GA3; bản Android Học viên 0.1.0)

Giai đoạn 6 (Beta riêng) là giai đoạn cuối của lộ trình v1 (docs/product/plan-macos-v1.md); plan lập trong PR đóng giai
đoạn 5 (review-and-merge.md mục 4).

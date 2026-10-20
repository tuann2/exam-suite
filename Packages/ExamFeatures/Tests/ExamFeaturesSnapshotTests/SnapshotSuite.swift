import Testing

/// Suite cha của mọi snapshot test: chạy tuần tự (mỗi lúc một cửa sổ chụp, không chen nhau ở các điểm `await`).
@MainActor
@Suite("Snapshot sáng/tối 960×640", .serialized)
struct SnapshotSuite {}

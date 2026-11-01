import ExamFile
import ExamKit
import Foundation
@testable import LibraryData
import Testing

/// Đo main actor có bị chặn không: một task trên main actor ngủ 5 ms rồi ghi lại khoảng cách giữa hai
/// lần thức. Main actor bị chặn X ms thì sẽ có khoảng cách ≥ X ms.
@MainActor
final class MainActorHeartbeat {
    private(set) var longestGap: Duration = .zero
    private(set) var beats = 0
    private var task: Task<Void, Never>?

    func start() {
        task = Task { @MainActor in
            let clock = ContinuousClock()
            var last = clock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(5))
                let now = clock.now
                longestGap = max(longestGap, now - last)
                beats += 1
                last = now
            }
        }
    }

    func stop() async {
        task?.cancel()
        await task?.value
    }
}

@MainActor
@Suite("Đọc file ở nền")
struct BackgroundReadingTests {
    @Test("Bằng chứng âm: thước đo bắt được main actor bị chặn và bộ đếm bắt được lần đọc trên main thread")
    func instrumentsDetectBlocking() async throws {
        let beat = MainActorHeartbeat()
        beat.start()
        try await Task.sleep(for: .milliseconds(20))
        usleep(300_000) // chặn main actor 300 ms
        try await Task.sleep(for: .milliseconds(20))
        await beat.stop()
        #expect(beat.longestGap >= .milliseconds(250))

        let workspace = try TestWorkspace()
        let file = try workspace.write(makeExam(), to: "de.exam")
        let recorder = ReadRecorder()
        _ = try recorder.reader(file, .strict) // gọi thẳng trên main actor
        #expect(recorder.mainThreadReads == 1)
    }

    @Test("Số lần đọc cùng lúc không vượt maxConcurrentReads, khi nhập lẫn khi làm mới", arguments: [1, 3])
    func respectsMaxConcurrentReads(limit: Int) async throws {
        let workspace = try TestWorkspace()
        let recorder = ReadRecorder(delay: 0.1)
        let store = workspace.makeStore(recorder: recorder, maxConcurrentReads: limit)
        var urls: [URL] = []
        for index in 0 ..< 10 {
            urls.append(try workspace.write(makeExam(title: "Đề \(index)"), to: "de-\(index).exam"))
        }

        _ = await store.importFiles(urls)
        #expect(recorder.peakConcurrentReads <= limit)
        #expect(recorder.peakConcurrentReads >= min(limit, 2))

        for url in urls { try workspace.touch(url) }
        recorder.resetPeak()
        await store.refreshAll()
        #expect(recorder.peakConcurrentReads <= limit)
        #expect(recorder.peakConcurrentReads >= min(limit, 2))
        #expect(store.entries.count == 10)
        #expect(store.entries.allSatisfy { $0.status == .ready })
    }

    @Test(
        "Lần đọc treo khi làm mới: thôi chờ sau thời hạn, mục giữ trạng thái cũ, kết quả về muộn bị bỏ, lần sau đọc lại",
        .timeLimit(.minutes(1))
    )
    func hungReadDoesNotBlockRefresh() async throws {
        let workspace = try TestWorkspace()
        let gate = ReadGate()
        defer { gate.release() }
        // Chỉ lần kiểm treo có hạn (theo đồng hồ, như bản app); lần đọc file trên máy và lần đọc lại ở cuối
        // không bao giờ hết hạn. Trước đây hạn 2 giây áp cho mọi file nên khi máy bận (test đề lớn chạy song
        // song dồn hàng đợi file) lần đọc bình thường đôi khi quá hạn và test đỏ.
        let deadlines = TestDeadlines()
        let store = workspace.makeStore(reader: gate.reader, refreshDeadline: deadlines.deadline)
        let hung = makeExam(title: "Trên ổ mạng")
        let local = makeExam(title: "Trên máy")
        let hungFile = try workspace.write(hung, to: "o-mang.exam")
        let localFile = try workspace.write(local, to: "tren-may.exam")
        _ = await store.importFiles([hungFile, localFile])
        try workspace.write(makeExam(id: hung.id, title: "Ổ mạng đã đổi"), to: "o-mang.exam")
        try workspace.write(makeExam(id: local.id, title: "Trên máy đã đổi"), to: "tren-may.exam")
        gate.block("o-mang.exam")
        deadlines.useClock(.seconds(2), forNextCheckOf: hung.id)
        // Lưới an toàn: nếu cơ chế thời hạn hỏng, làm mới sẽ chờ lần đọc treo mãi. Tự mở chặn sau 15 giây để
        // test đỏ (lần đọc treo xong trước khi làm mới trả về: finishedReads = 2, tên mới) thay vì treo.
        Task.detached {
            try? await Task.sleep(for: .seconds(15))
            gate.release()
        }

        await store.refreshAll()

        #expect(!store.isRefreshing)
        #expect(store.entry(hung.id)?.status == .ready)
        #expect(store.entry(hung.id)?.title == "Trên ổ mạng")
        #expect(store.entry(local.id)?.title == "Trên máy đã đổi")
        #expect(gate.finishedReads(of: "o-mang.exam") == 1)

        // Lần đọc treo xong muộn: kết quả bị bỏ, mục không đổi. (30 giây chỉ là lưới an toàn.)
        gate.release()
        let lateReadFinished = try await waitUntil(timeout: .seconds(30)) {
            gate.finishedReads(of: "o-mang.exam") == 2
        }
        #expect(lateReadFinished)
        let inFlight = store.inFlightReads
        let cleared = try await waitUntil(timeout: .seconds(30)) { !inFlight.contains(hung.id) }
        #expect(cleared)
        try await Task.sleep(for: .milliseconds(100))
        #expect(store.entry(hung.id)?.title == "Trên ổ mạng")

        // Lần làm mới sau đọc lại.
        await store.refreshAll()
        #expect(store.entry(hung.id)?.title == "Ổ mạng đã đổi")
        #expect(store.entry(hung.id)?.status == .ready)
    }

    @Test(
        "Lần kiểm trước còn treo: các lần làm mới sau bỏ qua mục đó (không mở thêm lần đọc), xong rồi mới đọc lại",
        .timeLimit(.minutes(1))
    )
    func stillRunningCheckIsNotRestarted() async throws {
        let workspace = try TestWorkspace()
        let gate = ReadGate()
        defer { gate.release() }
        // Hạn do test quyết định, không theo đồng hồ: chỉ lần kiểm của file trên ổ mạng hết hạn, đúng lúc lần
        // đọc của nó đã bị chặn; lần kiểm file trên máy không bao giờ hết hạn. Trước đây hạn 1 giây áp cho mọi
        // file nên khi máy bận lần đọc "tren-may.exam" đôi khi quá hạn, mục giữ tên cũ và test đỏ.
        let deadlines = TestDeadlines()
        let store = workspace.makeStore(reader: gate.reader, refreshDeadline: deadlines.deadline)
        let hung = makeExam(title: "Trên ổ mạng")
        let local = makeExam(title: "Trên máy")
        let hungFile = try workspace.write(hung, to: "o-mang.exam")
        _ = await store.importFiles([hungFile, try workspace.write(local, to: "tren-may.exam")])
        try workspace.write(makeExam(id: hung.id, title: "Ổ mạng đã đổi"), to: "o-mang.exam")
        gate.block("o-mang.exam") { deadlines.expire(hung.id) }
        // Lưới an toàn như test trên: test đỏ chứ không treo nếu cơ chế thời hạn hỏng.
        Task.detached {
            try? await Task.sleep(for: .seconds(15))
            gate.release()
        }

        await store.refreshAll()
        #expect(gate.startedReads(of: "o-mang.exam") == 2)
        #expect(gate.finishedReads(of: "o-mang.exam") == 1)

        // Hai lần làm mới nữa trong lúc lần đọc vẫn treo: không mở thêm lần đọc, mục giữ nguyên.
        try workspace.write(makeExam(id: local.id, title: "Trên máy lần 2"), to: "tren-may.exam")
        await store.refreshAll()
        await store.refreshAll()
        #expect(gate.startedReads(of: "o-mang.exam") == 2)
        #expect(store.entry(hung.id)?.title == "Trên ổ mạng")
        #expect(store.entry(hung.id)?.status == .ready)
        #expect(store.entry(local.id)?.title == "Trên máy lần 2")
        #expect(!store.isRefreshing)

        // Lần đọc treo xong: lần làm mới kế tiếp đọc lại. (30 giây chỉ là lưới an toàn.)
        gate.release()
        let lateReadFinished = try await waitUntil(timeout: .seconds(30)) {
            gate.finishedReads(of: "o-mang.exam") == 2
        }
        #expect(lateReadFinished)
        let inFlight = store.inFlightReads
        let cleared = try await waitUntil(timeout: .seconds(30)) { !inFlight.contains(hung.id) }
        #expect(cleared)
        await store.refreshAll()
        #expect(gate.startedReads(of: "o-mang.exam") == 3)
        #expect(store.entry(hung.id)?.title == "Ổ mạng đã đổi")
    }

    @Test(
        "FileWork.run(timeout:) trả kết quả khi kịp, nil khi quá hạn, và resume đúng một lần khi hai bên gần như cùng lúc",
        .timeLimit(.minutes(1))
    )
    func fileWorkTimeout() async throws {
        #expect(await FileWork.run(timeout: .seconds(5)) { 42 } == 42)

        let semaphore = DispatchSemaphore(value: 0)
        // Lưới an toàn: nếu đồng hồ hết hạn hỏng, việc bị chặn sẽ chờ mãi. Tự mở chặn sau 3 giây để test
        // đỏ (trả 7 sau ≥ 3 giây) thay vì treo tới trần thời gian của job CI.
        Task.detached {
            try? await Task.sleep(for: .seconds(3))
            semaphore.signal()
        }
        let start = ContinuousClock.now
        let late = await FileWork.run(timeout: .milliseconds(50)) { () -> Int in
            semaphore.wait()
            return 7
        }
        let elapsed = ContinuousClock.now - start
        #expect(late == nil)
        #expect(elapsed < .seconds(2))

        // Việc xong đúng lúc hết hạn: CheckedContinuation sẽ dừng tiến trình nếu bị resume hai lần.
        var finished = 0
        var timedOut = 0
        for _ in 0 ..< 300 {
            let value = await FileWork.run(timeout: .milliseconds(1)) { () -> Int in
                Thread.sleep(forTimeInterval: 0.001)
                return 1
            }
            if value == nil { timedOut += 1 } else { finished += 1 }
        }
        #expect(finished + timedOut == 300)
    }

    @Test("Đọc file đề không chạy trên main thread: nhập, làm mới, tìm file, đề mẫu")
    func readsNeverRunOnMainThread() async throws {
        let workspace = try TestWorkspace()
        let recorder = ReadRecorder()
        let store = workspace.makeStore(samples: try SampleTests.makeSource(workspace), recorder: recorder)
        let exams = (0 ..< 5).map { makeExam(title: "Đề \($0)") }
        var urls: [URL] = []
        for (index, exam) in exams.enumerated() {
            urls.append(try workspace.write(exam, to: "de-\(index).exam"))
        }

        _ = await store.importFiles(urls)
        for url in urls { try workspace.touch(url) }
        await store.refreshAll()
        try FileManager.default.removeItem(at: urls[0])
        let moved = try workspace.write(exams[0], to: "Nơi khác/de-0.exam")
        try await store.relocate(exams[0].id, to: moved)
        await store.seedSamplesIfNeeded()

        #expect(recorder.totalReads >= 13)
        #expect(recorder.mainThreadReads == 0)
    }

    @Test("Nhập và làm mới 20 đề 2.000 câu: đọc ở nền, main actor không bị chặn", .timeLimit(.minutes(3)))
    func largeExamsDoNotBlockMainActor() async throws {
        let workspace = try TestWorkspace()
        let root = workspace.root
        // Dựng và ghi 20 đề lớn ngoài main actor.
        let exams: [Exam] = try await Task.detached {
            try (0 ..< 20).map { index in
                let exam = makeExam(title: "Đề lớn \(index)", questions: 2000)
                try ExamPackageWriter.write(ExamPackage(exam: exam), to: root.appendingPathComponent("lon-\(index).exam"))
                return exam
            }
        }.value
        let urls = (0 ..< 20).map { root.appendingPathComponent("lon-\($0).exam") }
        let firstURL = urls[0]
        let singleRead = await Task.detached {
            ContinuousClock().measure { _ = try? ExamPackageReader.read(contentsOf: firstURL, mode: .strict) }
        }.value

        let recorder = ReadRecorder()
        // Nhiều việc đọc cùng lúc hơn số nhân CPU: nếu việc đọc chiếm luồng của thread pool Swift
        // concurrency (số luồng bằng số nhân), task trên main actor sẽ không được đánh thức kịp.
        let concurrentReads = ProcessInfo.processInfo.activeProcessorCount + 4
        let store = workspace.makeStore(recorder: recorder, maxConcurrentReads: concurrentReads)
        let clock = ContinuousClock()

        let importBeat = MainActorHeartbeat()
        importBeat.start()
        let importStart = clock.now
        let report = await store.importFiles(urls)
        let importDuration = clock.now - importStart
        await importBeat.stop()

        #expect(report.addedExamIDs == exams.map(\.id))
        #expect(store.entries.allSatisfy { $0.summary.questionCount == 2000 && $0.status == .ready })

        for url in urls { try workspace.touch(url) }
        let readsBeforeRefresh = recorder.totalReads
        let refreshBeat = MainActorHeartbeat()
        refreshBeat.start()
        let refreshStart = clock.now
        await store.refreshAll()
        let refreshDuration = clock.now - refreshStart
        await refreshBeat.stop()

        #expect(recorder.totalReads - readsBeforeRefresh == 20)
        #expect(recorder.mainThreadReads == 0)
        #expect(store.entries.allSatisfy { $0.status == .ready })

        print("""
            LibraryData timing: one 2000-question strict read \(singleRead); \
            \(concurrentReads) reads at once; \
            import 20: \(importDuration), longest main-actor gap \(importBeat.longestGap) (\(importBeat.beats) beats); \
            refresh 20: \(refreshDuration), longest main-actor gap \(refreshBeat.longestGap) (\(refreshBeat.beats) beats)
            """)
        // Nếu đọc file chạy trên main actor hoặc chiếm hết luồng của Swift concurrency, main actor bị
        // chặn ít nhất trọn một lần đọc (singleRead). Ngưỡng rộng để không lệ thuộc máy CI.
        let limit = max(singleRead / 2, .milliseconds(200))
        #expect(importBeat.longestGap < limit)
        #expect(refreshBeat.longestGap < limit)
        // Main actor vẫn chạy đều trong suốt lần làm mới.
        #expect(refreshBeat.beats > 0)
    }
}

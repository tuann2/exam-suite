import Foundation
import InterfaceCore
import LibraryData
import Observation
import OSLog
import SessionModel

/// Mọi trạng thái của bản iOS, một bản cho cả app (`MobileScenes` giữ): Thư viện (`LibraryModel` dùng chung
/// với bản macOS), điều phối phiên thi, file nhận từ app khác.
@MainActor
public final class MobileAppModel {
    public let library: LibraryModel
    public let sessions: MobileSessionCoordinator
    /// Nơi lưu kho, đề mẫu và cài đặt (`AppLaunchStorage`: container của app; build Debug với `-ExamSuiteUITest
    /// <thư mục>` thì thư mục tạm của UI test).
    public let storage: AppLaunchStorage
    let received: ReceivedFiles

    private static let log = Logger(subsystem: LibraryConfiguration.iosBundleIdentifier, category: "files")

    /// - Parameter startsAutomatically: tải kho và tạo đề mẫu lần đầu ngay (app); test tắt để tự điều khiển.
    public init(storage: AppLaunchStorage, startsAutomatically: Bool = true) {
        self.storage = storage
        library = LibraryModel(
            store: .persistent(configuration: storage.configuration, defaults: storage.defaults),
            startsAutomatically: startsAutomatically
        )
        sessions = MobileSessionCoordinator(environment: .live(
            store: library.store,
            defaults: storage.defaults,
            timeScale: storage.sessionTimeScale
        ))
        received = ReceivedFiles(configuration: storage.configuration)
        connectLibraryToSessions()
    }

    /// Test: thư viện và môi trường phiên thi tiêm vào.
    init(library: LibraryModel, sessions: MobileSessionCoordinator, storage: AppLaunchStorage, received: ReceivedFiles) {
        self.library = library
        self.sessions = sessions
        self.storage = storage
        self.received = received
        connectLibraryToSessions()
    }

    private func connectLibraryToSessions() {
        library.sessionActions = LibrarySessionActions(
            openPreExam: { [weak sessions] examID, mode in
                Task { await sessions?.openPreExam(examID: examID, mode: mode) }
            },
            openAttempt: { [weak sessions] attempt in
                sessions?.openHistoryAttempt(attempt)
            }
        )
    }

    /// File `.exam` mở từ app khác (`onOpenURL`): dời khỏi `Inbox` nếu cần rồi đi qua đúng luồng Thêm đề của Thư viện
    /// (báo lỗi, hộp Dùng file mới / Huỷ, chọn đề vừa thêm). Đang làm bài thì màn làm bài vẫn hiện (đang Tạm dừng vì
    /// vừa rời app); đề vẫn được thêm, hộp hỏi và việc chọn đề hiện khi về Thư viện (QI12b).
    @discardableResult
    public func open(_ url: URL) -> Task<Void, Never> {
        let received = received
        let library = library
        return Task {
            let adopted = await Task.detached { () -> Result<URL, any Error> in
                Result { try received.adopt(url) }
            }.value
            switch adopted {
            case let .success(file):
                await library.openFromFinder([file]).value
            case let .failure(error):
                // Không dời được (hết chỗ…): thêm thẳng từ Inbox, Thư viện báo nếu file không dùng được.
                Self.log.error("Không dời được file nhận khỏi Inbox: \(String(describing: error), privacy: .public)") // l10n-ignore: log
                await library.openFromFinder([url]).value
            }
        }
    }

    /// App xuống nền: tạm dừng bài đang làm (`background`).
    public func didEnterBackground() {
        sessions.appDidEnterBackground()
    }

    /// App lên lại: làm mới trạng thái file (như cửa sổ Thư viện được kích hoạt lại ở bản macOS).
    public func didBecomeActive() {
        library.windowBecameActive()
    }
}

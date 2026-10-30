import InterfaceCore
import LibraryData
import SessionModel
import SwiftUI

/// Màn gốc của bản iOS: Thư viện trong `NavigationStack`; phiên thi (làm bài → Kết quả → Xem lại bài) là màn đẩy vào;
/// Trước khi thi là sheet. App xuống nền thì tự tạm dừng bài đang làm (`scenePhase`, mobile.md, mục Bản iOS).
public struct MobileRootView: View {
    private let app: MobileAppModel

    @Environment(\.scenePhase) private var scenePhase

    public init(app: MobileAppModel) {
        self.app = app
    }

    public var body: some View {
        let sessions = app.sessions
        NavigationStack {
            LibraryScreen(library: app.library, sessions: sessions, storage: app.storage)
                .navigationDestination(isPresented: Binding(
                    get: { sessions.isSessionPresented },
                    set: { presented in if !presented { sessions.returnToLibrary() } }
                )) {
                    if let session = sessions.session {
                        SessionScreen(session: session, sessions: sessions)
                            .id(session.id)
                    }
                }
        }
        .sheet(item: Binding(
            get: { sessions.preExam },
            set: { model in if model == nil { sessions.cancelPreExam() } }
        )) { model in
            PreExamScreen(
                model: model,
                onCancel: { sessions.cancelPreExam() },
                onStart: { Task { await sessions.startPreExam() } }
            )
            .interactiveDismissDisabled(model.isStarting)
        }
        // Màu nhấn teal của app (bảng màu số, có test tương phản) cho mọi màn, sheet và nút của thanh điều hướng.
        .tint(MobilePalette.accent)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: app.didEnterBackground()
            case .active: app.didBecomeActive()
            case .inactive: break
            @unknown default: break
            }
        }
    }
}

/// Màn của một phiên: làm bài, Kết quả hay Xem lại bài theo `session.screen`. Nút Quay lại hỏi "Bỏ bài?" khi bài chưa
/// nộp (như đóng cửa sổ làm bài của bản macOS); cử chỉ vuốt từ cạnh màn để quay lại bị tắt (ẩn nút Quay lại của hệ
/// thống), để không bỏ bài vì vuốt nhầm.
struct SessionScreen: View {
    let session: MobileSession
    let sessions: MobileSessionCoordinator

    @State private var isConfirmingDiscard = false

    var body: some View {
        Group {
            switch session.screen {
            case .attempt:
                if let attempt = session.attempt {
                    AttemptScreen(session: session, attempt: attempt)
                }
            case .results:
                if let results = session.results {
                    ResultsScreen(session: session, results: results, sessions: sessions)
                }
            case .answerReview:
                if let review = session.answerReview {
                    AnswerReviewScreen(session: session, review: review, sessions: sessions)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if session.hasUnsubmittedWork {
                        isConfirmingDiscard = true
                    } else {
                        sessions.returnToLibrary()
                    }
                } label: {
                    Label(localized("Thư viện"), systemImage: "chevron.backward")
                        .labelStyle(.titleAndIcon)
                }
                .accessibilityIdentifier("session.back")
            }
        }
        .alert(sessions.discardMessage, isPresented: $isConfirmingDiscard) {
            // Tiếp tục làm là mặc định; Bỏ bài không lưu gì (exam-taking.md, phương án 2).
            Button(localized("Tiếp tục làm"), role: .cancel) {}
            Button(localized("Bỏ bài"), role: .destructive) { sessions.discardSession() }
                .accessibilityIdentifier("session.discard")
        }
    }
}

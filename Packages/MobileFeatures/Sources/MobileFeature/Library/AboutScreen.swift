import InterfaceCore
import SwiftUI

/// Nội dung của màn Giới thiệu, đọc từ bundle của app: phiên bản và số build (Info.plist), toàn văn các file giấy phép đi
/// kèm (project.yml đưa `LICENSE`, `NOTICE`, `THIRD_PARTY_NOTICES.md` vào tài nguyên của target `ExamSuiteiOS`).
struct AboutInfo: Equatable {
    let version: String
    let build: String
    let license: String?
    let notice: String?
    let thirdPartyNotices: String?

    static func load(from bundle: Bundle) -> AboutInfo {
        func text(_ name: String, _ ext: String?) -> String? {
            bundle.url(forResource: name, withExtension: ext).flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        }
        return AboutInfo(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
            license: text("LICENSE", nil),
            notice: text("NOTICE", nil),
            thirdPartyNotices: text("THIRD_PARTY_NOTICES", "md")
        )
    }
}

/// **Giới thiệu** (plan-ios-v1.md QI13: iOS không có hộp Giới thiệu như macOS), mở từ menu của Thư viện: cùng nội dung
/// với hộp Giới thiệu của bản macOS (`Apps/Student/*.lproj/Credits.rtf`), kèm toàn văn giấy phép Apache-2.0, NOTICE và
/// giấy phép của ZIPFoundation.
struct AboutScreen: View {
    let info: AboutInfo
    @Environment(\.dismiss) private var dismiss

    static let sourceURL = URL(string: "https://github.com/tuann2/exam-suite")!

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: "Exam Suite")
                            .font(.title2.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                        Text("Phiên bản \(info.version) (\(info.build))", bundle: .module)
                            .foregroundStyle(MobilePalette.secondaryText)
                            .accessibilityIdentifier("about.version")
                    }
                    Text("Exam Suite là dự án cá nhân của Nt0.", bundle: .module)
                    Text("Giấy phép Apache 2.0 · © 2026 Nt0", bundle: .module)
                    Text("Dùng ZIPFoundation (giấy phép MIT) · © 2017–2025 Thomas Zoechling", bundle: .module)
                    Link(destination: Self.sourceURL) {
                        Label(localized("Mã nguồn và giấy phép"), systemImage: "arrow.up.right.square")
                    }
                }
                Section {
                    SectionHeader(localized("Giấy phép"))
                    licenseLink(localized("Giấy phép Apache 2.0"), info.license, identifier: "about.license")
                    licenseLink(localized("Thông báo (NOTICE)"), info.notice, identifier: "about.notice")
                    licenseLink(localized("Thư viện bên thứ ba"), info.thirdPartyNotices, identifier: "about.thirdParty")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(localized("Giới thiệu"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("Xong")) { dismiss() }
                        .accessibilityIdentifier("about.done")
                }
            }
        }
    }

    /// Dòng mở toàn văn một file giấy phép; thiếu file trong bundle (không xảy ra ở bản build của project.yml) thì ẩn.
    @ViewBuilder
    private func licenseLink(_ title: String, _ text: String?, identifier: String) -> some View {
        if let text {
            NavigationLink(title) {
                LicenseTextView(title: title, text: text)
            }
            .accessibilityIdentifier(identifier)
        }
    }
}

/// Toàn văn một file giấy phép (chữ trơn, giữ nguyên dòng như file).
struct LicenseTextView: View {
    let title: String
    let text: String

    var body: some View {
        ScrollView {
            Text(verbatim: text)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

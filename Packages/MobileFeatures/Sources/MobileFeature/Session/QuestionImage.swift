import InterfaceCore
import SwiftUI
import UIKit

/// Ảnh của câu (màn làm bài, chi tiết Xem lại bài): giải mã ngoài main thread mỗi khi câu đổi (`preparingForDisplay`),
/// như `.task(id: data)` của `QuestionImageView` bản macOS, để đổi câu không chờ giải mã ảnh (đo đề chuẩn ở bước I3:
/// giải mã trong `body` làm lần đổi sang câu có ảnh chậm nhất 74–103 ms, ngân sách 16 ms). Ảnh hỏng thì hiện "Không hiện
/// được ảnh của câu này" như macOS.
struct QuestionImage: View {
    let data: Data
    /// Chạm để phóng to (màn làm bài); nil thì ảnh chỉ để xem.
    var onZoom: ((UIImage) -> Void)?

    @State private var image: UIImage?
    /// Dữ liệu ảnh của lần giải mã gần nhất: khác `data` nghĩa là đang giải mã ảnh của câu mới.
    @State private var decodedData: Data?

    var body: some View {
        Group {
            if decodedData != data {
                // Đang giải mã: chưa hiện gì (thường vài mili giây).
                Color.clear.frame(height: 1)
            } else if let image {
                if let onZoom {
                    Button {
                        onZoom(image)
                    } label: {
                        picture(image)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("question.image")
                    .accessibilityLabel(localized("Ảnh của câu hỏi"))
                    .accessibilityHint(localized("Chạm để phóng to"))
                } else {
                    picture(image)
                        .accessibilityLabel(localized("Ảnh của câu hỏi"))
                }
            } else {
                Label(localized("Không hiện được ảnh của câu này"), systemImage: "photo.badge.exclamationmark")
                    .foregroundStyle(MobilePalette.secondaryText)
            }
        }
        .task(id: data) {
            let source = data
            let decoded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                // Chỉ báo hỏng khi không đọc được ảnh (như `NSImage(data:)` của macOS): `preparingForDisplay()` trả nil
                // với vài định dạng điểm ảnh thì dùng ảnh chưa giải mã trước.
                let image = UIImage(data: source)
                return image?.preparingForDisplay() ?? image
            }.value
            guard !Task.isCancelled else { return }
            image = decoded
            decodedData = source
        }
    }

    private func picture(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 280)
            .frame(maxWidth: .infinity)
    }
}

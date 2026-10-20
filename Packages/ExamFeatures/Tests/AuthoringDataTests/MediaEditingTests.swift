@testable import AuthoringData
import ExamFile
import ExamKit
import Foundation
import Testing

/// Ảnh (authoring.md, mục Ảnh): byte gốc, tên SHA-256, ảnh trùng lưu một lần, ảnh thừa bỏ khi lưu,
/// không đổi tên ảnh đã có, giới hạn của `ExamPackageLimits`.
@Suite("Ảnh của câu")
struct MediaEditingTests {
    @Test("Thêm ảnh: giữ byte gốc, tên media/<16 hex SHA-256>.<đuôi chữ thường>; Hoàn tác bỏ cả byte ảnh mới",
          arguments: ["png", "JPG", "jpeg", "gif", "webp", "HEIC"])
    func addImage(ext: String) throws {
        var draft = try RepoFixtures.kienThucChung()
        let q = draft.exam.sections[1].questions[0].id
        let bytes = imageBytes(1)
        var path = ""
        try checkUndoRedo(&draft) {
            let result = try $0.setImage(of: q, data: bytes, fileExtension: ext)
            path = result.path
            return result.inverse
        }
        #expect(path == (try MediaNaming.path(for: bytes, fileExtension: ext)))
        #expect(path.hasSuffix("." + ext.lowercased()))
        #expect(draft.question(q).image == path)
        #expect(draft.package.media[path] == bytes)
        #expect(draft.validationIssues.isEmpty)
        let saved = try checkRoundTrip(draft, strict: true)
        #expect(saved.media[path] == bytes)
        #expect(saved.media.count == 2)
    }

    @Test("Hoàn tác thêm ảnh mới xoá byte ảnh khỏi gói; ảnh đã có thì giữ")
    func undoAddRemovesNewBytesOnly() throws {
        var draft = try RepoFixtures.kienThucChung()
        let original = draft.package.media
        let q = draft.exam.sections[1].questions[0].id
        let inverse = try draft.setImage(of: q, data: imageBytes(2), fileExtension: "png").inverse
        #expect(draft.package.media.count == 2)
        try draft.apply(inverse)
        #expect(draft.package.media == original)

        // Ảnh trùng ảnh có sẵn: Hoàn tác không xoá ảnh có sẵn.
        let existing = try #require(original.first)
        let inverse2 = try draft.setImage(of: q, data: existing.value, fileExtension: "png").inverse
        #expect(draft.question(q).image == existing.key)
        try draft.apply(inverse2)
        #expect(draft.package.media == original)
        #expect(draft.question(q).image == nil)
    }

    @Test("Ảnh trùng byte chỉ lưu một lần, dùng chung đường dẫn")
    func duplicateImageStoredOnce() throws {
        var draft = try RepoFixtures.kienThucChung()
        let ids = draft.exam.allQuestions.map(\.id)
        let bytes = imageBytes(3)
        let a = try draft.setImage(of: ids[1], data: bytes, fileExtension: "png").path
        let b = try draft.setImage(of: ids[3], data: bytes, fileExtension: "png").path
        // Cùng byte, đuôi khác: vẫn dùng lại ảnh đã có.
        let c = try draft.setImage(of: ids[4], data: bytes, fileExtension: "jpg").path
        #expect(a == b && b == c)
        let saved = try checkRoundTrip(draft, strict: true)
        #expect(saved.media.count == 2)
    }

    @Test("Thay ảnh: ảnh cũ giữ cho Hoàn tác, bỏ khi lưu nếu không câu nào dùng; xoá ảnh tương tự")
    func replaceAndRemoveImage() throws {
        var draft = try RepoFixtures.kienThucChung()
        let q = draft.exam.sections[0].questions[0].id
        let oldPath = try #require(draft.question(q).image)
        try checkUndoRedo(&draft) { try $0.setImage(of: q, data: imageBytes(4), fileExtension: "webp").inverse }
        #expect(draft.question(q).image != oldPath)
        #expect(draft.package.media[oldPath] != nil)
        let saved = try checkRoundTrip(draft, strict: true)
        #expect(saved.media[oldPath] == nil)
        #expect(Array(saved.media.keys) == [try #require(draft.question(q).image)])

        try checkUndoRedo(&draft) { try $0.removeImage(of: q) }
        #expect(draft.question(q).image == nil)
        #expect(draft.package.media.count == 2)
        let empty = try checkRoundTrip(draft, strict: true)
        #expect(empty.media.isEmpty)
        #expect(try draft.removeImage(of: q).isEmpty)
    }

    @Test("Ảnh còn câu khác dùng thì vẫn được lưu khi một câu bỏ ảnh")
    func sharedImageKeptWhileUsed() throws {
        var draft = try RepoFixtures.kienThucChung()
        let first = draft.exam.sections[0].questions[0]
        let path = try #require(first.image)
        let other = draft.exam.sections[1].questions[1].id
        try draft.setImage(of: other, data: try #require(draft.package.media[path]), fileExtension: "png")
        #expect(draft.question(other).image == path)
        try draft.removeQuestion(first.id)
        let saved = try checkRoundTrip(draft, strict: true)
        #expect(Array(saved.media.keys) == [path])
    }

    @Test("Từ chối đuôi không hỗ trợ, ảnh quá lớn, gói vượt giới hạn; đề không đổi")
    func rejectsInvalidImages() throws {
        var draft = try RepoFixtures.kienThucChung()
        let before = draft
        let q = draft.exam.sections[1].questions[0].id
        for ext in ["bmp", "svg", "", "png.exe", ".png"] {
            #expect(throws: ExamEditError.unsupportedImageType(ext)) {
                try draft.setImage(of: q, data: imageBytes(5), fileExtension: ext)
            }
        }
        let limits = ExamPackageLimits(mediaEntryBytes: 100, totalUncompressedBytes: 300, entryCount: 3)
        #expect(throws: ExamEditError.imageTooLarge(bytes: 101, limit: 100)) {
            try draft.setImage(of: q, data: Data(count: 101), fileExtension: "png", limits: limits)
        }
        #expect(draft == before)
        // Tổng dung lượng (kể cả exam.json): xem totalLimitCountsManifest. Ở đây: ảnh có sẵn của đề (câu
        // khác còn dùng) một mình đã vượt trần thì không thêm được ảnh nào.
        let existingSize = try #require(draft.package.media.values.first).count
        let tight = ExamPackageLimits(totalUncompressedBytes: existingSize)
        #expect(throws: ExamEditError.packageTooLarge(limit: existingSize)) {
            try draft.setImage(of: q, data: Data(repeating: 7, count: 1), fileExtension: "png", limits: tight)
        }
        #expect(draft == before)
        // Số entry: exam.json + ảnh có sẵn + ảnh mới = 3 vừa đủ; ảnh thứ ba thì vượt.
        let roomy = ExamPackageLimits(entryCount: 3)
        try draft.setImage(of: q, data: imageBytes(6), fileExtension: "png", limits: roomy)
        let after = draft
        let other = draft.exam.sections[1].questions[1].id
        #expect(throws: ExamEditError.tooManyImages(limit: 3)) {
            try draft.setImage(of: other, data: imageBytes(7), fileExtension: "png", limits: roomy)
        }
        #expect(draft == after)
        // Thay ảnh của chính câu đó không làm tăng số ảnh được lưu.
        try draft.setImage(of: q, data: imageBytes(8), fileExtension: "png", limits: roomy)

        #expect(throws: ExamEditError.questionNotFound(fixedID(99))) {
            try draft.setImage(of: fixedID(99), data: imageBytes(9), fileExtension: "png")
        }
    }

    @Test("Trần tổng dung lượng tính cả exam.json: đúng trần thì lưu rồi mở lại được với cùng giới hạn, vượt 1 byte thì từ chối")
    func totalLimitCountsManifest() throws {
        let base = try RepoFixtures.kienThucChung()
        let q = base.exam.sections[1].questions[0].id
        // Ảnh 200 byte; đo exam.json và ảnh có sẵn sau khi gắn ảnh (bằng giới hạn rộng).
        var probe = base
        let path = try probe.setImage(of: q, data: Data(repeating: 1, count: 200), fileExtension: "png").path
        let saved = try ExamPackageReader.read(probe.fileData(), mode: .strict)
        let manifest = try ExamJSON.encode(saved.exam).count
        let exact = manifest + saved.media.values.reduce(0) { $0 + $1.count }
        #expect(saved.media[path]?.count == 200)

        let limits = ExamPackageLimits(totalUncompressedBytes: exact)
        var atLimit = base
        try atLimit.setImage(of: q, data: Data(repeating: 1, count: 200), fileExtension: "png", limits: limits)
        let reopened = try ExamPackageReader.read(atLimit.fileData(), mode: .strict, limits: limits)
        #expect(reopened == atLimit.packageForSaving)

        // Ảnh lớn hơn 1 byte: tổng (kể cả exam.json) vượt trần, bị từ chối; không có kiểm này thì file
        // lưu ra bị chính bộ đọc từ chối.
        var over = base
        #expect(throws: ExamEditError.packageTooLarge(limit: exact)) {
            try over.setImage(of: q, data: Data(repeating: 2, count: 201), fileExtension: "png", limits: limits)
        }
        #expect(over == base)
        var unchecked = base
        try unchecked.setImage(of: q, data: Data(repeating: 2, count: 201), fileExtension: "png")
        #expect(throws: ExamFileError.tooLarge(entry: ExamPackageLimits.totalSizeName, limit: exact)) {
            try ExamPackageReader.read(unchecked.fileData(), mode: .strict, limits: limits)
        }
    }

    @Test("Không bao giờ đổi tên ảnh đã có: ảnh của file cũ giữ tên dù không theo 16 hex SHA-256")
    func neverRenamesExistingImages() throws {
        // Ảnh đặt tên 64 hex (schema cho phép 16–64) và không khớp nội dung.
        var package = try RepoFixtures.package("kien-thuc-chung")
        let oldPath = try #require(package.exam.sections[0].questions[0].image)
        let bytes = try #require(package.media[oldPath])
        package.media[oldPath] = nil
        let legacyPath = "media/" + String(repeating: "ab", count: 32) + ".png"
        package.media[legacyPath] = bytes
        package.exam.sections[0].questions[0].image = legacyPath
        var draft = ExamDraft(package: package)
        let q = draft.exam.sections[0].questions[0].id
        let fingerprint = QuestionFingerprint.fingerprint(of: draft.question(q))

        // Sửa đề nhiều cách: tên ảnh không đổi, dấu vân tay câu không đổi.
        try draft.moveSections(fromOffsets: [0], toOffset: 2)
        try draft.moveQuestion(q, toSection: draft.exam.sections[0].id)
        draft.setTitle("Đề đổi tên")
        // Thêm cùng byte ảnh cho câu khác: dùng lại đường dẫn cũ.
        let other = draft.exam.sections[0].questions[0].id
        let reused = try draft.setImage(of: other, data: bytes, fileExtension: "png").path
        #expect(reused == legacyPath)
        #expect(draft.package.media.keys.sorted() == [legacyPath])

        let saved = try checkRoundTrip(draft, strict: true)
        #expect(saved.media.keys.sorted() == [legacyPath])
        let reread = try #require(saved.exam.question(id: q))
        #expect(reread.image == legacyPath)
        #expect(QuestionFingerprint.fingerprint(of: reread) == fingerprint)
    }

    @Test("Trùng tên với ảnh khác nội dung (trùng tiền tố SHA-256): từ chối, không ghi đè")
    func refusesToOverwriteDifferentBytes() throws {
        var draft = try RepoFixtures.kienThucChung()
        let bytes = imageBytes(10)
        let path = try MediaNaming.path(for: bytes, fileExtension: "png")
        // Giả lập: gói đã có ảnh khác nội dung ở đúng đường dẫn đó.
        let q0 = draft.exam.sections[1].questions[0].id
        try draft.apply(.group([.insertMedia(path: path, data: imageBytes(11))]))
        try draft.updateQuestion(q0) { $0.image = path }
        let before = draft
        let q = draft.exam.sections[1].questions[1].id
        #expect(throws: ExamEditError.mediaNameCollision(path)) {
            try draft.setImage(of: q, data: bytes, fileExtension: "png")
        }
        #expect(throws: ExamEditError.mediaNameCollision(path)) {
            try draft.apply(.insertMedia(path: path, data: bytes))
        }
        #expect(draft == before)
        #expect(draft.package.media[path] == imageBytes(11))
    }

    @Test("Đề đọc dễ thiếu ảnh: sửa và lưu được, tham chiếu thiếu giữ nguyên")
    func missingMediaStillSaves() throws {
        var package = try RepoFixtures.package("kien-thuc-chung")
        let path = try #require(package.exam.sections[0].questions[0].image)
        package.media = [:]
        var draft = ExamDraft(package: package)
        #expect(draft.validationIssues.map(\.code) == [.imageNotFound])
        draft.setTitle("Vẫn lưu")
        let saved = try checkRoundTrip(draft, strict: false)
        #expect(saved.missingMedia == [path])
        #expect(throws: ExamFileError.self) { try ExamPackageReader.read(draft.fileData(), mode: .strict) }
    }
}

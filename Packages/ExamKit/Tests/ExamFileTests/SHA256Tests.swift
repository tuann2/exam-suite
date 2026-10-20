import Foundation
import Testing
@testable import ExamFile

@Suite("SHA-256 thuần Swift và đặt tên ảnh")
struct SHA256Tests {
    // Vector chuẩn FIPS 180-4 / NIST.
    @Test("Chuỗi rỗng")
    func empty() {
        #expect(SHA256.hexDigest(Data()) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    @Test("\"abc\"")
    func abc() {
        #expect(SHA256.hexDigest(Data("abc".utf8))
            == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test("Chuỗi 448 bit (hai khối sau khi đệm)")
    func twoBlocks() {
        let input = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
        #expect(SHA256.hexDigest(Data(input.utf8))
            == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
    }

    @Test("1.000.000 ký tự \"a\"")
    func millionA() {
        let input = Data(repeating: UInt8(ascii: "a"), count: 1_000_000)
        #expect(SHA256.hexDigest(input) == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
    }

    @Test("Biên đệm: 55, 56, 63, 64, 65 ký tự a (vector từ python3 hashlib)", arguments: [
        (55, "9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318"),
        (56, "b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a"),
        (63, "7d3e74a05d7db15bce4ad9ec0658ea98e3f06eeecf16b4c6fff2da457ddc2f34"),
        (64, "ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb"),
        (65, "635361c48bb9eab14198e76ea8ab7f1a41685d6ad62aa9146d301d4f17eb0ae0"),
    ])
    func paddingBoundaries(length: Int, expected: String) {
        #expect(SHA256.hexDigest(Data(repeating: UInt8(ascii: "a"), count: length)) == expected)
    }
}

@Suite("MediaNaming")
struct MediaNamingTests {
    @Test("isValidPath khớp mẫu image của schema", arguments: [
        ("media/0123456789abcdef.png", true),
        ("media/" + String(repeating: "a", count: 64) + ".heic", true),
        ("media/" + String(repeating: "a", count: 65) + ".png", false),
        ("media/0123456789abcde.png", false),
        ("media/0123456789ABCDEF.png", false),
        ("media/0123456789abcdef.PNG", false),
        ("media/0123456789abcdeg.png", false),
        ("media/0123456789abcdef", false),
        ("media/a/0123456789abcdef.png", false),
        ("media/../0123456789abcdef.png", false),
        ("0123456789abcdef.png", false),
        ("media/0123456789abcde\u{0301}f.png", false),
    ])
    func validPath(path: String, valid: Bool) {
        #expect(MediaNaming.isValidPath(path) == valid)
    }

    @Test("Tên ảnh của fixture kien-thuc-chung khớp hash nội dung")
    func fixtureImageName() throws {
        let url = RepoPaths.examDirectory("kien-thuc-chung").appendingPathComponent("media/9d5dc894e10f060d.png")
        let data = try Data(contentsOf: url)
        #expect(try MediaNaming.path(for: data, fileExtension: "png") == "media/9d5dc894e10f060d.png")
    }

    @Test("Đuôi viết hoa được đổi về chữ thường")
    func lowercasesExtension() throws {
        let path = try MediaNaming.path(for: Data("abc".utf8), fileExtension: "JPEG")
        #expect(path == "media/ba7816bf8f01cfea.jpeg")
    }

    @Test("Mọi đuôi hợp lệ được nhận", arguments: ["png", "jpg", "jpeg", "gif", "webp", "heic"])
    func allowedExtensions(ext: String) throws {
        #expect(try MediaNaming.path(for: Data(), fileExtension: ext).hasSuffix(".\(ext)"))
    }

    @Test("Đuôi không hỗ trợ bị từ chối", arguments: ["bmp", "svg", "", ".png", "tiff"])
    func rejectsExtension(ext: String) {
        #expect(throws: ExamFileError.unsupportedImageType(ext)) {
            try MediaNaming.path(for: Data(), fileExtension: ext)
        }
    }
}

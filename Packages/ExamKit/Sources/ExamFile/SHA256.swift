import Foundation

/// SHA-256 thuần Swift theo FIPS 180-4. Tự cài đặt vì CryptoKit không có trên
/// Linux và ADR 0006 không cho thêm swift-crypto. Chỉ dùng để đặt tên ảnh theo
/// nội dung, không dùng cho mục đích bảo mật.
enum SHA256 {
    private static let k: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ]

    private static let initial: [UInt32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ]

    /// Băm 32 byte của `data`.
    static func digest(_ data: Data) -> [UInt8] {
        // Đệm: thêm bit 1, các bit 0, rồi độ dài (tính bằng bit) 64-bit big-endian,
        // cho đủ bội số 64 byte.
        var message = [UInt8](data)
        let bitLength = UInt64(data.count) &* 8
        message.append(0x80)
        while message.count % 64 != 56 { message.append(0) }
        for shift in stride(from: 56, through: 0, by: -8) {
            message.append(UInt8(truncatingIfNeeded: bitLength >> UInt64(shift)))
        }

        var h = initial
        var w = [UInt32](repeating: 0, count: 64)
        // Vòng nén viết cho bản Debug cũng đủ nhanh (đặt tên 200 ảnh ~60 MB của đề chuẩn khi đọc `.oef`; large-exams.md):
        // con trỏ thay cho mảng, phép dịch có mặt nạ (`&>>`, `&<<`) và vòng `while` thay cho hàm `rotr`, phép dịch
        // generic và vòng `for … in` (ở -Onone mỗi thứ là một lời gọi hàm). Thuật toán không đổi (SHA256Tests).
        message.withUnsafeBufferPointer { bytes in
            w.withUnsafeMutableBufferPointer { w in
                k.withUnsafeBufferPointer { k in
                    h.withUnsafeMutableBufferPointer { h in
                        var chunk = 0
                        while chunk < bytes.count {
                            var t = 0
                            while t < 16 {
                                let i = chunk &+ t &* 4
                                w[t] = UInt32(bytes[i]) &<< 24 | UInt32(bytes[i &+ 1]) &<< 16
                                    | UInt32(bytes[i &+ 2]) &<< 8 | UInt32(bytes[i &+ 3])
                                t &+= 1
                            }
                            while t < 64 {
                                let x = w[t &- 15], y = w[t &- 2]
                                let s0 = (x &>> 7 | x &<< 25) ^ (x &>> 18 | x &<< 14) ^ (x &>> 3)
                                let s1 = (y &>> 17 | y &<< 15) ^ (y &>> 19 | y &<< 13) ^ (y &>> 10)
                                w[t] = w[t &- 16] &+ s0 &+ w[t &- 7] &+ s1
                                t &+= 1
                            }
                            var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7]
                            t = 0
                            while t < 64 {
                                let s1 = (e &>> 6 | e &<< 26) ^ (e &>> 11 | e &<< 21) ^ (e &>> 25 | e &<< 7)
                                let ch = (e & f) ^ (~e & g)
                                let t1 = hh &+ s1 &+ ch &+ k[t] &+ w[t]
                                let s0 = (a &>> 2 | a &<< 30) ^ (a &>> 13 | a &<< 19) ^ (a &>> 22 | a &<< 10)
                                let maj = (a & b) ^ (a & c) ^ (b & c)
                                let t2 = s0 &+ maj
                                hh = g; g = f; f = e; e = d &+ t1
                                d = c; c = b; b = a; a = t1 &+ t2
                                t &+= 1
                            }
                            h[0] = h[0] &+ a; h[1] = h[1] &+ b; h[2] = h[2] &+ c; h[3] = h[3] &+ d
                            h[4] = h[4] &+ e; h[5] = h[5] &+ f; h[6] = h[6] &+ g; h[7] = h[7] &+ hh
                            chunk &+= 64
                        }
                    }
                }
            }
        }
        return h.flatMap { word in (0 ..< 4).map { UInt8(truncatingIfNeeded: word >> UInt32(24 - $0 * 8)) } }
    }

    /// Băm dạng 64 ký tự hex chữ thường.
    static func hexDigest(_ data: Data) -> String {
        let hex = Array("0123456789abcdef")
        var out = ""
        out.reserveCapacity(64)
        for byte in digest(data) {
            out.append(hex[Int(byte >> 4)])
            out.append(hex[Int(byte & 0x0f)])
        }
        return out
    }
}

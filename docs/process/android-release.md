# Phát hành bản Android

APK phát riêng, ký bằng keystore của Nt0 (Q10 của [plan-android-v1.md](../product/plan-android-v1.md)). Keystore và mật
khẩu chỉ ở máy của Nt0, không vào git, không lên GitHub (CI không đóng APK). Người dùng cài theo
[install-android.md](../install-android.md).

## Một lần: tạo keystore (Nt0)

```bash
mkdir -p ~/.config/exam-suite && chmod 700 ~/.config/exam-suite
keytool -genkeypair -v -keystore ~/.config/exam-suite/examsuite-android.jks -alias examsuite \
  -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=Nt0"
```

`keytool` (JDK 17) hỏi mật khẩu; keystore PKCS12 dùng một mật khẩu cho cả kho và khoá. Rồi tạo
`~/.config/exam-suite/android-signing.properties` (quyền 600), đường dẫn đầy đủ, không dùng `~`:

```properties
storeFile=/Users/<tên>/.config/exam-suite/examsuite-android.jks
storePassword=<mật khẩu>
keyAlias=examsuite
keyPassword=<mật khẩu>
```

`android/app/build.gradle.kts` đọc file này (hoặc file trong biến `EXAMSUITE_ANDROID_SIGNING`); không có file thì bản
release không được ký.

**Sao lưu keystore và mật khẩu ra ngoài máy.** Mất keystore thì bản sau không cài đè được: người dùng phải gỡ app và mất
Thư viện, lịch sử thi (dữ liệu không sao lưu, mobile.md).

## Mỗi bản phát hành

1. PR tăng `versionCode` (luôn tăng) và `versionName` trong `android/app/build.gradle.kts`, thêm mục vào
   `android/CHANGELOG.md`; merge khi check `android`, `local/verify` (mức none) và `local/verify-android` xanh trên SHA
   cuối (review-and-merge.md mục 2).
2. Trên SHA đó của `main`, tree sạch:

   ```bash
   (cd android && ./gradlew :app:assembleRelease)
   $ANDROID_HOME/build-tools/35.0.0/apksigner verify --print-certs android/app/build/outputs/apk/release/app-release.apk
   mkdir -p dist
   cp android/app/build/outputs/apk/release/app-release.apk dist/ExamSuite-<versionName>.apk
   cp LICENSE dist/LICENSE.txt && cp NOTICE dist/NOTICE.txt
   cp android/THIRD_PARTY_NOTICES.md dist/THIRD_PARTY_NOTICES.txt
   ```

   Chứng chỉ in ra phải là của Nt0 (`CN=Nt0`, SHA-256 như các bản trước; bản đầu ghi vào `android/CHANGELOG.md`).
3. Nt0 cài APK lên điện thoại, chạy thử (cổng GA3 với bản đầu), rồi gắn tag `android-v<versionName>` trên đúng SHA và
   đẩy tag (chỉ Nt0; tag chạy job `android` lint + test của `.github/workflows/android.yml`, không đóng APK).
4. Gửi `dist/ExamSuite-<versionName>.apk` cùng `LICENSE.txt`, `NOTICE.txt`, `THIRD_PARTY_NOTICES.txt` (Apache-2.0 đòi
   người nhận có giấy phép; bản macOS để chúng trong DMG, ADR 0001) và hướng dẫn cài.

Bản release chưa bật R8 (rút gọn, tối ưu mã) ở 0.1.0: test Compose chỉ chạy trên bản debug (Decisions A4 của exec-plan
`android-v1`).

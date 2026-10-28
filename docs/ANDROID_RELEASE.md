# Android release APK 만들기

앱 ID는 `kr.localstudy.jlpt_study`입니다. 현재 공개판은 `1.0.13+14`, GitHub 태그는 `v1.0.13-beta.1`입니다. release는 실행 방식과 최적화 구분이고 beta는 콘텐츠 검수·기기 검증이 남은 배포 상태입니다. release APK도 beta로 공개할 수 있습니다.

## 설치 파일 선택

- 범용 `jlpt-study-release.apk`: ARM32, ARM64, x86_64를 포함합니다. 일반 휴대폰과 x86_64 에뮬레이터에 사용할 수 있습니다.
- `jlpt-study-arm64-release.apk`: ARM64만 포함해 더 작습니다. 기능·콘텐츠는 같습니다.
- `.apk.zip`: 같은 APK를 압축한 파일입니다. 압축 해제 후 APK를 설치합니다.
- `SHA256SUMS.txt`: 다운로드 파일의 SHA-256 목록입니다.

기존 debug 서명과 release 서명은 다릅니다. debug 앱에서 옮길 때는 앱 설정의 백업 파일을 안전하게 보관한 뒤 앱 삭제·release 설치·복원을 진행하세요. 기존 앱을 삭제하지 않고 두 서명으로 같은 앱 ID를 동시에 설치할 수는 없습니다. 이후 업데이트에서는 같은 배포 키를 사용하고 `pubspec.yaml`의 빌드 번호를 증가시킵니다. Flutter ABI 분할 APK에는 별도의 높은 versionCode가 붙으므로 가능하면 설치한 종류(범용/ARM64)를 계속 사용하세요. ARM64판에서 범용판으로 교체할 때 버전 다운그레이드로 거부될 수 있습니다.

## 서명 준비 (Windows / Linux)

저장소의 소스·DB는 공개하지만 배포 개인 키와 암호는 공개하지 않습니다. 기존 배포 앱을 업데이트하는 관리자는 **최초 배포에 사용한 키**를 안전한 보관 위치에서 가져와야 합니다. 새 키를 만들면 기존 배포 앱에 업데이트할 수 없습니다.

독립된 새 앱을 배포할 경우에만 새 키를 생성합니다. JDK의 `keytool`을 사용하며 암호는 대화형 입력으로 설정합니다.

```powershell
# Windows PowerShell: 공개 저장소 밖에 키 저장
New-Item -ItemType Directory -Force "$env:USERPROFILE\.jlpt-signing"
keytool -genkeypair -v -keystore "$env:USERPROFILE\.jlpt-signing\release.jks" -storetype JKS -alias jlpt-release -keyalg RSA -keysize 4096 -validity 10000
Copy-Item android/key.properties.example android/key.properties
```

```bash
# Linux: 공개 저장소 밖에 키 저장
install -d -m 700 "$HOME/.local/share/jlpt-signing"
keytool -genkeypair -v -keystore "$HOME/.local/share/jlpt-signing/release.jks" -storetype JKS -alias jlpt-release -keyalg RSA -keysize 4096 -validity 10000
cp android/key.properties.example android/key.properties
chmod 600 android/key.properties "$HOME/.local/share/jlpt-signing/release.jks"
```

`android/key.properties`에 실제 `storeFile`, `storePassword`, `keyAlias`, `keyPassword`를 기입합니다. Windows 경로는 `C:/Users/사용자/.jlpt-signing/release.jks`처럼 `/`를 쓰세요. 예시 파일의 값은 실제 키가 아닙니다. 키와 암호는 별도로 암호화 백업하고 Git, 소스 ZIP, GitHub Releases에 넣지 마세요. 이 프로젝트는 누락된 서명을 debug 서명으로 대체하지 않습니다.

## 검사 및 빌드

Flutter 3.47.8 / Dart 3.13.7 / JDK 17 / Android SDK 36 환경에서 빌드합니다. Android Studio SDK 경로와 JDK 설정은 README의 Windows 안내를 참고하세요. Windows/Linux에서 동일한 Flutter 명령을 사용합니다.

```text
flutter pub get
flutter analyze
flutter test
python -m unittest discover -s pipeline/tests -v
python pipeline/self_test.py
python pipeline/audit_report.py --db assets/content.sqlite --outdir reports/audit
flutter build apk --release
```

범용 APK: `build/app/outputs/flutter-apk/app-release.apk`. 다른 폴더에 먼저 복사한 뒤 ARM64판을 생성합니다.

같은 작업 폴더에서 `flutter test`와 Android 빌드를 동시에 실행하지 마세요. 테스트가 플러그인 등록 파일을 다시 생성하므로, 테스트 종료 후 위처럼 `--no-pub` 없이 release를 빌드해 배포용 등록 파일을 갱신합니다.

```text
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

ARM64 APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. `apksigner verify --verbose --print-certs`로 APK 서명과 인증서 SHA-256을 확인합니다. 인증서는 `Android Debug`가 아니어야 하며 두 APK의 인증서가 같아야 합니다.

패키징하려면 범용을 `dist/jlpt-study-release.apk`, ARM64를 `dist/jlpt-study-arm64-release.apk`로 복사하고 공개 파일을 Git에 추가한 뒤 `python pipeline/package_artifacts.py --release`를 실행합니다. APK에 포함된 DB·ABI, ZIP CRC 및 압축 전후 SHA-256을 확인하고 소스 ZIP과 체크섬 파일을 만듭니다. 소스는 Git에서 관리하는 파일만 포함하며 실수로 관리된 서명 파일은 차단합니다.

데이터 검수 게이트는 별개입니다. `python pipeline/release_gate.py --db assets/content.sqlite --strict --report reports/v1-readiness.json`은 현재 종료 코드 2를 반환합니다. 이 결과를 검수 완료로 바꾸지 말고 미리보기 상태로 배포하세요.

공식 안내: [Flutter Android 배포](https://docs.flutter.dev/deployment/android), [Android 앱 서명](https://developer.android.com/studio/publish/app-signing).

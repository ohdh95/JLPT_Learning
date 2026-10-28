# Linux 에뮬레이터 실행 확인 — 2026-10-28 (KST)

- Ubuntu 22.04.5 LTS x86_64, KVM 사용 가능.
- Android Emulator 37.2.12, Android API 36 x86_64 가상 기기를 실제 GUI 창으로 부팅.
- 기존 범용 `dist/jlpt-study-debug.apk`를 `adb install -r`로 설치: Success.
- `kr.localstudy.jlpt_study/.MainActivity`가 최상위 실행 Activity임을 확인.
- 실제 홈 화면을 확인하고 `android/linux-emulator-home.png`로 저장.
- `run-emulator.sh` 실행으로 기존 기기 재사용·APK 업데이트·앱 실행 성공.
- Python 구문 검사, shell 구문 검사, desktop-file-validate 통과.
- 앱 메뉴 바로가기: 하루 한 장 JLPT (Android).
- SDK/가상 기기를 `~/.local/share/jlpt-study/`로 이동했고 기존 임시 경로에는 호환 심볼릭 링크를 유지.
- 앱 APK와 기존 Dart 기능 코드는 변경하지 않음. 휴대폰 실기기·스피커의 실제 발음 청취를 새로 검증한 것은 아님.

## 중단한 별도 데스크톱 작업

사용자가 에뮬레이터를 선호하여 Linux 전용 변경은 `dist/jlpt-linux-desktop-wip-source.zip`에 별도로 보관한 후 원래 소스로 복원했다. 중간 변경에서 `flutter analyze`와 Flutter 테스트 24개, Linux release 빌드는 통과했으나 Linux 데스크톱 앱 실행과 음성 재생은 검증하지 않았다. `linux-*.log`는 해당 중간 작업의 기록이며 현재 제공하는 APK의 추가 검증 결과가 아니다.

# 일본어 완전정복 · 1.0.10+11

2026-10-28 (Asia/Seoul)

## 반영 내용

- 앱 이름: **일본어 완전정복**
- 부제: **가나부터 JLPT N1까지**
- 첫 화면의 제목과 부제, Flutter 앱 제목, Android 설치 이름, iOS 표시 이름, Linux 실행 바로가기 이름과 설명, README에 적용했다.
- 하단 단어·한자·가나·별표·문법 메뉴를 유지했다. Android 앱 ID `kr.localstudy.jlpt_study`, 내부 프로젝트 이름 및 사용자 DB 스키마는 유지했다.
- Android 설치 아이콘은 기존 초록색 배경·흰색 펼친 책·금색 책갈피 벡터를 유지했다. Linux 실행 바로가기는 기존 시스템 교육 아이콘을 사용한다. iOS 아이콘은 이번 작업에서 변경하지 않았다.

## 실제 확인

| 검사 | 결과 | 근거 |
|---|---|---|
| Flutter analyze | 문제 없음 | app-name-analyze.log |
| Flutter 테스트 | 59개 통과 | app-name-flutter-tests.log |
| Python 테스트 | 31개 통과 | app-name-python-tests.log |
| 데이터 파이프라인 self_test | 합성 fixture 통과 | app-name-self-test.log |
| 콘텐츠 감사 | 무결성/외래키 오류 없음 | app-name-audit.log |
| Android 범용·ARM64 빌드 | 성공 | app-name-build.log, app-name-arm64-build.log |
| APK 서명 | 두 파일 모두 검증 통과 | app-name-apk-signature.log, app-name-arm64-signature.log |
| APK 이름·버전·ABI | 실제 앱 이름 확인, 버전 1.0.10, 범용 코드 11 / ARM64 코드 2011 | app-name-apk-metadata.json |
| Android 에뮬레이터 업데이트 | 설치 성공, 첫 화면 이름·부제 확인 | app-name-install.json, app-name-screens/home.png |
| 사용자 데이터 | 설치 직전/직후 7개 테이블의 모든 기존 행 동일, 스키마 3 유지 | app-name-install.json |
| iOS 메타데이터 | plist 파싱 및 두 표시 이름 확인 | ios/Runner/Info.plist |

Android API 36 x86_64 에뮬레이터에서 기존 앱을 삭제하지 않고 업데이트했다. 첫 화면 캡처를 직접 확인했으며 기존 사용자 데이터는 별도로 백업했다. iOS 실행·빌드 및 ARM64 실물 기기 실행은 이번 작업에서 확인하지 않았다.

콘텐츠 SHA-256은 `be94baa977fdd415a20fd96898b3754988997e4ca2ac2c3b9320995dc845047b`로 이전 버전과 동일하다. 콘텐츠 검수 상태와 남은 검수 항목은 이전 보고서 `LEARNING_FLOW_UPDATE.md`를 따른다.

## 전달 파일

`dist/jlpt-study-debug.apk.zip`, `dist/jlpt-study-arm64-debug.apk.zip`, `dist/jlpt-study-source.zip`을 제공한다. APK는 개발용 디버그 서명이다. 포장 도구는 APK/ZIP CRC, 내장 DB 해시와 ABI, 압축 전후 APK 해시를 검사하고 결과를 `artifacts.json`, 최종 체크섬을 `dist/SHA256SUMS.txt`에 기록한다.

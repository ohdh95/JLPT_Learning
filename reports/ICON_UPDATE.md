# 일본어 완전정복 · 벚꽃색 あ 아이콘 · 1.0.11+12

2026-10-28 (Asia/Seoul)

## 반영 내용

- 앱 이름은 **일본어 완전정복**, 부제는 **가나부터 JLPT N1까지**다. 첫 화면, 플랫폼 표시 이름과 Linux 실행 바로가기에 반영했다.
- 기존 책 아이콘을 연한 벚꽃색 배경, 짙은 분홍색 **あ**, 작은 벚꽃으로 교체했다. 원본은 `design/app_icon.svg`, 미리보기는 `design/app_icon.png`다.
- Android에는 구형 기기용 5개 해상도 PNG와 적응형 아이콘·벡터 전경을 적용했다. 실제 API 36 에뮬레이터 홈 화면에서 새 원형 아이콘이 표시되는 것을 확인했다.
- iOS 앱 아이콘의 모든 크기와 마케팅용 1024px 이미지를 불투명 RGB PNG로 생성했다. Linux 실행 바로가기에도 같은 SVG를 연결했다.
- SVG에는 Noto Sans CJK JP Bold의 あ 윤곽선을 포함한다. 폰트 설치나 네트워크가 필요하지 않으며 출처·라이선스는 `design/ICON_NOTICE.txt`, `design/NOTO_FONT_LICENSE.txt`에 보존했다.
- 앱 내부 기능·테마, 콘텐츠 DB, 패키지 ID와 사용자 DB 스키마는 유지했다. 일반 Flutter 빌드는 생성된 아이콘을 사용하고, 재생성은 `tool/export_app_icon.py`로 수행한다.

## 실제 검증

| 검사 | 결과 | 근거 |
|---|---|---|
| Dart 코드 분석·Flutter 회귀 검사 | 문제 없음, 59개 통과 | app-name-analyze.log, app-name-flutter-tests.log |
| 데이터 파이프라인 검사 | Python 31개 및 합성 self_test 통과, 콘텐츠 무결성/외래키 오류 없음 | app-name-python-tests.log, app-name-self-test.log, app-name-audit.log |
| 아이콘 파일 | Android XML 파싱, PNG 해상도, iOS PNG 크기·불투명 RGB 확인 | icon-assets.json |
| 범용·ARM64 APK 빌드 및 서명 | 성공 | icon-build.log, icon-arm64-build.log, icon-*-signature.log |
| APK 메타데이터 | 이름 일본어 완전정복, 버전 1.0.11, 코드 12 / ARM64 2012, 새 아이콘 리소스 포함 | icon-apk-metadata.json |
| 에뮬레이터 설치 | 기존 앱에 업데이트 성공, 첫 화면 이름·부제 및 홈 화면 아이콘 확인 | icon-install.json, icon-screens/home.png, icon-screens/launcher-home.png |
| 사용자 데이터 보존 | 스키마 3 유지, 기존 7개 테이블 모든 행 동일 | icon-install.json |

Dart/파이프라인 검사는 앱 이름·부제 변경 후 실행했다. 이후 변경은 아이콘 리소스·내보내기 도구·버전·문서에 한정하며 Android 빌드와 리소스 검증을 별도로 실행했다. iOS는 리소스만 생성·검사했고 빌드 및 실물 기기 실행은 확인하지 않았다. Linux 바로가기의 아이콘 연결을 변경했으며 데스크톱 UI의 캐시 갱신 여부는 별도 확인하지 않았다.

콘텐츠 DB SHA-256은 `be94baa977fdd415a20fd96898b3754988997e4ca2ac2c3b9320995dc845047b`로 동일하다. 콘텐츠 검수 상태와 남은 항목은 `LEARNING_FLOW_UPDATE.md`를 따른다. 이름 변경 직후의 중간 결과는 `APP_NAME_UPDATE.md`에 보존한다.

## 전달 파일

- `dist/jlpt-study-debug.apk.zip`: 범용 APK
- `dist/jlpt-study-arm64-debug.apk.zip`: ARM64 APK
- `dist/jlpt-study-source.zip`: 소스, 아이콘 원본·내보내기 도구, 콘텐츠 DB, 검사 결과

APK는 개발용 디버그 서명이다. 포장 도구는 CRC, 내장 콘텐츠 DB 해시, ABI, 압축 전후 APK 해시를 확인하고 `artifacts.json`, `dist/SHA256SUMS.txt`에 기록한다.

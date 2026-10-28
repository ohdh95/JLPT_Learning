> 최신 1.0.5+6 전체 예문 검토 및 검증 결과는 [FULL_EXAMPLE_REVIEW.md](FULL_EXAMPLE_REVIEW.md)를 참고하세요. 아래는 이전 버전 기록입니다.

> 최신 1.0.4+5 예문 연결·전체 번역·실제 검증 결과는 [EXAMPLE_UPDATE.md](EXAMPLE_UPDATE.md)를 참고하세요. 아래는 이전 버전 기록입니다.

> 최신 한국어 현지화 및 1.0.3+4 검증은 [LOCALIZATION_UPDATE.md](LOCALIZATION_UPDATE.md)를 참고하세요. 아래는 초기 구현 당시 기록입니다.

# 실제 검증 기록

최신 버전 **1.0.2+3**의 품사 분류·문법 탭·훈음 표시 변경과 실제 검사 결과는 [GRAMMAR_UPDATE.md](GRAMMAR_UPDATE.md)에 기록했다. Flutter 테스트 29개, Python 테스트 10개, 분석, 두 APK 빌드·서명·ZIP 및 에뮬레이터 업데이트를 확인했다. 이전 단어 화면 개선은 [STUDY_LAYOUT.md](STUDY_LAYOUT.md), 아래는 초기 1.0.0 구현 당시의 검증 기록이다.

검증일: 2026-10-28 (Asia/Seoul). 환경: Ubuntu 22.04, Flutter 3.47.8, Dart 3.13.7, Temurin JDK 17, Android SDK 35/36, Build-Tools 36.0.0, NDK 28.2.13676358.

## 완료된 검사

| 검사 | 실제 결과 | 근거 |
|---|---|---|
| Android API 36 x86_64 실제 SQLite/UI 통합 검사 | 1개 통과, BUILD SUCCESSFUL | android_instrumentation.log / android/*.xml |
| 일반 실행용 APK 빌드·설치 | 성공, 기본 main.dart 대상 APK 설치 후 홈 표시 확인 | apk_build.log / android/home.png |
| Flutter 정적 분석 | No issues found | flutter_analyze.log |
| Dart 저장소·상태·위젯·TTS 테스트 | 18개 통과 | flutter_test.log |
| Python 파이프라인 테스트 | 10개 통과 | python_tests.log |
| 첨부 파이프라인 자체 테스트 | 통과, 합성/8단어 한정 | pipeline_self_test.log |
| SQLite integrity_check | ok | database_checks.json |
| SQLite foreign_key_check | 오류 0개 | database_checks.json |
| 전체 OpenJLPT 수입 | 7,811단어, 2,383한자, 13,718예문; 메타데이터 일치 | import.json |
| 전체 실제 JMdict 대조 | 218,969항목 스캔; 7,788 일치 / 21 미발견 / 2 ID 충돌 | jmdict.json |
| 한국어 검수 출시 게이트 | 기대대로 실패(종료 코드 2), 확정 단어 0 | release_gate_strict.log |

한국어 뜻 17개와 한자 훈음 15개는 사용자 제공 샘플을 정확히 대응시킨 **초안**입니다. 검수 완료는 0개이며, 나머지 한국어 뜻 7,794개/훈음 2,368개/예문 번역 13,718개는 미제공입니다. 표기/읽기/ID 일치도 한국어 검수와 구분됩니다.

원본 단어에 나오는 한자 중 OpenJLPT의 독립 한자 카탈로그에 없는 글자는 159종입니다. 연결을 삭제하거나 가짜 한자 정보를 만들지 않고 source_review 및 UI의 준비 중 상태로 보존합니다. 이 때문에 word_kanji.character는 카탈로그 외래키를 강제하지 않으며 word_id 관계는 외래키로 검사합니다.

## 자동 테스트가 다루는 동작

- 실제 전체 DB의 검색/정렬/페이지 경계, 모든 결과 7,811개 선택.
- 페이지·급수·검색·별표·페이지 크기 변경 후 선택 보존, 부분 선택 상태, 재시작 복원.
- 9개 항목과 세 프로필 독립 저장, 임시 공개 원복, 사용자 지정 페이지 크기 검증.
- 중복 없는 셔플, 뒤집기 전 평가 차단, 연속 탭 중복 평가 차단, 중단/재개, 직전 평가 수정, 평가별 재시험.
- 별표와 평가 독립성, 최근 평가 기준 진도, 콘텐츠에서 단어 삭제 후에도 사용자 기록과 스냅샷 보존.
- 백업 왕복, 손상된 세션/설정 및 DB 실패 시 복원 롤백.
- 320px 화면·1.5배 글꼴·다크 모드, 실제 DB에 연결된 목록/학습/결과 UI.
- TTS 미설치/플랫폼 오류 처리 및 일본어 언어/음성 요청: 플랫폼 채널 모킹 테스트로 음질을 확인한 것은 아님.
- 부분 원본 차단, 기존 사용자 DB 보존, ZIP 경로 탈출 차단, 한국어 검수 근거 조건, 변경 이력, JMdict 제한 읽기 및 합성 데이터 검증 격리.

## 발견하고 수정한 사항

- Android 시스템 SQLite의 FTS5 부재 가능성: FTS5 의존 제거 및 LIKE 검색으로 통일.
- 원본 구축 중 실패로 이전 DB가 지워지는 문제: 임시 파일 구축 후 정상 완료 시 교체.
- 미검증 데이터 인증 가능성: 검토자/날짜/독립 출처/근거 조건 강화, 합성 JMdict는 test_fixture_only.
- 화면 테스트에서 setState 콜백이 Future를 반환하던 오류 수정. 긴 예문에 영향받지 않도록 테스트 평가 버튼 하단 고정.
- 위젯 테스트의 SQLite 실제 I/O를 테스트 시계와 함께 처리하도록 수정. 가짜 저장소로 성공 결과를 대체하지 않음.

## 검증 한계

실물 휴대폰에서 TTS 음질/음성 데이터 설치, 제조사별 시스템 파일 선택기, iOS 빌드는 확인하지 않았습니다. 한국어 내용과 일본어 의미/품사/예문 자연스러움에 대한 사람 검수는 수행하지 않았습니다. 완성된 한국어 교재 데이터가 아닙니다.

## Android 통합 테스트 경로

`flutter test integration_test/app_test.dart`와 `flutter drive`는 이 에뮬레이터에서 DDS/VM 서비스 연결 끊김 또는 `integration_test.VmServiceProxyGoldenFileComparator` stream 오류를 보였습니다. 이를 성공이라고 계산하지 않았습니다. 동일한 테스트 본문을 Android의 기본 instrumentation 실행기에서 다음 명령으로 실행하여 테스트 1개, 실패 0개를 확인했습니다.

```sh
cd android
./gradlew app:connectedAndroidTest -Ptarget=integration_test/app_test.dart
```

테스트 기기: 직접 만든 Android 16(API 36), x86_64 에뮬레이터. 실물 기기는 아닙니다. 테스트는 설치된 앱의 bundled SQLite/sqflite와 실제 Flutter 위젯을 사용합니다. TTS 출력은 이 흐름에서 대체 어댑터로 처리하므로 실제 발음을 들었다는 뜻은 아닙니다.

## 일반 앱 APK 확인

통합 테스트가 끝난 뒤 반드시 `flutter build apk --debug --target lib/main.dart`로 일반 앱을 새로 빌드했습니다. 이 파일을 `dist/jlpt-study-debug.apk`에 복사해 Android 에뮬레이터에 설치하고 홈 화면을 확인했습니다. 전달용 APK는 통합 테스트 엔트리포인트로 만들어진 테스트 APK가 아닙니다. 디버그 서명이며 Play Store 배포용이 아닙니다.

- Wi-Fi와 모바일 데이터를 모두 끈 에뮬레이터에서 일반 앱의 7,811개 단어 목록 조회를 확인했습니다 (`android/words-offline.png`).
- ARM64 분할 APK도 빌드했습니다 (`apk_split_build.log`). ARM64 실물 단말 실행 확인은 하지 않았습니다.

최종 전달 파일의 SHA-256과 바이트 수는 `artifacts.json`에 기록했습니다. 두 APK 내부 `assets/flutter_assets/assets/content.sqlite`가 작업 폴더의 최종 콘텐츠 DB와 바이트 단위로 같음을 확인했습니다. 범용 APK의 디버그 서명도 `apksigner verify`로 확인했습니다 (`apk_signature.log`).

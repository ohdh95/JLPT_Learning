> 최신 1.0.5+6 전체 예문 검토 및 검증 결과는 [FULL_EXAMPLE_REVIEW.md](FULL_EXAMPLE_REVIEW.md)를 참고하세요. 아래는 이전 버전 기록입니다.

# 예문 연결·전체 한국어 번역 · 1.0.4+5

2026-10-28 · Linux / Flutter 3.47.8 / Dart 3.13.7 / JDK 17 / Android API 36 x86_64.

## 완료한 기능

- 예문에서 밑줄 친 단어를 누르면 해당 단어 학습 페이지로 이동한다. 뒤로 가면 원래 카드·스크롤·선택을 유지한다. 동형 표기가 여러 항목으로 연결되면 표제어·읽기·뜻을 보고 선택한다.
- 예문은 기본 접힘이며, 펼친 뒤에도 각 문장의 해석은 별도의 **해석 보기**를 눌러야 나타난다. 예문 전체를 접었다 열거나 다른 단어로 이동하면 해석도 다시 접힌다.
- 학습/테스트 카드·단어 목록·한자 화면에서 초안·미검수 문구를 제거했다. 데이터 검수 화면·DB 검수 상태·출처·변경 이력은 보존한다. 표시 제거가 검증 완료를 뜻하지 않는다.
- 기존 한국어 뜻 7,811개, 훈음 2,542자와 **예문 번역 13,718개 전체**를 제공한다. 기기에서 단어 연결·해석을 보는 데 네트워크나 번역 엔진이 필요하지 않다.

## 데이터 작업과 검토 범위

| 급수 | 예문 번역 입력 |
|---|---:|
| N5 | 1,320 / 1,320 |
| N4 | 1,238 / 1,238 |
| N3 | 3,218 / 3,218 |
| N2 | 3,094 / 3,094 |
| N1 | 4,848 / 4,848 |
| 전체 | 13,718 / 13,718 |

원본 영어 풀이 12,556개 고유 문장을 Google Translate 웹 엔드포인트로 한국어 번역했다. 공개된 사전 예문만 전송했으며 사용자 DB·기록·계정 정보는 전송하지 않았다. 호출 간격과 실패 시 지연·중단, 재개 캐시를 두었고 응답에 포함된 원문 구간을 요청 원문과 정확히 비교했다. 문장 경계를 넘거나 일부가 사라지는 응답은 분할 재시도하며 잘못된 예문 ID에 붙이지 않는다. 실제 앱은 저장된 번역만 사용한다. 공개 웹 엔드포인트는 계약형 API가 아니므로 향후 작동을 보장하지 않는다.

기존 일본어 대조 교정본을 유지하고 이번에 **185개 항목**의 교정을 추가했다. 부분 부정(부모님 두 분 다 살아 계신 것은 아니다), 관용표현(two-timing, off and on, shoot the bull, blue, make ends meet), 영어 풀이에서 사라진 형제 호칭 등을 일본어 기준으로 고쳤다. 일본어와 영어가 모두 같은 문장에만 교정을 공유했다. 최종 반영 방식은 **AI 원문 대조 교정 506개 / 자동 번역 13,212개**다. 이는 독립된 사람 검수 건수가 아니다.

M2M100과 MADLAD는 표본에서 의미 오류를 발견하여 해당 번역 후보를 앱에 수입하지 않았다. 원시 후보·비교 표본은 파이프라인/보고서에 보존한다. Google 번역도 표본에서 오류가 있었고 확인한 항목을 교정했다. 13,718개 전체를 문맥 단위로 검수했다고 주장하지 않는다. `examples-final-sample.json`은 75개 표본의 교정 전 자동 번역이며 최종값은 DB와 교정 JSONL을 참고한다.

「荷物が遅れた場合、特別な連帯保険がある。」는 일본어와 영어 delay insurance가 어긋나는 원문이다. 요청에 맞춰 일본어를 직역해 번역을 채웠지만 `SOURCE_SENTENCE_CONFLICT` 이슈는 유지했다.

SudachiPy 0.6.11 / SudachiDict-core 20260723으로 단어 경계·활용형을 분석하고, 표기·읽기·ID가 검증된 단어만 공식 JMdict 대체 표기를 추가했다. 읽기 제한과 `re_nokanji`를 적용했다. **모든 예문에 하나 이상의 링크**, 링크 72,895개, 연결된 단어 ID 7,141개다. 단어 경계 전체의 최장 일치와 사전형을 사용하며 글자 일부를 무조건 연결하지 않는다. UTF-16 위치를 저장해 Dart 문자열 위치와 일치한다. 동음이의어·형태소 분석의 모든 문맥 판정이 정확하다는 의미는 아니다. 사전 엔진과 모델 가중치는 APK에 포함하지 않는다.

전체 비어 있는 번역 0, 자동 형식 검사 경고 0, SQLite integrity `ok`, FK 오류 0을 확인했다. 표제어·읽기·급수·일본어/영어 예문 등 원본 필드는 이번 작업 전 DB와 동일하다. 단어 뜻·훈음·예문 모두 `human_reviewed` 0을 유지하며 `release_gate.py --strict`는 예상대로 종료 코드 2다. 검수 CSV는 `review_templates/examples_20261028/`에 새로 내보냈다.

## 실제 검사

| 검사 | 결과 | 근거 |
|---|---|---|
| Flutter analyze | No issues found | examples-analyze.log |
| Flutter 전체 테스트 | 35개 통과 | examples-flutter-tests.log |
| 예문 동작 테스트 | 5개 통과, 전체 35개에 포함 | examples-interaction-tests.log |
| Python 전체 테스트 | 22개 통과 | examples-python-tests.log |
| 파이프라인 자체 검사 | 합성 fixture 범위 통과 | examples-self-test.log |
| 데이터 감사·원본 보존 | 무결성/FK/번역 입력/원본 필드 검사 통과 | examples-data-checks.json, audit/quality_summary.json |
| 엄격 출시 게이트 | 예상 차단, 종료 2 | examples-release-gate.log |
| 범용·ABI 분할 APK | 빌드 성공, 두 전달 APK 서명 검증 성공 | examples-apk-build.log, examples-apk-split-build.log, examples-apk-signature.log |
| Android 업데이트 | 1.0.3+4 → 1.0.4+5, 설치 직전/직후 실제 user.db 바이트 동일 | examples-install.json |

새 위젯 검사는 문장별 해석 기본 숨김·독립 토글·재접힘, 링크 클릭 후 돌아오기와 선택 유지, 여러 후보 선택, 테스트 중 링크 클릭 시 카드 뒤집힘/평가 방지, UTF-16 이모지와 recognizer 정리를 확인한다. 파이프라인 검사는 모든 링크의 경계·중첩·참조, 활용형 연결, 예문 응답 원문 불일치·잘림·잘못된 순서 차단, 전체 ID 집합/원문 검증, 교정 우선 적용을 포함한다. 기존 320px 화면, 선택/별표/백업/재시험/문법 검사도 통과했다.

실제 320×640 에뮬레이터에서 会う의 예문을 펼치고 두 해석이 접혀 있음을 확인했다. 예문의 パーティー를 눌러 단어 학습 1/1로 이동한 뒤 돌아와 기존 1/20 카드와 스크롤 위치가 유지되는 것을 확인했다. 첫 해석을 펼쳐도 두 번째 해석은 접힌 채 남는다. 학습 카드에 초안·미검수 문구가 없다. 근거 화면은 `android/examples-revealed.png`, `examples-toggles.png`, `examples-linked-word.png`, `examples-return.png`, `examples-translation-open.png`다.

실물 Android 기기·iOS와 일본어 TTS 음질은 이번 작업에서 새로 확인하지 않았다. 자동 번역의 의미·관용표현 전체 검수, 기존 사전 연결 21개 미발견/2개 ID 충돌, 품사 누락 11개, 한국식 훈음 대안과 예문 문맥 검수는 남아 있다.

## 전달 파일과 재현

- `dist/jlpt-study-debug.apk.zip`: 범용 APK. 이 Linux PC의 x86_64 에뮬레이터용.
- `dist/jlpt-study-arm64-debug.apk.zip`: ARM64 Android 휴대폰용.
- `dist/jlpt-study-source.zip`: 앱·전체 DB·번역/교정 JSONL·검수 CSV·보고서.
- `dist/SHA256SUMS.txt`: 위 파일과 압축 전 APK의 SHA-256.
- 빌드·설치·Windows/Linux 사용법: README.
- 콘텐츠 재생성 후 `apply_localization.py` → `apply_example_translations.py` → `build_example_links.py` 순서로 재적용. 저장된 번역 재적용에는 인터넷이 필요 없다.
- APK/ZIP 검사·패키징 도구: `python pipeline/package_artifacts.py` (두 APK를 먼저 빌드하여 dist에 복사).

콘텐츠 SHA-256: `89567839a965caa45fcd08320647434001ce8c3f4b79e93a19b4cd9a0ad50ba7`.

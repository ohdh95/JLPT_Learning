# 전체 예문 검토 · 1.0.5+6

2026-10-28 · Ubuntu 22.04 / Flutter 3.47.8 / Dart 3.13.7 / JDK 17 / Android API 36.

## 완료한 변경

N5~N1 예문 **13,718개 전체**를 대상으로 일본어와 한국어의 의미·부정·시제·주어·관용표현·자연스러움을 AI가 한 차례 대조했다. 일본어와 기존 한국어가 같은 항목을 묶은 **12,615개 문장쌍을 모두 읽고** 유지/수정 결정을 기록했다. **3,819개 문장쌍, 실제 예문 행 4,134개**의 번역을 수정했다. 이 수치는 오류가 전혀 없음을 보증하거나 독립된 사람 검수가 끝났다는 뜻은 아니다.

| 급수 | 검토한 예문 행 | 번역이 바뀐 행 |
|---|---:|---:|
| N5 | 1,320 | 394 |
| N4 | 1,238 | 410 |
| N3 | 3,218 | 918 |
| N2 | 3,094 | 995 |
| N1 | 4,848 | 1,417 |
| 합계 | 13,718 | 4,134 |

- `공개 닫기`를 **정답 닫기**로 변경했다.
- `단어 발음은 가나 읽기를 참고하세요.` 안내를 일반·암기 카드에서 제거했다. 검증된 한자별 읽기가 없으면 해당 빈 안내 영역도 표시하지 않는다.
- 예문과 해석 기본 접힘, 밑줄 친 단어 이동, 선택·별표·평가 보존은 유지한다.
- 한국어 뜻 7,811개, 한자 2,542자와 단어 연결 72,895개는 이번 예문 수정 전 DB와 동일하다.

## 교정 예

| 일본어 | 이전 번역 | 수정 번역 |
|---|---|---|
| 堤防が都市を洪水から守ってくれた。 | 은행은 홍수로부터 도시를 보호했습니다. | 제방이 도시를 홍수로부터 지켜 주었다. |
| 彼は生まれつき積極性に乏しかった。 | 그는 본질적으로 독단적이었습니다. | 그는 타고나기를 적극성이 부족했다. |
| 彼はその理屈がわからないほどばかではない。 | 그 사람은 너무 현명해서 그 이유를 알지 못합니다. | 그는 그 이치를 모를 만큼 어리석지는 않다. |
| 彼がパチンコするなんて絶対にないよ。 | 그는 파칭코를 하다가 죽지 않을 것입니다. | 그가 파친코를 할 리는 절대로 없어. |
| 梅酒はね、梅で作る和風リキュールのことだよ。 | 우메슈는 자두로 만든 일본 리큐어입니다. | 우메슈는 매실로 만드는 일본식 리큐르야. |

전체 수정 전후: [full-review-changes.csv](full-review-changes.csv). 모든 유지/수정 결정은 `pipeline/localization/full_review/decisions.jsonl`에 있다. 후속 교정은 이전 결정을 삭제하지 않고 amendments 이력으로 남겼다.

## 검수 근거와 미완료 항목

- 원문 오기, 일본어와 영어의 불일치, 날짜·사실 확인 등이 필요한 **94개 문장쌍(97개 예문 ID)**은 `source_issues.jsonl` 및 DB `source_review`에 미해결로 남겼다. 이를 번역 검증 완료로 처리하지 않았다. 기존 사전·한자 이슈와 합한 source_review 전체는 338건이다.
- `連帯保険`와 영어 `delay insurance`가 어긋나는 예문은 배송 지연 문맥과 영어를 참고해 “지연 보험”으로 잠정 교정했다. 일본어 원문 확인은 여전히 필요하다. 몇몇 원문이 손상된 문장도 동일하게 근거와 불확실성을 기록했다.
- 한자 `道`의 획수와 조사 `は`·`が`를 설명하는 두 문장은 한국어 안에 해당 일본어 글자를 직접 인용해야 한다. 형식 검사의 미번역 문자 경고에 개별 예외 사유를 기록했다. 포괄적인 검사 우회는 하지 않았다.
- 전수 검토에서는 새 번역 API·번역 모델을 호출하지 않았다. 저장된 일본어/한국어를 읽고 교정했다. 이전 자동 번역은 이력으로 남긴다.
- 모든 예문의 현재 작성 방식은 `assistant_ja_ko_review`, 상태는 `draft`다. **사람 검수 완료는 0건**이다. 단어 뜻·한자 훈음에 대해서도 사람 검수 완료를 새로 부여하지 않았다.
- 독립된 사람의 내용 검수, 원문 94건 해결, 동형이의어 링크 문맥, 기존 JMdict 미발견 21개/ID 충돌 2개 및 품사 누락 11개는 남아 있다.

## 재현과 검증

`review_all_examples.py`는 전체 ID 누락/중복, 부분 검토, 원문 변경, 잘못된 유지/수정 분류, 허위 사람 검수, 변경된 파일 해시를 거부한다. `manifest.json`은 입력·결정·출력·원문 이슈 파일의 SHA-256과 건수를 포함한다. 앱 반영은 이전 번역보다 최종 전수 검토본을 우선하며, 사람 검수 값은 덮어쓰지 않는다.

```bash
python pipeline/review_all_examples.py status
python pipeline/apply_example_translations.py --db assets/content.sqlite
python -m unittest discover -s pipeline/tests -v
python pipeline/self_test.py
python pipeline/audit_report.py --db assets/content.sqlite --outdir reports/audit
python pipeline/release_gate.py --db assets/content.sqlite --strict
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --debug --split-per-abi
```

현재 저장된 번역을 다시 적용하는 데 네트워크는 필요 없다. 입력 스냅샷과 최종 결정이 같아야 하며, 원문이 바뀐 새 사전에는 재검토 없이 자동 적용하지 않는다. 수정 내용을 반영한 사람 검수용 CSV는 `review_templates/full_examples_20261028/`에 있다.

| 검사 | 실제 결과 | 근거 |
|---|---|---|
| Flutter 정적 분석 | No issues found | full-review-flutter-analyze.log |
| Flutter 테스트 | 35개 통과 | full-review-flutter-tests.log |
| Python 테스트 | 31개 통과 | full-review-python-tests.log |
| 파이프라인 자체 검사 | 통과, 합성 8단어 fixture 범위 | full-review-self-test.log |
| 전체 SQLite | integrity ok, 외래키 오류 0, 번역 빈칸 0 | full-review-data-verification.json |
| 원본 보존 | 일본어·영어·ID·순서, 단어·한자·연결 테이블 모두 이전 DB와 동일 | full-review-data-verification.json |
| 반복 수입 | 13,718개 unchanged, 변경 이력 추가 0 | full-review-data-verification.json |
| 엄격 출시 게이트 | 예상 차단, 종료 코드 2 | full-review-release-gate.json, full-review-release-gate.log |
| 범용·ARM64 APK | 빌드 성공, 두 전달 파일 v2 서명 검증 성공 | full-review-build-universal.log, full-review-build-split.log, full-review-signature-*.log |
| Android 업데이트 | 1.0.5+6 설치 성공, 설치 전후 user.db 바이트 동일, 기존 선택 674개 보존 | full-review-install.json |

파이프라인 신규 검사는 전체 전수 검토의 누락·중복·원문 변경·파일 변조 차단, 결정 수정 이력, 모든 해당 ID에 원문 이슈 전파, 최종본 우선 적용과 반복 수입, 사람 검수 값 보호를 확인한다. 기존 예문 펼침/접힘·링크 이동, 320px 화면, 다중 페이지 선택·별표·프로필·재시험 테스트도 통과했다.

실제 320×640 에뮬레이터에서 `会う` 카드를 열어 **정답 닫기** 표시와 발음 안내 삭제를 확인했다. 기본 카드가 화면 안에 들어오며 예문을 펼쳐도 해석은 접혀 있다. 첫 해석을 펼치자 수정된 “스미스 씨를 이미 만나셨지요?”가 표시되고 두 번째 해석은 접힌 채 유지되었다. 근거: `android/full-review-answer.png`, `full-review-examples-closed.png`, `full-review-translation.png` 및 `full-review-translation.xml`. 최초 앱 시작 직후 UI 트리 조회는 아직 준비되지 않아 실패했고, 홈 화면 로드 후 다시 조회하여 확인했다.

실물 Android 기기의 TTS 음질, 제조사별 파일 선택기, ARM64 실물 실행 및 iOS 빌드는 이번에 확인하지 않았다. iPhone에는 APK를 설치할 수 없다. iOS 프로젝트는 있지만 macOS/Xcode에서 별도 빌드·서명과 기기 검증이 필요하다.

## 전달 파일

- `dist/jlpt-study-debug.apk.zip`: 범용 APK, 이 Linux PC의 x86_64 에뮬레이터에서 실행.
- `dist/jlpt-study-arm64-debug.apk.zip`: ARM64 Android 휴대폰용 APK.
- `dist/jlpt-study-source.zip`: 소스, 전체 콘텐츠 DB, 검토 원본·결정·변경 이력, 검수 CSV, 보고서.
- 두 APK는 디버그 서명이며 스토어 업로드용 서명은 하지 않았다. Windows/Linux 실행·빌드와 iOS 준비 방법은 README를 참고한다.
- 파일 크기·SHA-256·ABI·내장 DB 일치·ZIP 압축 해제 검사 결과는 `artifacts.json`과 `dist/SHA256SUMS.txt`에 기록한다.

콘텐츠 DB SHA-256: `be94baa977fdd415a20fd96898b3754988997e4ca2ac2c3b9320995dc845047b`.

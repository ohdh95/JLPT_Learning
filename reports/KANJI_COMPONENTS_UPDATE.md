# 한자 구성 · 1.0.14+15

검사일: 2026-10-28. 배포 태그: `v1.0.14-beta.1`.

## 변경 내용

한자 상세의 **정답 보기** 뒤에 한자 구성을 표시합니다. `休 → 亻 + 木`,
`明 → 日 + 月`, `語 → 言 + 吾`처럼 각 구성 요소를 눌러 상세로 이동합니다.
`亻 → 人`, `氵 → 水`는 원래 글자로 연결합니다. 뒤로 가면 부모의 정답 표시,
관련 단어 펼침 상태와 스크롤 위치를 유지합니다. 단순 방문은 학습 완료로 세지 않습니다.

人·木·日 같은 기본 글자에는 구성 제목과 빈 공간을 만들지 않습니다.
정답 숨기기나 다음/이전 이동 시 구성도 숨깁니다. 반복 부품(林의 木 + 木)은 유지합니다.
일부만 포함된 모양은 '일부'로 표시하고 완전한 한자로 연결하지 않습니다.
독립된 상세 자료가 없는 모양도 일반 글자로 표시합니다.

## 자료 범위와 한계

- [KanjiVG 고정 리비전](https://github.com/KanjiVG/kanjivg/tree/70a0b7ae0c18ceb5cb358274b029cce0234a43bc)의 SVG 구성 그룹을 사용합니다.
- 구성 정보 **2,291자 / 구성 요소 4,878행**. 급수 지정 한자 2,033자와 보충 한자 258자에 구성이 있습니다.
- 상세 이동에 필요한 보충 한자 **214자**를 추가했습니다. 전체 한자 2,756자 중 급수 한자 2,383자는 그대로이며 보충 한자는 373자입니다. N5~N1 진도 분모와 순서는 바뀌지 않습니다.
- 추가 보충 한자의 일본어 읽기는 KANJIDIC2, 한국어 훈음은 기존 libhangul 자료에서 가져옵니다. 임의 급수는 지정하지 않으며 한국어 검수 상태는 `draft`입니다.
- 구성 영역을 생략한 465자는 기본 학습 글자 101자, 완전한 구성 그룹 미확인 248자, 획/표현 불가 모양 55자, 분할 그룹 미완성 38자, 단일 그룹 4자, 원본 파일 없음 19자입니다. **영역이 없다는 사실만으로 독체자라고 판정하지 않습니다.**
- 구성 자료는 현대 글자 모양의 구조입니다. 역사적 어원이나 의미 결합을 자동 추론하지 않습니다. 독립된 사람의 전수 검수 완료로 표시하지 않습니다.

출처·원본 SHA-256·문자별 처리 상태·추가 한자 원자료는
`pipeline/data/kanji_components.json`, DB `source_info`와
`reports/kanji-components-data.json`에 보존합니다. KanjiVG 원본은 CC BY-SA 3.0,
파생 구성 자료는 CC BY-SA 4.0입니다. 앱의 기존 출처·라이선스 화면에 고지를 추가했습니다.

## 실제 검증 결과

- `flutter analyze`: 문제 없음.
- `flutter test`: **66개 통과**. 구성 숨김/표시, 기본 글자 영역 생략, 변형 및 중첩 상세 이동,
  부모 상태·스크롤 복원, 이동만으로 미학습 유지, 보충 한자 진도 제외·저장 지속성을 검증했습니다.
- Python `unittest`: **39개 통과**. 원본 그룹 처리, 반복 부품과 분할 그룹 구별,
  불완전 분해 제외, 잘못된 링크/순환 거부, DB 재수입 멱등성과 기존 자료 보존을 검사했습니다.
- fixture self-test 통과. 전체 DB 무결성 정상, 외래 키 오류 0.
- 고정 원본으로 다시 생성한 결과와 체크인 스냅샷이 일치합니다.
- 기존 버전의 모든 단어·한자·예문·연결·검수 근거를 이전 Git DB와 비교해 변경되지 않았음을 확인했습니다.
- debug, 범용 release, ARM64 release 빌드 성공.
- 범용 APK **67,704,964 bytes**, ARM64 APK **32,888,013 bytes**.
- 두 release APK의 서명, `debuggable=false`, AOT 코드, ABI, 포함 DB 해시를 확인했습니다.
  배포 인증서는 기존 1.0.13과 동일합니다. [APK 검증 결과](kanji-components-apk-verification.json).
- 별도 Android API 36 x86_64 에뮬레이터에서 이전 release에 학습 표시와 별표를 저장한 후
  새 release로 업데이트했습니다. 기존 기록 유지, 네트워크를 끈 상태의 구성 표시,
  `休 → 人/木`, 기본 글자의 영역 생략, 부모 정답 상태 복귀, 큰 글씨 화면을 확인했습니다.
  재시작 후 기존 단어와 새 한자 학습 표시도 유지됐습니다.
  [기기 검증 결과](kanji-components-device-verification.json).
- 엄격 데이터 검수 게이트는 기존과 같이 **종료 코드 2 / release_ready=false**입니다.
  사람 검수 요건은 별개이며, 이번 배포도 미리보기 상태를 유지합니다.

실제 Android 휴대폰과 iOS는 이번에 실행하지 않았습니다.

## 오프라인 재적용

원본 DB를 다시 구축한 경우 기존 한국어 현지화 적용 이후 실행합니다.

```text
python pipeline/build_kanji_components.py --db assets/content.sqlite
```

checked-in snapshot만 사용하므로 네트워크가 필요 없습니다. 기존 한자 뜻과 검수 상태,
단어 순서 및 사용자 DB를 수정하지 않습니다. 원본에서 다시 생성하려면 다음 인자를 줍니다.

```text
python pipeline/build_kanji_components.py --db assets/content.sqlite --kanjivg <고정리비전의-kanji-폴더> --kanjidic <kanjidic2.xml.gz> --hanja <libhangul-hanja.txt>
```

원본 파일은 [KanjiVG](https://github.com/KanjiVG/kanjivg),
[KANJIDIC2](https://www.edrdg.org/kanjidic/kanjidic2.xml.gz),
[libhangul](https://github.com/libhangul/libhangul/blob/main/data/hanja/hanja.txt)에서 가져옵니다.
현재 스냅샷의 파일 해시와 새 자료가 다르면 변경 내용을 검토한 뒤 재생성해야 합니다.

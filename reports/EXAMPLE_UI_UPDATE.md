# 예문 화면 정리 · 1.0.15+16

2026-10-29. 학습 및 테스트의 공통 예문 카드에서 `Tatoeba #… · CC BY 2.0 FR` 문구를 제거했다. 설정의 출처·라이선스 고지와 DB의 원본 문장 ID를 보존하고, 고지에 Tatoeba 홈페이지 링크를 추가했다. 예문·해석의 기본 접힘, 예문 단어 이동, 콘텐츠와 단어 순서는 바꾸지 않았다.

## 이번 변경의 실제 검증

- `flutter analyze`: 문제 없음.
- `flutter test`: 66개 통과. 실제 SQLite를 사용하는 학습 예문·해석 접기/펼치기, 예문 단어 이동, 테스트 뒷면에서 이동 후 진행 상태 보존 테스트 포함.
- `python3 -m unittest discover -s pipeline/tests -v`: 39개 통과.
- `python3 pipeline/self_test.py`: 8단어 fixture 기반 가져오기·무결성·선택·JMdict 파서·감사·한국어 템플릿 검사 통과. 전체 원본 JMdict 재검증을 의미하지 않는다.
- `python3 pipeline/audit_report.py --db assets/content.sqlite --outdir reports/audit`: SQLite 무결성 `ok`, 외래 키 오류 0.
- Android debug, 범용 release, ARM64 release 빌드 성공.
- 두 release APK의 배포 인증서 일치, 비디버그·AOT 빌드, 버전, 포함 고지 파일을 확인했다. [APK 검증 기록](example-ui-apk-verification.json).

콘텐츠 DB SHA-256은 이전판과 같은 `7cd9d2343a76290d86749a45fae30f609c655b93e5badd483c3ab13bdf78bd2d`다. 사용자 DB 스키마와 저장 로직은 변경하지 않았다. 이번 문구 수정에서는 에뮬레이터를 새로 실행하거나 실기기/iOS를 테스트하지 않았다. 이전판의 기기 검증은 [한자 구성 업데이트 기록](KANJI_COMPONENTS_UPDATE.md)에 별도로 남아 있다.

한국어 뜻·훈음·예문의 독립된 사람 검수는 여전히 미완료이며, 이 버전도 검수 완료판이 아닌 미리보기다.

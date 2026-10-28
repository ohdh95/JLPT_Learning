import 'dart:convert';
import 'parts_of_speech.dart';

const fields = <String, String>{
  'reading': '가나 읽기',
  'meaning': '한국어 뜻',
  'part_of_speech': '품사',
  'korean_hun': '한자 한국식 훈',
  'korean_eum': '한자 한국식 음',
  'kanji_reading': '한자별 일본어 읽기',
  'jlpt_level': 'JLPT 급수',
  'example': '일본어 예문',
  'translation': '예문 번역',
};
const ratings = {'unknown': '모름', 'uncertain': '애매함', 'known': '알고 있음'};
const levels = ['N5', 'N4', 'N3', 'N2', 'N1'];
List<String> strings(Object? value) =>
    value == null ? [] : List<String>.from(jsonDecode(value as String) as List);
String reviewLabel(Object? status) => switch (status) {
  'human_reviewed' => '사람 검수 기록 있음',
  'draft' => '초안 · 미검수',
  'direct_jmdict_verified' => 'JMdict 표기·읽기·ID 일치',
  'jmdict_not_found' => 'JMdict 대조: 미발견',
  'jmdict_id_conflict' => 'JMdict 대조: ID 불일치',
  'jmdict_pair_only' => '표기·읽기 일치 · 원본 ID 없음',
  'upstream_jmdict_linked' => '원본 연결만 있음 · 직접 검증 미실행',
  _ => '준비 중 · 미검수',
};

class Word {
  final Map<String, Object?> row;
  const Word(this.row);
  String get id => row['word_id'] as String;
  String get surface => row['surface'] as String;
  String get reading => row['reading_kana'] as String;
  String get level => row['jlpt_level'] as String;
  List<String> get meanings => strings(row['meanings_ko_json']);
  List<String> get english => strings(row['gloss_en_json']);
  List<String> get pos => strings(row['pos_codes_json']);
  PosClassification get partOfSpeech =>
      classifyPos(pos, surface: surface, reading: reading);
}

class WordFilter {
  final PartOfSpeech? partOfSpeech;
  final String? level;
  final String query, status, sort;
  final bool starred, selected;
  const WordFilter({
    this.partOfSpeech,
    this.level,
    this.query = '',
    this.status = 'all',
    this.sort = 'source',
    this.starred = false,
    this.selected = false,
  });
}

class WordPage {
  final List<Word> words;
  final int total, page, size;
  const WordPage(this.words, this.total, this.page, this.size);
  int get pages => total == 0 ? 1 : (total / size).ceil();
}

class TestSession {
  final String id, startedAt, status, kind;
  final List<String> order;
  final Map<String, String> responses;
  final Map<String, dynamic> snapshots;
  final int index;
  final bool revealed;
  const TestSession({
    required this.id,
    this.kind = 'word',
    required this.startedAt,
    required this.status,
    required this.order,
    required this.responses,
    required this.snapshots,
    required this.index,
    required this.revealed,
  });
  bool get isKanji => kind == 'kanji';
  Map<String, Object?> kanjiSnapshot(String id) =>
      Map<String, Object?>.from(snapshots[id] as Map);
  bool get complete => status == 'completed';
  Word snapshot(String wordId) =>
      Word(Map<String, Object?>.from(snapshots[wordId] as Map));
}

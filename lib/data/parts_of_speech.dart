/// Learning categories are separate from the original JMdict tags. A word may
/// belong to several categories; qualifiers never certify a dictionary sense.
enum PartOfSpeech {
  noun('명사'),
  ichidan('1단동사'),
  godan('5단동사'),
  irregular('불규칙동사'),
  iAdjective('い형용사'),
  naAdjective('な형용사'),
  adverb('부사'),
  adnominal('연체사'),
  conjunction('접속사'),
  particle('조사'),
  interjection('감동사'),
  auxiliary('조동사');

  final String label;
  const PartOfSpeech(this.label);
}

enum _Qualifier { any, suruWord, suruNoun, hazu, notHazu }

class _Rule {
  final PartOfSpeech category;
  final List<String> codes;
  final _Qualifier qualifier;
  const _Rule(this.category, this.codes, [this.qualifier = _Qualifier.any]);

  bool matches(List<String> tags, String surface, String reading) {
    if (!codes.any(tags.contains)) return false;
    final suru = surface.endsWith('する') || reading.endsWith('する');
    return switch (qualifier) {
      _Qualifier.any => true,
      _Qualifier.suruWord => suru,
      _Qualifier.suruNoun => !suru,
      _Qualifier.hazu => reading == 'はず',
      _Qualifier.notHazu => reading != 'はず',
    };
  }

  // Only constant rule tags are interpolated. User search remains parameterized.
  String get sql {
    final tag = codes
        .map((c) => '''instr(v.pos_codes_json, '"$c"')>0''')
        .join(' OR ');
    const suru = "(v.surface LIKE '%する' OR v.reading_kana LIKE '%する')";
    final condition = switch (qualifier) {
      _Qualifier.any => '1=1',
      _Qualifier.suruWord => suru,
      _Qualifier.suruNoun => 'NOT $suru',
      _Qualifier.hazu => "v.reading_kana='はず'",
      _Qualifier.notHazu => "v.reading_kana!='はず'",
    };
    return '(($tag) AND ($condition))';
  }
}

const _rules = [
  _Rule(PartOfSpeech.noun, [
    'n',
    'n-pref',
    'n-suf',
    'pn',
    'num',
    'ctr',
    'adj-no',
  ]),
  _Rule(PartOfSpeech.noun, ['vs'], _Qualifier.suruNoun),
  _Rule(PartOfSpeech.noun, ['aux'], _Qualifier.hazu),
  _Rule(PartOfSpeech.ichidan, ['v1', 'v1-s']),
  _Rule(PartOfSpeech.godan, [
    'v5aru',
    'v5b',
    'v5g',
    'v5k',
    'v5k-s',
    'v5m',
    'v5n',
    'v5r',
    'v5r-i',
    'v5s',
    'v5t',
    'v5u',
    'v5u-s',
  ]),
  _Rule(PartOfSpeech.irregular, ['vk', 'vs-i', 'vs-s', 'vz']),
  _Rule(PartOfSpeech.irregular, ['vs'], _Qualifier.suruWord),
  _Rule(PartOfSpeech.iAdjective, ['adj-i', 'adj-ix', 'aux-adj']),
  _Rule(PartOfSpeech.naAdjective, ['adj-na']),
  _Rule(PartOfSpeech.adverb, ['adv', 'adv-to']),
  _Rule(PartOfSpeech.adnominal, ['adj-pn']),
  _Rule(PartOfSpeech.conjunction, ['conj']),
  _Rule(PartOfSpeech.particle, ['prt']),
  _Rule(PartOfSpeech.interjection, ['int']),
  // JMdict aux is broader than school grammar: はず is a formal noun.
  // aux-v/aux-adj are supplementary verbs/adjectives, not automatically 助動詞.
  _Rule(PartOfSpeech.auxiliary, ['aux'], _Qualifier.notHazu),
];

const _tagLabels = {
  'vi': '자동사',
  'vt': '타동사',
  'pn': '대명사',
  'num': '수사',
  'ctr': '조수사',
  'n-pref': '접두적으로 쓰이는 명사',
  'n-suf': '접미적으로 쓰이는 명사',
  'pref': '접두사',
  'suf': '접미사',
  'exp': '구문·관용표현',
  'adj-no': 'の로 명사 수식',
  'adj-f': '명사 앞에서 쓰이는 표현',
  'adj-nari': 'なり형 문어 형용동사',
  'adj-t': 'たる형 문어 표현',
  'adv-to': 'と를 붙여 쓰는 부사',
  'adj-ix': 'いい・よい형 활용',
  'aux-v': '보조동사',
  'aux-adj': '보조형용사',
  'v1-s': 'くれる형',
  'v5aru': '존경 표현의 특수 5단 활용',
  'v5k-s': '行く: て형·た형 예외',
  'v5r-i': 'ある: 부정형 ない',
  'v5u-s': 'う어미 특수 활용',
  'vs-s': 'する 계열 특수 활용',
  'vz': 'ずる형 · じる형과 활용 차이 있음',
};

final knownPosCodes = {
  for (final rule in _rules) ...rule.codes,
  ..._tagLabels.keys,
};

class PosClassification {
  final List<PartOfSpeech> categories;
  final List<String> tags;
  final List<String> unknownCodes;
  const PosClassification(this.categories, this.tags, this.unknownCodes);
  String get display => categories.isNotEmpty
      ? categories.map((c) => c.label).join(' · ')
      : tags.isNotEmpty
      ? tags.join(' · ')
      : '품사 정보 확인 중';
}

PosClassification classifyPos(
  List<String> codes, {
  required String surface,
  required String reading,
}) {
  final categories = {
    for (final rule in _rules)
      if (rule.matches(codes, surface, reading)) rule.category,
  };
  final tags = {
    for (final code in codes)
      if (_tagLabels.containsKey(code)) _tagLabels[code]!,
    if (codes.contains('vs') &&
        !surface.endsWith('する') &&
        !reading.endsWith('する'))
      'する와 결합 가능',
    if (codes.contains('aux') && reading == 'はず') '형식명사',
  };
  return PosClassification(
    PartOfSpeech.values.where(categories.contains).toList(),
    tags.toList(),
    codes.where((code) => !knownPosCodes.contains(code)).toList(),
  );
}

String partOfSpeechSql(PartOfSpeech category) =>
    '(${_rules.where((r) => r.category == category).map((r) => r.sql).join(' OR ')})';

String formatHunEum(
  Map<String, Object?> kanji, {
  bool showHun = true,
  bool showEum = true,
}) {
  String? value(String key) {
    final text = (kanji[key] as String?)?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  final hun = value('korean_hun'), eum = value('korean_eum');
  if (showHun && showEum && hun == null && eum == null) return '훈음 준비 중';
  return [if (showHun) hun ?? '훈 준비 중', if (showEum) eum ?? '음 준비 중'].join(' ');
}

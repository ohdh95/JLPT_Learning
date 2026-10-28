/// Offline learning notes. Rules and original Korean explanations are kept
/// separate from vocabulary review statuses; no study history is written.
class GrammarForm {
  final String label, rule, example;
  const GrammarForm(this.label, this.rule, this.example);
}

class GrammarSection {
  final String title;
  final List<GrammarForm> forms;
  final bool expanded;
  const GrammarSection(this.title, this.forms, {this.expanded = false});
}

class GrammarSource {
  final String title, url;
  const GrammarSource(this.title, this.url);
}

class GrammarLesson {
  final String id, title, subtitle, summary;
  final List<GrammarSection> sections;
  final List<String> notes;
  final List<GrammarSource> sources;
  const GrammarLesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.sections,
    required this.notes,
    required this.sources,
  });
}

const _groups = GrammarSource(
  '도쿄외국어대 · 동사의 세 종류',
  'https://www.coelang.tufs.ac.jp/mt/ja/gmod/contents/explanation/039.html',
);
const _te = GrammarSource(
  '도쿄외국어대 · て형',
  'https://www.coelang.tufs.ac.jp/mt/ja/gmod/contents/explanation/043.html',
);
const _potential = GrammarSource(
  '도쿄외국어대 · 가능형',
  'https://www.coelang.tufs.ac.jp/mt/ja/gmod/contents/card/074.html',
);
const _adjectives = GrammarSource(
  '도쿄외국어대 · 형용사 보통형',
  'https://www.coelang.tufs.ac.jp/mt/ja/gmod/contents/explanation/040.html',
);
const _handbook = GrammarSource(
  '국립국어연구소 · 入れる 활용표',
  'https://www2.ninjal.ac.jp/verbhandbook/headwords/入れる.html',
);
const _jpf = GrammarSource(
  '국제교류기금 · 문법 해설',
  'https://www.jpf.go.jp/j/urawa/j_rsorcs/textbook/dl/setsumei/setsumei_all.pdf',
);
const _kuru = GrammarSource(
  '국립국어연구소 · 来る 활용표',
  'https://www2.ninjal.ac.jp/verbhandbook/headwords/来る.html',
);
const _condition = GrammarSource(
  '도쿄외국어대 · 조건 표현',
  'https://www.coelang.tufs.ac.jp/mt/ja/gmod/contents/card/083.html',
);
const _volitional = GrammarSource(
  '도쿄외국어대 · 의지형',
  'https://www.coelang.tufs.ac.jp/mt/ja/gmod/contents/card/065.html',
);

const grammarLessons = [
  GrammarLesson(
    id: 'ichidan',
    title: '1단동사',
    subtitle: '食べる · 見る / 2그룹',
    summary: '마지막 る를 빼고 어미를 붙입니다. 食べる(たべる, 먹다)의 어간은 食べ입니다.',
    sections: [
      GrammarSection('기본 활용', [
        GrammarForm('사전형', '기본형', '食べる'),
        GrammarForm('정중형 · ます', 'る → ます', '食べます'),
        GrammarForm('부정 · ない', 'る → ない', '食べない'),
        GrammarForm('과거 · た', 'る → た', '食べた'),
        GrammarForm('과거 부정', 'る → なかった', '食べなかった'),
        GrammarForm('연결 · て', 'る → て', '食べて'),
      ], expanded: true),
      GrammarSection('정중형 네 가지', [
        GrammarForm('현재·미래 긍정', '어간 + ます', '食べます'),
        GrammarForm('현재·미래 부정', '어간 + ません', '食べません'),
        GrammarForm('과거 긍정', '어간 + ました', '食べました'),
        GrammarForm('과거 부정', '어간 + ませんでした', '食べませんでした'),
      ]),
      GrammarSection('가능·수동·사역·조건·의지', [
        GrammarForm('가능 · 먹을 수 있다', 'る → られる', '食べられる'),
        GrammarForm('수동 · 먹히다', 'る → られる', '食べられる'),
        GrammarForm('사역 · 먹게 하다', 'る → させる', '食べさせる'),
        GrammarForm('조건 · ~하면', 'る → れば / た형 + ら', '食べれば / 食べたら'),
        GrammarForm('의지·권유', 'る → よう', '食べよう'),
        GrammarForm('명령 · 강한 말투', 'る → ろ', '食べろ'),
        GrammarForm('금지 · 강한 말투', '사전형 + な', '食べるな'),
      ]),
    ],
    notes: [
      'る로 끝난다고 모두 1단은 아닙니다. 帰る(かえる), 走る(はしる), 入る(はいる)는 5단동사입니다.',
      '가능형과 수동형의 모양이 같습니다. 문장 속 뜻으로 구별합니다. 기본 학습에서는 ら를 포함한 食べられる를 익힙니다.',
      'くれる는 1단동사지만 명령형은 くれ입니다.',
    ],
    sources: [_groups, _potential, _handbook, _condition, _volitional, _jpf],
  ),
  GrammarLesson(
    id: 'godan',
    title: '5단동사',
    subtitle: '書く · 読む · 買う / 1그룹',
    summary: '마지막 가나가 あ·い·う·え·お단으로 바뀝니다. 書く(かく, 쓰다)로 익혀 보세요.',
    sections: [
      GrammarSection('기본 활용', [
        GrammarForm('사전형', 'う단으로 끝남', '書く'),
        GrammarForm('정중형 · ます', '끝 가나를 い단 + ます', '書きます'),
        GrammarForm('부정 · ない', '끝 가나를 あ단 + ない', '書かない'),
        GrammarForm('과거 · た', '어미별 소리 변화', '書いた'),
        GrammarForm('과거 부정', 'ない → なかった', '書かなかった'),
        GrammarForm('연결 · て', '어미별 소리 변화', '書いて'),
      ], expanded: true),
      GrammarSection('て형·た형 어미별 규칙', [
        GrammarForm(
          'う・つ・る → って / った',
          '買う・待つ・帰る',
          '買って / 買った\n待って / 待った\n帰って / 帰った',
        ),
        GrammarForm(
          'む・ぶ・ぬ → んで / んだ',
          '読む・遊ぶ・死ぬ',
          '読んで / 読んだ\n遊んで / 遊んだ\n死んで / 死んだ',
        ),
        GrammarForm('く → いて / いた', '書く', '書いて / 書いた'),
        GrammarForm('ぐ → いで / いだ', '泳ぐ', '泳いで / 泳いだ'),
        GrammarForm('す → して / した', '話す', '話して / 話した'),
      ]),
      GrammarSection('정중형 네 가지', [
        GrammarForm('현재·미래 긍정', 'い단 + ます', '書きます'),
        GrammarForm('현재·미래 부정', 'い단 + ません', '書きません'),
        GrammarForm('과거 긍정', 'い단 + ました', '書きました'),
        GrammarForm('과거 부정', 'い단 + ませんでした', '書きませんでした'),
      ]),
      GrammarSection('가능·수동·사역·조건·의지', [
        GrammarForm('가능 · 쓸 수 있다', '끝 가나를 え단 + る', '書ける'),
        GrammarForm('수동 · 쓰이다', '끝 가나를 あ단 + れる', '書かれる'),
        GrammarForm('사역 · 쓰게 하다', '끝 가나를 あ단 + せる', '書かせる'),
        GrammarForm('조건 · ~하면', 'え단 + ば / た형 + ら', '書けば / 書いたら'),
        GrammarForm('의지·권유', '끝 가나를 お단 + う', '書こう'),
        GrammarForm('명령 · 강한 말투', '끝 가나를 え단으로', '書け'),
        GrammarForm('금지 · 강한 말투', '사전형 + な', '書くな'),
      ]),
    ],
    notes: [
      'う로 끝나면 부정형의 あ단은 わ입니다. 買う → 買わない. 수동·사역도 買われる・買わせる입니다.',
      '行く(いく)의 て형·た형은 行って・行った입니다. ある의 부정형은 ない입니다.',
      '問う → 問うて・問うた처럼 특수한 う 어미도 있습니다. 단어별 예외 태그를 확인하세요.',
      'くださる・なさる・おっしゃる・いらっしゃる의 ます형은 くださいます・なさいます・おっしゃいます・いらっしゃいます입니다.',
    ],
    sources: [_groups, _te, _potential, _condition, _volitional, _jpf],
  ),
  GrammarLesson(
    id: 'irregular',
    title: '불규칙동사',
    subtitle: 'する · 来る / 3그룹',
    summary: 'する(하다)와 来る(くる, 오다)는 각각 외웁니다. 来る는 활용에 따라 く・き・こ로 읽기가 바뀝니다.',
    sections: [
      GrammarSection('する · 기본 활용', [
        GrammarForm('사전형', '하다', 'する'),
        GrammarForm('정중형 · ます', '합니다', 'します'),
        GrammarForm('부정 · ない', '하지 않는다', 'しない'),
        GrammarForm('과거 · た', '했다', 'した'),
        GrammarForm('과거 부정', '하지 않았다', 'しなかった'),
        GrammarForm('연결 · て', '하고 / 해서', 'して'),
      ], expanded: true),
      GrammarSection('来る · 기본 활용', [
        GrammarForm('사전형', '오다', '来る（くる）'),
        GrammarForm('정중형 · ます', '옵니다', '来ます（きます）'),
        GrammarForm('부정 · ない', '오지 않는다', '来ない（こない）'),
        GrammarForm('과거 · た', '왔다', '来た（きた）'),
        GrammarForm('과거 부정', '오지 않았다', '来なかった（こなかった）'),
        GrammarForm('연결 · て', '오고 / 와서', '来て（きて）'),
      ]),
      GrammarSection('정중형 네 가지', [
        GrammarForm('현재·미래 긍정', 'する / 来る', 'します / 来ます（きます）'),
        GrammarForm('현재·미래 부정', 'する / 来る', 'しません / 来ません（きません）'),
        GrammarForm('과거 긍정', 'する / 来る', 'しました / 来ました（きました）'),
        GrammarForm('과거 부정', 'する / 来る', 'しませんでした\n来ませんでした（きませんでした）'),
      ]),
      GrammarSection('する · 가능·수동·사역 등', [
        GrammarForm('가능', '할 수 있다', 'できる'),
        GrammarForm('수동', '당하다 / ~되다', 'される'),
        GrammarForm('사역', '하게 하다', 'させる'),
        GrammarForm('조건', '~하면', 'すれば / したら'),
        GrammarForm('의지·권유', '하자 / 해야지', 'しよう'),
        GrammarForm('명령 · 강한 말투', '해라', 'しろ / せよ'),
        GrammarForm('금지 · 강한 말투', '하지 마라', 'するな'),
      ]),
      GrammarSection('来る · 가능·수동·사역 등', [
        GrammarForm('가능', '올 수 있다', '来られる（こられる）'),
        GrammarForm('수동', '문맥에 따라 피해 등을 나타냄', '来られる（こられる）'),
        GrammarForm('사역', '오게 하다', '来させる（こさせる）'),
        GrammarForm('조건', '~하면', '来れば（くれば） / 来たら（きたら）'),
        GrammarForm('의지·권유', '오자 / 와야지', '来よう（こよう）'),
        GrammarForm('명령 · 강한 말투', '와라', '来い（こい）'),
        GrammarForm('금지 · 강한 말투', '오지 마라', '来るな（くるな）'),
      ]),
    ],
    notes: [
      '勉強する → 勉強します・勉強しない처럼 する와 결합한 동사도 이 규칙을 따릅니다. 모든 명사에 する를 붙일 수 있는 것은 아닙니다.',
      '사전의 「する와 결합 가능」 태그와 실제 する동사는 구별합니다. 勉強 자체는 명사로 표시합니다.',
      '愛する・信ずる 등의 특수 활용은 기본 する 표를 그대로 적용하지 않습니다. 이 화면은 대표형 する・来る의 활용표입니다.',
    ],
    sources: [_groups, _potential, _kuru, _condition, _volitional, _jpf],
  ),
  GrammarLesson(
    id: 'i-adjective',
    title: 'い형용사',
    subtitle: '高い · おいしい',
    summary: '끝의 い를 바꾸어 활용합니다. 高い(たかい, 높다·비싸다)를 기준으로 익혀 보세요.',
    sections: [
      GrammarSection('기본 활용', [
        GrammarForm('보통형 긍정', '기본형', '高い'),
        GrammarForm('정중형 긍정', '기본형 + です', '高いです'),
        GrammarForm('부정', 'い → くない', '高くない'),
        GrammarForm('과거', 'い → かった', '高かった'),
        GrammarForm('과거 부정', 'い → くなかった', '高くなかった'),
        GrammarForm('연결', 'い → くて', '高くて'),
      ], expanded: true),
      GrammarSection('정중형과 문장 연결', [
        GrammarForm('정중한 부정', 'くないです / くありません', '高くないです / 高くありません'),
        GrammarForm('정중한 과거', 'かった + です', '高かったです'),
        GrammarForm('정중한 과거 부정', 'くなかったです / くありませんでした', '高くなかったです\n高くありませんでした'),
        GrammarForm('조건', 'い → ければ / 과거형 + ら', '高ければ / 高かったら'),
        GrammarForm('동사 수식', 'い → く', '高く売る（비싸게 팔다）'),
        GrammarForm('명사 수식', '기본형 + 명사', '高い山（높은 산）'),
      ]),
      GrammarSection('いい의 예외 활용', [
        GrammarForm('기본형', 'いい / よい', 'いい'),
        GrammarForm('부정', 'よい를 기준으로 변화', 'よくない'),
        GrammarForm('과거 / 과거 부정', 'よかった / よくなかった', 'よかった / よくなかった'),
        GrammarForm('연결 / 조건', 'よくて / よければ', 'よくて / よければ'),
      ]),
    ],
    notes: [
      '과거형은 高かったです입니다. 高いでした로 만들지 않습니다.',
      'いい(좋다)와 달리 かわいい(귀엽다)는 규칙적으로 かわいくない・かわいかった가 됩니다.',
      '형용사에는 동사의 ます를 붙이지 않습니다. 高います가 아니라 高いです입니다.',
    ],
    sources: [_adjectives, _condition, _jpf],
  ),
  GrammarLesson(
    id: 'na-adjective',
    title: 'な형용사',
    subtitle: '静か · きれい',
    summary: '명사를 꾸밀 때 な를 붙입니다. 静か(しずか, 조용하다)에 だ・です 등을 붙여 문장을 만듭니다.',
    sections: [
      GrammarSection('기본 활용', [
        GrammarForm('보통형 긍정', '어간 + だ', '静かだ'),
        GrammarForm('정중형 긍정', '어간 + です', '静かです'),
        GrammarForm('부정', '어간 + ではない / じゃない', '静かではない / 静かじゃない'),
        GrammarForm('과거', '어간 + だった', '静かだった'),
        GrammarForm('과거 부정', '어간 + ではなかった', '静かではなかった'),
        GrammarForm('연결', '어간 + で', '静かで'),
      ], expanded: true),
      GrammarSection('정중형과 문장 연결', [
        GrammarForm('정중한 부정', 'ではありません / じゃないです', '静かではありません\n静かじゃないです'),
        GrammarForm('정중한 과거', '어간 + でした', '静かでした'),
        GrammarForm('정중한 과거 부정', 'ではありませんでした', '静かではありませんでした'),
        GrammarForm('조건', '어간 + なら / だったら', '静かなら / 静かだったら'),
        GrammarForm('동사 수식', '어간 + に', '静かに話す（조용히 말하다）'),
        GrammarForm('명사 수식', '어간 + な + 명사', '静かな部屋（조용한 방）'),
      ]),
    ],
    notes: [
      'きれい(예쁘다·깨끗하다), 嫌い(きらい, 싫다)는 い로 끝나지만 な형용사입니다. きれいな部屋・嫌いな食べ物처럼 씁니다.',
      '문장 끝에서는 静かです, 명사 앞에서는 静かな部屋입니다. 静かなです로 쓰지 않습니다.',
      'じゃ는 では의 회화형입니다. 静かじゃなかった도 과거 부정 표현입니다.',
    ],
    sources: [_adjectives, _condition, _jpf],
  ),
];

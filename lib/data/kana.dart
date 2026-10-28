/// Modern kana correspondences checked against The Japan Foundation's
/// Irodori / MARUGOTO Plus charts. Korean hints are approximate study aids,
/// not official foreign-word spellings or exact phonetic transcriptions.
class KanaEntry {
  final String? hiragana;
  final String katakana, korean;
  const KanaEntry(this.hiragana, this.katakana, this.korean);
  const KanaEntry.foreign(this.katakana, this.korean) : hiragana = null;
}

class KanaGroup {
  final String title;
  final List<List<KanaEntry?>> rows;
  final String note;
  const KanaGroup(this.title, this.rows, this.note);
}

const kanaGroups = [
  KanaGroup(
    '기본',
    [
      [
        KanaEntry('あ', 'ア', '아'),
        KanaEntry('い', 'イ', '이'),
        KanaEntry('う', 'ウ', '우'),
        KanaEntry('え', 'エ', '에'),
        KanaEntry('お', 'オ', '오'),
      ],
      [
        KanaEntry('か', 'カ', '카'),
        KanaEntry('き', 'キ', '키'),
        KanaEntry('く', 'ク', '쿠'),
        KanaEntry('け', 'ケ', '케'),
        KanaEntry('こ', 'コ', '코'),
      ],
      [
        KanaEntry('さ', 'サ', '사'),
        KanaEntry('し', 'シ', '시'),
        KanaEntry('す', 'ス', '스'),
        KanaEntry('せ', 'セ', '세'),
        KanaEntry('そ', 'ソ', '소'),
      ],
      [
        KanaEntry('た', 'タ', '타'),
        KanaEntry('ち', 'チ', '치'),
        KanaEntry('つ', 'ツ', '츠'),
        KanaEntry('て', 'テ', '테'),
        KanaEntry('と', 'ト', '토'),
      ],
      [
        KanaEntry('な', 'ナ', '나'),
        KanaEntry('に', 'ニ', '니'),
        KanaEntry('ぬ', 'ヌ', '누'),
        KanaEntry('ね', 'ネ', '네'),
        KanaEntry('の', 'ノ', '노'),
      ],
      [
        KanaEntry('は', 'ハ', '하'),
        KanaEntry('ひ', 'ヒ', '히'),
        KanaEntry('ふ', 'フ', '후'),
        KanaEntry('へ', 'ヘ', '헤'),
        KanaEntry('ほ', 'ホ', '호'),
      ],
      [
        KanaEntry('ま', 'マ', '마'),
        KanaEntry('み', 'ミ', '미'),
        KanaEntry('む', 'ム', '무'),
        KanaEntry('め', 'メ', '메'),
        KanaEntry('も', 'モ', '모'),
      ],
      [
        KanaEntry('や', 'ヤ', '야'),
        null,
        KanaEntry('ゆ', 'ユ', '유'),
        null,
        KanaEntry('よ', 'ヨ', '요'),
      ],
      [
        KanaEntry('ら', 'ラ', '라'),
        KanaEntry('り', 'リ', '리'),
        KanaEntry('る', 'ル', '루'),
        KanaEntry('れ', 'レ', '레'),
        KanaEntry('ろ', 'ロ', '로'),
      ],
      [KanaEntry('わ', 'ワ', '와'), null, null, null, KanaEntry('を', 'ヲ', '오')],
      [KanaEntry('ん', 'ン', 'ㄴ·ㅁ·ㅇ'), null, null, null, null],
    ],
    '조사 は·へ·を는 각각 와·에·오로 읽어요.\nん·ン은 뒤따르는 소리에 따라 ㄴ·ㅁ·ㅇ처럼 들릴 수 있어요.\n작은 っ·ッ는 다음 자음 앞에서 한 박자 막고, ー는 앞 모음을 한 박자 늘여요.',
  ),
  KanaGroup('탁음·반탁음', [
    [
      KanaEntry('が', 'ガ', '가'),
      KanaEntry('ぎ', 'ギ', '기'),
      KanaEntry('ぐ', 'グ', '구'),
      KanaEntry('げ', 'ゲ', '게'),
      KanaEntry('ご', 'ゴ', '고'),
    ],
    [
      KanaEntry('ざ', 'ザ', '자'),
      KanaEntry('じ', 'ジ', '지'),
      KanaEntry('ず', 'ズ', '즈'),
      KanaEntry('ぜ', 'ゼ', '제'),
      KanaEntry('ぞ', 'ゾ', '조'),
    ],
    [
      KanaEntry('だ', 'ダ', '다'),
      KanaEntry('ぢ', 'ヂ', '지'),
      KanaEntry('づ', 'ヅ', '즈'),
      KanaEntry('で', 'デ', '데'),
      KanaEntry('ど', 'ド', '도'),
    ],
    [
      KanaEntry('ば', 'バ', '바'),
      KanaEntry('び', 'ビ', '비'),
      KanaEntry('ぶ', 'ブ', '부'),
      KanaEntry('べ', 'ベ', '베'),
      KanaEntry('ぼ', 'ボ', '보'),
    ],
    [
      KanaEntry('ぱ', 'パ', '파'),
      KanaEntry('ぴ', 'ピ', '피'),
      KanaEntry('ぷ', 'プ', '푸'),
      KanaEntry('ぺ', 'ペ', '페'),
      KanaEntry('ぽ', 'ポ', '포'),
    ],
  ], '표준어에서 じ·ぢ는 같은 소리, ず·づ도 같은 소리로 읽어요.'),
  KanaGroup('요음', [
    [
      KanaEntry('きゃ', 'キャ', '캬'),
      KanaEntry('きゅ', 'キュ', '큐'),
      KanaEntry('きょ', 'キョ', '쿄'),
    ],
    [
      KanaEntry('しゃ', 'シャ', '샤'),
      KanaEntry('しゅ', 'シュ', '슈'),
      KanaEntry('しょ', 'ショ', '쇼'),
    ],
    [
      KanaEntry('ちゃ', 'チャ', '차'),
      KanaEntry('ちゅ', 'チュ', '추'),
      KanaEntry('ちょ', 'チョ', '초'),
    ],
    [
      KanaEntry('にゃ', 'ニャ', '냐'),
      KanaEntry('にゅ', 'ニュ', '뉴'),
      KanaEntry('にょ', 'ニョ', '뇨'),
    ],
    [
      KanaEntry('ひゃ', 'ヒャ', '햐'),
      KanaEntry('ひゅ', 'ヒュ', '휴'),
      KanaEntry('ひょ', 'ヒョ', '효'),
    ],
    [
      KanaEntry('みゃ', 'ミャ', '먀'),
      KanaEntry('みゅ', 'ミュ', '뮤'),
      KanaEntry('みょ', 'ミョ', '묘'),
    ],
    [
      KanaEntry('りゃ', 'リャ', '랴'),
      KanaEntry('りゅ', 'リュ', '류'),
      KanaEntry('りょ', 'リョ', '료'),
    ],
    [
      KanaEntry('ぎゃ', 'ギャ', '갸'),
      KanaEntry('ぎゅ', 'ギュ', '규'),
      KanaEntry('ぎょ', 'ギョ', '교'),
    ],
    [
      KanaEntry('じゃ', 'ジャ', '자'),
      KanaEntry('じゅ', 'ジュ', '주'),
      KanaEntry('じょ', 'ジョ', '조'),
    ],
    [
      KanaEntry('ぢゃ', 'ヂャ', '자'),
      KanaEntry('ぢゅ', 'ヂュ', '주'),
      KanaEntry('ぢょ', 'ヂョ', '조'),
    ],
    [
      KanaEntry('びゃ', 'ビャ', '뱌'),
      KanaEntry('びゅ', 'ビュ', '뷰'),
      KanaEntry('びょ', 'ビョ', '뵤'),
    ],
    [
      KanaEntry('ぴゃ', 'ピャ', '퍄'),
      KanaEntry('ぴゅ', 'ピュ', '퓨'),
      KanaEntry('ぴょ', 'ピョ', '표'),
    ],
  ], '작은 ゃ·ゅ·ょ를 앞 글자와 합쳐 한 박자로 읽어요.\nぢゃ·ぢゅ·ぢょ는 드물게 쓰이며 じゃ·じゅ·じょ와 같은 소리예요.'),
  KanaGroup('외래어', [
    [
      KanaEntry.foreign('ファ', '파'),
      KanaEntry.foreign('フィ', '피'),
      KanaEntry.foreign('フェ', '페'),
    ],
    [
      KanaEntry.foreign('フォ', '포'),
      KanaEntry.foreign('ティ', '티'),
      KanaEntry.foreign('ディ', '디'),
    ],
    [
      KanaEntry.foreign('トゥ', '투'),
      KanaEntry.foreign('ドゥ', '두'),
      KanaEntry.foreign('テュ', '튜'),
    ],
    [
      KanaEntry.foreign('デュ', '듀'),
      KanaEntry.foreign('フュ', '퓨'),
      KanaEntry.foreign('ヴュ', '뷰'),
    ],
    [
      KanaEntry.foreign('ヴァ', '바'),
      KanaEntry.foreign('ヴィ', '비'),
      KanaEntry.foreign('ヴ', '브'),
    ],
    [
      KanaEntry.foreign('ヴェ', '베'),
      KanaEntry.foreign('ヴォ', '보'),
      KanaEntry.foreign('イェ', '예'),
    ],
    [
      KanaEntry.foreign('ウィ', '위'),
      KanaEntry.foreign('ウェ', '웨'),
      KanaEntry.foreign('ウォ', '워'),
    ],
    [
      KanaEntry.foreign('シェ', '셰'),
      KanaEntry.foreign('ジェ', '제'),
      KanaEntry.foreign('チェ', '체'),
    ],
    [
      KanaEntry.foreign('ツァ', '차'),
      KanaEntry.foreign('ツィ', '치'),
      KanaEntry.foreign('ツェ', '체'),
    ],
    [
      KanaEntry.foreign('ツォ', '초'),
      KanaEntry.foreign('クァ', '콰'),
      KanaEntry.foreign('クィ', '퀴'),
    ],
    [
      KanaEntry.foreign('クェ', '퀘'),
      KanaEntry.foreign('クォ', '쿼'),
      KanaEntry.foreign('グァ', '과'),
    ],
  ], ''),
];

const kanaReferences = [
  'https://www.bunka.go.jp/kokugo_nihongo/sisaku/joho/joho/kijun/naikaku/gairai/honbun01.html',
  'https://www.irodori.jpf.go.jp/assets/data/Kana_all.pdf',
  'https://a1.marugotoweb.jp/en/hiragana.php',
  'https://a1.marugotoweb.jp/en/katakana.php',
];

import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/parts_of_speech.dart';
import '../data/speech.dart';
import '../state/app_model.dart';
import 'common.dart';
import 'linked_example.dart';
import 'kanji_detail.dart';

class WordCard extends StatefulWidget {
  final AppModel model;
  final Speech speech;
  final Word word;
  final String profile;
  final bool temporaryReveal;
  final VoidCallback? onTap;
  const WordCard({
    super.key,
    required this.model,
    required this.speech,
    required this.word,
    required this.profile,
    this.temporaryReveal = false,
    this.onTap,
  });
  @override
  State<WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<WordCard> {
  late Future<List<List<Map<String, Object?>>>> details;
  bool openingDetail = false;

  Future<void> openWord(List<String> ids) async {
    if (openingDetail) return;
    openingDetail = true;
    try {
      await guard(context, () async {
        final words = (await Future.wait(
          ids.map(widget.model.repo.word),
        )).whereType<Word>().toList();
        if (!mounted || words.isEmpty) return;
        final id = words.length == 1
            ? words.single.id
            : await showModalBottomSheet<String>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (context) => SafeArea(
                  child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.55,
                    child: ListView(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('이동할 단어 선택'),
                        ),
                        for (final w in words)
                          ListTile(
                            title: Text('${w.surface} · ${w.reading}'),
                            subtitle: Text(w.meanings.join(' / ')),
                            onTap: () => Navigator.pop(context, w.id),
                          ),
                      ],
                    ),
                  ),
                ),
              );
        if (!mounted || id == null) return;
        await widget.speech.stop();
        if (!mounted) return;
        await push(
          context,
          StudyScreen(model: widget.model, speech: widget.speech, ids: [id]),
        );
      });
    } finally {
      openingDetail = false;
    }
  }

  Future<void> openKanji(String character) async {
    if (openingDetail) return;
    openingDetail = true;
    try {
      await guard(context, () async {
        final characters = (await details).first
            .map((k) => k['character'] as String)
            .toSet();
        final entries = (await Future.wait(
          characters.map(widget.model.repo.kanjiEntry),
        )).whereType<Map<String, Object?>>().toList();
        final initial = entries.indexWhere((k) => k['character'] == character);
        if (!mounted) return;
        if (initial < 0) {
          toast(context, '이 한자의 상세 정보가 없습니다.');
          return;
        }
        await widget.speech.stop();
        if (!mounted) return;
        await push(
          context,
          KanjiDetail(
            model: widget.model,
            speech: widget.speech,
            entries: entries,
            initial: initial,
          ),
        );
      });
    } finally {
      openingDetail = false;
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(WordCard old) {
    super.didUpdateWidget(old);
    if (old.word.id != widget.word.id) {
      load();
    }
  }

  void load() {
    details = Future.wait([
      widget.model.repo.components(widget.word.id),
      widget.model.repo.examples(widget.word.id),
    ]);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final w = widget.word;
      final compact = widget.profile == 'study';
      final vis = widget.model.visibility(widget.profile);
      bool show(String k) => widget.profile == 'test_front'
          ? false
          : widget.profile == 'test_back'
          ? true
          : widget.temporaryReveal || vis[k] == true;
      Widget field(String label, String value) => Padding(
        padding: EdgeInsets.only(top: compact ? 6 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            SizedBox(height: compact ? 2 : 4),
            SelectableText(value, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        w.surface,
                        locale: const Locale('ja'),
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                      ),
                    ),
                    StarButton(model: widget.model, id: w.id),
                    if (widget.profile != 'test_front')
                      IconButton(
                        tooltip: '단어 발음 듣기',
                        onPressed: () =>
                            speak(context, widget.speech, w.reading),
                        icon: const Icon(Icons.volume_up_outlined),
                      ),
                  ],
                ),
                if (show('reading')) field('가나 읽기', w.reading),
                if (show('meaning') && (w.meanings.isNotEmpty || !compact)) ...[
                  field(
                    '한국어 뜻',
                    w.meanings.isEmpty ? '한국어 뜻 준비 중' : w.meanings.join(' / '),
                  ),
                  if (w.meanings.isEmpty)
                    field('원문 영어 뜻', w.english.join(' / ')),
                ],
                if (show('meaning') && compact && w.meanings.isEmpty)
                  field('원문 영어 뜻', w.english.join(' / ')),
                if (show('part_of_speech'))
                  Padding(
                    padding: EdgeInsets.only(top: compact ? 6 : 12),
                    child: PosLabel(word: w),
                  ),
                if (!compact && show('jlpt_level')) field('비공식 학습 급수', w.level),
                if (show('korean_hun') ||
                    show('korean_eum') ||
                    show('kanji_reading') ||
                    show('example') ||
                    show('translation'))
                  AsyncView(
                    future: details,
                    builder: (data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (compact)
                          CompactKanji(
                            entries: data[0],
                            onOpen: openKanji,
                            showHun: show('korean_hun'),
                            showEum: show('korean_eum'),
                            showReading: show('kanji_reading'),
                          ),
                        for (final k
                            in compact ? <Map<String, Object?>>[] : data[0])
                          if (show('korean_hun') ||
                              show('korean_eum') ||
                              (show('kanji_reading') &&
                                  k['reading_alignment_status'] == 'verified'))
                            KanjiLink(
                              entry: k,
                              onOpen: openKanji,
                              child: field(
                                '${k['character']} · 한자 풀이',
                                [
                                  if (show('korean_hun') || show('korean_eum'))
                                    formatHunEum(
                                      k,
                                      showHun: show('korean_hun'),
                                      showEum: show('korean_eum'),
                                    ),
                                  if (show('kanji_reading') &&
                                      k['reading_alignment_status'] ==
                                          'verified')
                                    '이 단어의 읽기: ${k['reading_in_word']}',
                                ].join('\n'),
                              ),
                            ),
                        if (show('example') || show('translation'))
                          ExpansionTile(
                            key: ValueKey(
                              'examples:${w.id}:${widget.profile}:${widget.temporaryReveal}',
                            ),
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(bottom: 8),
                            initiallyExpanded: false,
                            title: Text(
                              '예문 · ${data[1].length}개',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            children: [
                              if (data[1].isEmpty) const Text('제공된 예문이 없습니다.'),
                              for (final ex in data[1])
                                ExampleBlock(
                                  key: ValueKey(
                                    'example:${ex['example_id']}:${widget.profile}:${widget.temporaryReveal}',
                                  ),
                                  example: ex,
                                  speech: widget.speech,
                                  showJapanese: show('example'),
                                  showTranslation: show('translation'),
                                  onOpenWord: openWord,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class ExampleBlock extends StatelessWidget {
  final Map<String, Object?> example;
  final Speech speech;
  final bool showJapanese, showTranslation;
  final ValueChanged<List<String>> onOpenWord;
  const ExampleBlock({
    super.key,
    required this.example,
    required this.speech,
    required this.showJapanese,
    required this.showTranslation,
    required this.onOpenWord,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showJapanese) ...[
          Text('일본어 예문', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          LinkedExampleText(
            text: example['text_ja'] as String,
            links:
                (example['links'] as List?)?.cast<Map<String, Object?>>() ?? [],
            onOpen: onOpenWord,
          ),
          if (example['furigana_markup'] != null) ...[
            const SizedBox(height: 6),
            Text(
              '후리가나 (원본 표기)',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Text(
              example['furigana_markup'] as String,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          TextButton.icon(
            onPressed: () =>
                speak(context, speech, example['text_ja'] as String),
            icon: const Icon(Icons.volume_up_outlined),
            label: const Text('예문 듣기'),
          ),
        ],
        if (showTranslation)
          ExpansionTile(
            key: ValueKey('translation:${example['example_id']}'),
            initiallyExpanded: false,
            maintainState: false,
            tilePadding: EdgeInsets.zero,
            title: const Text('해석 보기'),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    example['text_ko'] as String? ?? '번역 준비 중',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ],
          ),
        if (showJapanese)
          Text(
            'Tatoeba #${example['tatoeba_id'] ?? '미제공'} · CC BY 2.0 FR',
            style: Theme.of(context).textTheme.labelSmall,
          ),
      ],
    ),
  );
}

class PosLabel extends StatelessWidget {
  final Word word;
  const PosLabel({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    final pos = word.partOfSpeech;
    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${word.surface} · 품사',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(pos.display),
                if (pos.categories.isNotEmpty && pos.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(pos.tags.join(' · ')),
                ],
                const SizedBox(height: 16),
                const Text(
                  '사전 정보를 학습용 분류로 정리했습니다. 여러 용법이 있으면 품사를 함께 표시합니다. 자동사·타동사와 접두사·관용표현 등은 보조 태그로 구분합니다.',
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
              ],
            ),
          ),
        ),
      ),
      child: Semantics(
        button: true,
        label: '품사 설명 보기',
        child: Row(
          children: [
            Expanded(child: Text('품사: ${pos.display}')),
            const SizedBox(width: 4),
            Text('자세히', style: Theme.of(context).textTheme.labelMedium),
            const Icon(Icons.chevron_right, size: 16),
          ],
        ),
      ),
    );
  }
}

/// Avoid repeating the same missing-data warning for every kanji/field.
/// Full readings remain available; no unverified per-character readings are inferred.
class CompactKanji extends StatelessWidget {
  final List<Map<String, Object?>> entries;
  final ValueChanged<String> onOpen;
  final bool showHun, showEum, showReading;
  const CompactKanji({
    super.key,
    required this.entries,
    required this.onOpen,
    required this.showHun,
    required this.showEum,
    required this.showReading,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty ||
        (!showHun &&
            !showEum &&
            (!showReading ||
                !entries.any(
                  (k) => k['reading_alignment_status'] == 'verified',
                )))) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final k in entries)
            if (showHun ||
                showEum ||
                k['reading_alignment_status'] == 'verified')
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: KanjiLink(
                  entry: k,
                  onOpen: onOpen,
                  child: Text(
                    [
                      '${k['character']}',
                      if (showHun || showEum)
                        formatHunEum(k, showHun: showHun, showEum: showEum),
                      if (showReading &&
                          k['reading_alignment_status'] == 'verified')
                        '읽기 ${k['reading_in_word']}',
                    ].join(' · '),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class KanjiLink extends StatelessWidget {
  final Map<String, Object?> entry;
  final ValueChanged<String> onOpen;
  final Widget child;
  const KanjiLink({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final character = entry['character'] as String;
    return Semantics(
      button: true,
      label: '$character 한자 상세 보기',
      child: InkWell(
        key: ValueKey('kanji-link:$character:${entry['surface_pos']}'),
        onTap: () => onOpen(character),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
          child: child,
        ),
      ),
    );
  }
}

class StudyScreen extends StatefulWidget {
  final AppModel model;
  final Speech speech;
  // The caller's list identifies the starting word only. Browsing always uses
  // the full N5 → N1 catalog, independent of pages, filters and selections.
  final List<String> ids;
  final int initial;
  const StudyScreen({
    super.key,
    required this.model,
    required this.speech,
    required this.ids,
    this.initial = 0,
  });
  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  int index = 0;
  late List<String> ids;
  bool navigationReady = false;
  bool revealed = false;
  bool savingAnswer = false;
  final scroll = ScrollController();
  late Future<Word?> word;
  @override
  void initState() {
    super.initState();
    ids = [widget.ids[widget.initial]];
    load();
    guard(context, () async {
      final order = await widget.model.repo.allIds(const WordFilter());
      if (!mounted) return;
      final position = order.indexOf(ids.single);
      setState(() {
        if (position >= 0) {
          ids = order;
          index = position;
        }
        navigationReady = true;
      });
    });
  }

  void load() {
    word = widget.model.repo.word(ids[index]);
  }

  Future<void> toggleAnswer() async {
    if (savingAnswer) return;
    if (revealed) {
      setState(() => revealed = false);
      return;
    }
    final id = ids[index];
    final currentWord = word;
    setState(() => savingAnswer = true);
    await guard(context, () async {
      final loaded = await currentWord;
      if (loaded == null) return;
      // Opening/browsing a word does not complete it. Only this explicit reveal does.
      await widget.model.visit('word', id);
      if (mounted && ids[index] == id) setState(() => revealed = true);
    });
    if (mounted) setState(() => savingAnswer = false);
  }

  void move(int delta) {
    if (!navigationReady || index + delta < 0 || index + delta >= ids.length) {
      return;
    }
    if (scroll.hasClients) scroll.jumpTo(0);
    setState(() {
      index += delta;
      revealed = false;
      load();
    });
    widget.speech.stop();
  }

  @override
  void dispose() {
    scroll.dispose();
    widget.speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        navigationReady ? '단어 학습 · ${index + 1}/${ids.length}' : '단어 학습',
      ),
      actions: [
        LearningMarkButton(
          model: widget.model,
          kind: 'word',
          itemId: ids[index],
        ),
      ],
    ),
    body: ListView(
      key: const ValueKey('study-scroll'),
      controller: scroll,
      padding: const EdgeInsets.all(8),
      children: [
        AsyncView(
          future: word,
          builder: (Word? w) => w == null
              ? const Text('현재 콘텐츠에서 찾을 수 없는 단어입니다.')
              : WordCard(
                  key: ValueKey(w.id),
                  model: widget.model,
                  speech: widget.speech,
                  word: w,
                  profile: 'study',
                  temporaryReveal: revealed,
                ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              key: const ValueKey('study-previous'),
              onPressed: navigationReady && index > 0 ? () => move(-1) : null,
              child: const Text('이전'),
            ),
            Flexible(
              child: FilledButton.tonal(
                onPressed: savingAnswer ? null : toggleAnswer,
                child: Text(revealed ? '정답 닫기' : '정답 보기'),
              ),
            ),
            TextButton(
              key: const ValueKey('study-next'),
              onPressed: navigationReady && index + 1 < ids.length
                  ? () => move(1)
                  : null,
              child: const Text('다음'),
            ),
          ],
        ),
      ),
    ),
  );
}

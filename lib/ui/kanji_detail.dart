import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/parts_of_speech.dart';
import '../data/speech.dart';
import '../state/app_model.dart';
import 'cards.dart';
import 'common.dart';

class KanjiDetail extends StatefulWidget {
  final AppModel model;
  final Speech speech;
  final List<Map<String, Object?>> entries;
  final int initial;
  KanjiDetail({
    super.key,
    required this.model,
    required this.speech,
    required List<Map<String, Object?>> entries,
    this.initial = 0,
  }) : assert(entries.isNotEmpty),
       assert(initial >= 0 && initial < entries.length),
       entries = List.unmodifiable(entries);

  @override
  State<KanjiDetail> createState() => _KanjiDetailState();
}

class _KanjiDetailState extends State<KanjiDetail> {
  bool expanded = false;
  bool revealed = false;
  bool savingAnswer = false;
  late int index;
  late List<Map<String, Object?>> entries;
  bool navigationReady = false;
  final scroll = ScrollController();
  Future<List<Word>>? related;
  Future<List<Map<String, Object?>>>? composition;

  @override
  void initState() {
    super.initState();
    index = widget.initial;
    entries = widget.entries;
    final current = entries[index];
    guard(context, () async {
      final order = await widget.model.repo.kanji('N1', true, '');
      if (!mounted) return;
      final position = order.indexWhere(
        (k) => k['character'] == current['character'],
      );
      setState(() {
        // Supplemental characters have no assigned level; do not invent one.
        entries = position >= 0 ? order : [current];
        index = position >= 0 ? position : 0;
        navigationReady = true;
      });
    });
  }

  void move(int delta) {
    final next = index + delta;
    if (!navigationReady || next < 0 || next >= entries.length) return;
    if (scroll.hasClients) scroll.jumpTo(0);
    setState(() {
      index = next;
      expanded = false;
      revealed = false;
      related = null;
      composition = null;
    });
  }

  Future<void> toggleAnswer() async {
    if (savingAnswer) return;
    if (revealed) {
      setState(() {
        revealed = false;
        expanded = false;
        related = null;
      });
      return;
    }
    final character = entries[index]['character'] as String;
    setState(() => savingAnswer = true);
    await guard(context, () async {
      await widget.model.visit('kanji', character);
      if (mounted && entries[index]['character'] == character) {
        setState(() {
          revealed = true;
          composition ??= widget.model.repo.kanjiComponents(character);
        });
      }
    });
    if (mounted) setState(() => savingAnswer = false);
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = entries[index];
    final character = k['character'] as String;
    final onyomi = strings(k['onyomi_json']);
    final kunyomi = strings(k['kunyomi_json']);
    return Scaffold(
      appBar: AppBar(
        title: Text('$character · 한자 상세'),
        actions: [
          LearningMarkButton(
            model: widget.model,
            kind: 'kanji',
            itemId: character,
          ),
        ],
      ),
      body: ListView(
        key: const ValueKey('kanji-detail-scroll'),
        controller: scroll,
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            character,
            style: const TextStyle(fontSize: 80),
            textAlign: TextAlign.center,
          ),
          Text(
            navigationReady ? '${index + 1} / ${entries.length}' : '…',
            textAlign: TextAlign.center,
          ),
          if (revealed) ...[
            Text(
              k['jlpt_level'] == null ? '급수 미지정' : '${k['jlpt_level']}',
              textAlign: TextAlign.center,
            ),
            const SectionLabel('한국식 훈 · 음'),
            Text(formatHunEum(k)),
            const SectionLabel('일본어 음독'),
            Text(onyomi.isEmpty ? '읽기 정보 없음' : onyomi.join(' · ')),
            const SectionLabel('일본어 훈독'),
            Text(kunyomi.isEmpty ? '읽기 정보 없음' : kunyomi.join(' · ')),
            AsyncView(
              key: ValueKey('kanji-composition:$character'),
              future: composition!,
              builder: (parts) => parts.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionLabel('한자 구성'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (var i = 0; i < parts.length; i++) ...[
                              if (i > 0) const Text('+'),
                              component(parts[i]),
                            ],
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              key: ValueKey('related-words:$index:$character'),
              title: const Text('관련 단어'),
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: false,
              maintainState: false,
              onExpansionChanged: (value) => setState(() {
                expanded = value;
                if (value) related ??= widget.model.repo.related(character);
              }),
              children: [
                if (expanded)
                  AsyncView(
                    future: related!,
                    builder: (words) => words.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('관련 단어가 없습니다.'),
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < words.length; i++)
                                LearningTile(
                                  model: widget.model,
                                  kind: 'word',
                                  itemId: words[i].id,
                                  child: ListTile(
                                    key: ValueKey(
                                      'related-word:${words[i].id}',
                                    ),
                                    title: Text(words[i].surface),
                                    subtitle: Text(
                                      '${words[i].reading} · ${words[i].level}',
                                    ),
                                    trailing: StarButton(
                                      model: widget.model,
                                      id: words[i].id,
                                    ),
                                    onTap: () => push(
                                      context,
                                      StudyScreen(
                                        model: widget.model,
                                        speech: widget.speech,
                                        ids: words.map((w) => w.id).toList(),
                                        initial: i,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
              ],
            ),
          ],
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
                key: const ValueKey('kanji-previous'),
                onPressed: navigationReady && index > 0 ? () => move(-1) : null,
                child: const Text('이전'),
              ),
              Flexible(
                child: FilledButton.tonal(
                  onPressed: savingAnswer ? null : toggleAnswer,
                  child: Text(revealed ? '정답 숨기기' : '정답 보기'),
                ),
              ),
              TextButton(
                key: const ValueKey('kanji-next'),
                onPressed: navigationReady && index + 1 < entries.length
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

  Widget component(Map<String, Object?> part) {
    final glyph = part['glyph'] as String;
    final target = part['target_character'] as String?;
    final hunEum = target == null
        ? part['label_ko'] as String
        : formatHunEum(part);
    final partial = part['is_partial'] == 1;
    final text = [
      target != null && target != glyph ? '$glyph → $target' : glyph,
      if (partial) '일부',
      if (hunEum.isNotEmpty) hunEum,
    ].join(' ');
    final key = ValueKey('kanji-component:${part['sequence']}:$glyph');
    if (target == null) {
      return Chip(key: key, label: Text(text));
    }
    return ActionChip(
      key: key,
      label: Text(text),
      tooltip: '$target 한자 상세',
      onPressed: () => guard(context, () async {
        final entry = await widget.model.repo.kanjiEntry(target);
        if (!mounted || entry == null) return;
        await push(
          context,
          KanjiDetail(
            model: widget.model,
            speech: widget.speech,
            entries: [entry],
          ),
        );
      }),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../branding.dart';
import '../data/models.dart';
import '../data/parts_of_speech.dart';
import '../data/speech.dart';
import '../state/app_model.dart';
import 'cards.dart';
import 'common.dart';
import 'grammar.dart';
import 'kanji_detail.dart';
import 'kana.dart';
import 'tests.dart';

class Shell extends StatefulWidget {
  final AppModel model;
  final Speech speech;
  const Shell({super.key, required this.model, required this.speech});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    final speech = widget.speech;
    return Scaffold(
      appBar: AppBar(
        title: Text([appName, '한자', '가나 표', '별표 단어', '활용 문법'][tab]),
        actions: [
          IconButton(
            tooltip: '설정',
            onPressed: () => push(context, SettingsScreen(model: m)),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: switch (tab) {
        0 => HomeScreen(
          key: const ValueKey('word-home'),
          model: m,
          speech: speech,
          onLevel: (level) => push(
            context,
            Scaffold(
              appBar: AppBar(
                title: const Text('단어장'),
                actions: [
                  IconButton(
                    tooltip: '설정',
                    onPressed: () => push(context, SettingsScreen(model: m)),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              body: WordsScreen(model: m, speech: speech, initialLevel: level),
            ),
          ),
        ),
        1 => HomeScreen(
          key: const ValueKey('kanji-home'),
          model: m,
          speech: speech,
          kanji: true,
          onLevel: (level) => push(
            context,
            Scaffold(
              appBar: AppBar(
                title: const Text('한자장'),
                actions: [
                  IconButton(
                    tooltip: '설정',
                    onPressed: () => push(context, SettingsScreen(model: m)),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              body: KanjiScreen(model: m, speech: speech, initialLevel: level),
            ),
          ),
        ),
        2 => const KanaScreen(),
        3 => WordsScreen(
          key: const ValueKey('stars'),
          model: m,
          speech: speech,
          starred: true,
        ),
        _ => const GrammarScreen(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: '단어',
          ),
          NavigationDestination(icon: Icon(Icons.grid_view), label: '한자'),
          NavigationDestination(icon: Icon(Icons.translate), label: '가나'),
          NavigationDestination(icon: Icon(Icons.star_outline), label: '별표'),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            label: '문법',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final AppModel model;
  final Speech speech;
  final ValueChanged<String> onLevel;
  final bool kanji;
  const HomeScreen({
    super.key,
    required this.model,
    required this.speech,
    required this.onLevel,
    this.kanji = false,
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (!kanji)
          Text(appSubtitle, style: Theme.of(context).textTheme.bodyMedium),
        const SectionLabel('나의 학습 급수'),
        AsyncView(
          future: kanji ? model.repo.kanjiProgress() : model.repo.progress(),
          builder: (rows) => Column(
            children: [
              for (final r in rows)
                Card(
                  child: InkWell(
                    onTap: () => onLevel(r['jlpt_level'] as String),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                r['jlpt_level'] as String,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const Spacer(),
                              Text(
                                '${r['studied']}/${r['total']}${kanji ? '자' : '개'} 학습',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: (r['studied'] as int) / (r['total'] as int),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        AsyncView<String?>(
          future: kanji
              ? model.repo.firstUnlearnedKanji()
              : model.repo.firstUnlearnedWord(),
          builder: (id) => OutlinedButton.icon(
            onPressed: id == null
                ? null
                : () => guard(context, () async {
                    if (kanji) {
                      final entry = await model.repo.kanjiEntry(id);
                      if (entry != null && context.mounted) {
                        await push(
                          context,
                          KanjiDetail(
                            model: model,
                            speech: speech,
                            entries: [entry],
                          ),
                        );
                      }
                    } else {
                      await push(
                        context,
                        StudyScreen(model: model, speech: speech, ids: [id]),
                      );
                    }
                  }),
            icon: const Icon(Icons.bookmark_outline),
            label: Text(id == null ? '전체 학습 완료' : '이어서 학습'),
          ),
        ),
      ],
    ),
  );
}

class WordsScreen extends StatefulWidget {
  final AppModel model;
  final Speech speech;
  final String? initialLevel;
  final bool starred, selected;
  const WordsScreen({
    super.key,
    required this.model,
    required this.speech,
    this.initialLevel,
    this.starred = false,
    this.selected = false,
  });
  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends State<WordsScreen> {
  String? level;
  PartOfSpeech? partOfSpeech;
  String query = '';
  int page = 0;
  Timer? timer;
  final search = TextEditingController();
  @override
  void initState() {
    super.initState();
    level = widget.initialLevel;
  }

  @override
  void dispose() {
    timer?.cancel();
    search.dispose();
    super.dispose();
  }

  WordFilter get filter => WordFilter(
    level: level,
    partOfSpeech: partOfSpeech,
    query: query,
    starred: widget.starred,
    selected: widget.selected,
  );
  Future<void> jump(int pages) async {
    final c = TextEditingController();
    final v = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('페이지 이동 (1~$pages)'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '페이지 번호'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(c.text);
              if (n != null && n >= 1 && n <= pages) {
                Navigator.pop(context, n - 1);
              }
            },
            child: const Text('이동'),
          ),
        ],
      ),
    );
    if (v != null && mounted) {
      setState(() => page = v);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final m = widget.model;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: TextField(
              controller: search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '일본어 · 가나 · 한국어 뜻 검색',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                timer?.cancel();
                timer = Timer(const Duration(milliseconds: 250), () {
                  if (mounted) {
                    setState(() {
                      query = v;
                      page = 0;
                    });
                  }
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 12,
                children: [
                  DropdownButton<String>(
                    value: level ?? 'all',
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('모든 급수'),
                      ),
                      for (final l in levels)
                        DropdownMenuItem(value: l, child: Text(l)),
                    ],
                    onChanged: (v) => setState(() {
                      level = v == 'all' ? null : v;
                      page = 0;
                    }),
                  ),
                  DropdownButton<String>(
                    key: const ValueKey('pos-filter'),
                    value: partOfSpeech?.name ?? 'all',
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('모든 품사'),
                      ),
                      for (final p in PartOfSpeech.values)
                        DropdownMenuItem(value: p.name, child: Text(p.label)),
                    ],
                    onChanged: (v) => setState(() {
                      partOfSpeech = v == 'all'
                          ? null
                          : PartOfSpeech.values.byName(v!);
                      page = 0;
                    }),
                  ),
                  TextButton(
                    onPressed: () async {
                      await pageSizeDialog(context, m);
                      if (mounted) {
                        setState(() => page = 0);
                      }
                    },
                    child: Text('${m.pageSize}개씩'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: AsyncView(
              future: m.repo.words(filter, page, m.pageSize),
              builder: (result) {
                final ids = result.words.map((w) => w.id).toList();
                return Column(
                  children: [
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              tristate: true,
                              value: m.pageSelected(ids),
                              onChanged: ids.isEmpty
                                  ? null
                                  : (_) => guard(
                                      context,
                                      () => m.select(
                                        ids,
                                        m.pageSelected(ids) != true,
                                      ),
                                    ),
                            ),
                            const Text('현재 페이지 선택'),
                          ],
                        ),
                        TextButton(
                          onPressed: () => guard(context, () async {
                            await m.select(
                              await m.repo.allIds(WordFilter(level: level)),
                              true,
                            );
                          }),
                          child: Text(level == null ? '전체 급수 선택' : '단계 전체 선택'),
                        ),
                      ],
                    ),
                    Expanded(
                      child: result.total == 0
                          ? const Center(
                              child: Text(
                                '해당하는 단어가 없습니다.\n검색어나 필터를 바꿔보세요.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              itemCount: result.words.length,
                              itemBuilder: (context, i) {
                                final w = result.words[i];
                                return LearningTile(
                                  model: m,
                                  kind: 'word',
                                  itemId: w.id,
                                  child: ListTile(
                                    leading: Checkbox(
                                      value: m.selected.contains(w.id),
                                      onChanged: (v) => guard(
                                        context,
                                        () => m.select([w.id], v!),
                                      ),
                                    ),
                                    title: Text(
                                      w.surface,
                                      locale: const Locale('ja'),
                                      key: ValueKey('word-label:${w.id}'),
                                      style: const TextStyle(
                                        fontSize: 23,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${w.reading} · ${w.level}\n${w.meanings.isEmpty ? '한국어 뜻 준비 중' : w.meanings.join(' / ')}',
                                    ),
                                    isThreeLine: true,
                                    trailing: StarButton(model: m, id: w.id),
                                    onTap: () => push(
                                      context,
                                      StudyScreen(
                                        model: m,
                                        speech: widget.speech,
                                        ids: ids,
                                        initial: i,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          tooltip: '이전 페이지',
                          onPressed: result.page > 0
                              ? () => setState(() => page = result.page - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        TextButton(
                          onPressed: () => jump(result.pages),
                          child: Text(
                            '${result.page + 1} / ${result.pages} 페이지',
                          ),
                        ),
                        IconButton(
                          tooltip: '다음 페이지',
                          onPressed: result.page + 1 < result.pages
                              ? () => setState(() => page = result.page + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                        Text(
                          '${result.total == 0 ? 0 : result.page * result.size + 1}–${result.page * result.size + result.words.length} / ${result.total}',
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          SelectionBar(
            model: m,
            speech: widget.speech,
            inSelection: widget.selected,
          ),
        ],
      );
    },
  );
}

class SelectionBar extends StatelessWidget {
  final AppModel model;
  final Speech speech;
  final bool inSelection;
  const SelectionBar({
    super.key,
    required this.model,
    required this.speech,
    this.inSelection = false,
  });
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            TextButton(
              onPressed: inSelection
                  ? null
                  : () => push(
                      context,
                      Scaffold(
                        appBar: AppBar(title: const Text('선택한 단어')),
                        body: Column(
                          children: [
                            Expanded(
                              child: WordsScreen(
                                model: model,
                                speech: speech,
                                selected: true,
                              ),
                            ),
                            if (model.selected.isNotEmpty)
                              TextButton(
                                onPressed: () => guard(context, () async {
                                  final ids = await model.repo.allIds(
                                    const WordFilter(selected: true),
                                  );
                                  await model.select(
                                    model.selected.difference(ids.toSet()),
                                    false,
                                  );
                                }),
                                child: const Text('현재 콘텐츠에 없는 선택 항목 정리'),
                              ),
                          ],
                        ),
                      ),
                    ),
              child: Text('선택 ${model.selected.length}개'),
            ),
            TextButton(
              onPressed: model.selected.isEmpty
                  ? null
                  : () => guard(context, model.clearSelection),
              child: const Text('선택 해제'),
            ),
            TextButton(
              onPressed: model.selected.any((id) => model.isLearned('word', id))
                  ? () => guard(
                      context,
                      () => model.clearVisitItems('word', model.selected),
                    )
                  : null,
              child: const Text('학습 표시 해제'),
            ),
            FilledButton.icon(
              onPressed: model.selected.isEmpty
                  ? null
                  : () => push(
                      context,
                      TestSetupScreen(model: model, speech: speech),
                    ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('테스트'),
            ),
          ],
        ),
      ),
    ),
  );
}

class KanjiScreen extends StatefulWidget {
  final AppModel model;
  final Speech speech;
  final bool selected;
  final String initialLevel;
  const KanjiScreen({
    super.key,
    required this.model,
    required this.speech,
    this.selected = false,
    this.initialLevel = 'N5',
  });
  @override
  State<KanjiScreen> createState() => _KanjiScreenState();
}

class _KanjiScreenState extends State<KanjiScreen> {
  String? level;
  String query = '';
  int page = 0;
  bool starting = false;
  @override
  void initState() {
    super.initState();
    level = widget.selected ? null : widget.initialLevel;
  }

  Future<void> jump(int pages) async {
    var text = '';
    final chosen = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('페이지 이동 (1~$pages)'),
        content: TextField(
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '페이지 번호'),
          onChanged: (v) => text = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(text);
              if (n != null && n >= 1 && n <= pages) {
                Navigator.pop(context, n - 1);
              }
            },
            child: const Text('이동'),
          ),
        ],
      ),
    );
    if (chosen != null && mounted) setState(() => page = chosen);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final m = widget.model;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '한자 · 한국식 훈 · 음 검색',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() {
                query = v;
                page = 0;
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: level ?? 'all',
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('모든 급수')),
                    for (final l in levels)
                      DropdownMenuItem(value: l, child: Text(l)),
                  ],
                  onChanged: (v) => setState(() {
                    level = v == 'all' ? null : v;
                    page = 0;
                  }),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () async {
                    await pageSizeDialog(context, m);
                    if (mounted) setState(() => page = 0);
                  },
                  child: Text('${m.pageSize}개씩'),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView(
              future: m.repo.kanji(level ?? 'N1', level == null, query),
              builder: (allRows) {
                final rows = allRows
                    .where(
                      (k) =>
                          !widget.selected ||
                          m.kanjiSelected.contains(k['character']),
                    )
                    .toList();
                final pages = ((rows.length / m.pageSize).ceil()).clamp(
                  1,
                  100000,
                );
                final safePage = page.clamp(0, pages - 1);
                final visible = rows
                    .skip(safePage * m.pageSize)
                    .take(m.pageSize)
                    .toList();
                final ids = visible
                    .map((k) => k['character'] as String)
                    .toList();
                return Column(
                  children: [
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              key: const ValueKey('kanji-page-checkbox'),
                              tristate: true,
                              value: m.pageSelected(ids, kanji: true),
                              onChanged: ids.isEmpty
                                  ? null
                                  : (_) => guard(
                                      context,
                                      () => m.selectKanji(
                                        ids,
                                        m.pageSelected(ids, kanji: true) !=
                                            true,
                                      ),
                                    ),
                            ),
                            const Text('현재 페이지 선택'),
                          ],
                        ),
                        TextButton(
                          onPressed: () => guard(context, () async {
                            final all = await m.repo.kanji(
                              level ?? 'N1',
                              level == null,
                              '',
                            );
                            await m.selectKanji(
                              all.map((k) => k['character'] as String),
                              true,
                            );
                          }),
                          child: Text(level == null ? '전체 급수 선택' : '단계 전체 선택'),
                        ),
                      ],
                    ),
                    Expanded(
                      child: rows.isEmpty
                          ? const Center(child: Text('해당하는 한자가 없습니다.'))
                          : ListView.builder(
                              key: const ValueKey('kanji-list'),
                              itemCount: visible.length,
                              itemBuilder: (context, i) {
                                final k = visible[i];
                                final character = k['character'] as String;
                                return LearningTile(
                                  model: m,
                                  kind: 'kanji',
                                  itemId: character,
                                  child: ListTile(
                                    leading: Checkbox(
                                      key: ValueKey(
                                        'kanji-checkbox:$character',
                                      ),
                                      value: m.kanjiSelected.contains(
                                        character,
                                      ),
                                      onChanged: (v) => guard(
                                        context,
                                        () => m.selectKanji([character], v!),
                                      ),
                                    ),
                                    title: Text(
                                      character,
                                      key: ValueKey('kanji-label:$character'),
                                      locale: const Locale('ja'),
                                      style: const TextStyle(
                                        fontSize: 23,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                    subtitle: Text(formatHunEum(k)),
                                    onTap: () => push(
                                      context,
                                      KanjiDetail(
                                        model: m,
                                        speech: widget.speech,
                                        entries: visible,
                                        initial: i,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          tooltip: '이전 페이지',
                          onPressed: safePage > 0
                              ? () => setState(() => page = safePage - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        TextButton(
                          onPressed: () => jump(pages),
                          child: Text('${safePage + 1} / $pages 페이지'),
                        ),
                        IconButton(
                          tooltip: '다음 페이지',
                          onPressed: safePage + 1 < pages
                              ? () => setState(() => page = safePage + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                        Text(
                          '${rows.isEmpty ? 0 : safePage * m.pageSize + 1}–${safePage * m.pageSize + visible.length} / ${rows.length}',
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: widget.selected
                          ? null
                          : () => push(
                              context,
                              Scaffold(
                                appBar: AppBar(title: const Text('선택한 한자')),
                                body: KanjiScreen(
                                  model: m,
                                  speech: widget.speech,
                                  selected: true,
                                ),
                              ),
                            ),
                      child: Text('선택 ${m.kanjiSelected.length}개'),
                    ),
                    TextButton(
                      onPressed: m.kanjiSelected.isEmpty
                          ? null
                          : () => guard(context, m.clearKanjiSelection),
                      child: const Text('선택 해제'),
                    ),
                    TextButton(
                      onPressed:
                          m.kanjiSelected.any((id) => m.isLearned('kanji', id))
                          ? () => guard(
                              context,
                              () => m.clearVisitItems('kanji', m.kanjiSelected),
                            )
                          : null,
                      child: const Text('학습 표시 해제'),
                    ),
                    FilledButton.icon(
                      onPressed: starting || m.kanjiSelected.isEmpty
                          ? null
                          : () => guard(context, () async {
                              setState(() => starting = true);
                              try {
                                final session = await m.repo.start(
                                  m.kanjiSelected.map((c) => 'kanji:$c'),
                                  kind: 'kanji',
                                );
                                if (context.mounted) {
                                  await push(
                                    context,
                                    TestScreen(
                                      model: m,
                                      speech: widget.speech,
                                      sessionId: session.id,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => starting = false);
                              }
                            }),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(starting ? '준비 중…' : '한자 테스트'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class SettingsScreen extends StatelessWidget {
  final AppModel model;
  const SettingsScreen({super.key, required this.model});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ListTile(
            title: const Text('페이지당 항목 수'),
            subtitle: Text('${model.pageSize}개 · 직접 입력 1~200'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pageSizeDialog(context, model),
          ),
          ListTile(
            title: const Text('화면 테마'),
            trailing: DropdownButton<String>(
              value: model.theme,
              items: [
                for (final e in {
                  'system': '시스템',
                  'light': '밝게',
                  'dark': '어둡게',
                }.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) =>
                  guard(context, () => model.preference('theme', v)),
            ),
          ),
          const SectionLabel('로컬 데이터 관리'),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: const Text('사용자 기록 백업'),
            subtitle: const Text('별표 · 선택 · 설정 · 학습 표시를 JSON 파일로 저장'),
            onTap: () => guard(context, () async {
              final bytes = Uint8List.fromList(
                utf8.encode(await model.repo.backup()),
              );
              final path = await FilePicker.platform.saveFile(
                dialogTitle: '학습 기록 백업',
                fileName:
                    'jlpt-backup-${DateTime.now().millisecondsSinceEpoch}.json',
                bytes: bytes,
              );
              if (path != null && context.mounted) {
                toast(context, '백업을 저장했습니다.');
              }
            }),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('백업에서 복원'),
            subtitle: const Text('현재 사용자 기록을 선택한 백업 내용으로 교체'),
            onTap: () => guard(context, () async {
              final picked = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['json'],
                withData: true,
              );
              if (picked == null || !context.mounted) {
                return;
              }
              final f = picked.files.single;
              final text = utf8.decode(
                f.bytes ?? await File(f.path!).readAsBytes(),
              );
              if (!context.mounted) {
                return;
              }
              final yes = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('백업으로 교체할까요?'),
                  content: const Text(
                    '현재 별표·선택·설정·학습 표시가 이 백업 내용으로 교체됩니다. 필요한 경우 먼저 백업해주세요.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('복원'),
                    ),
                  ],
                ),
              );
              if (yes == true) {
                await model.repo.restore(text);
                await model.load();
                if (context.mounted) {
                  toast(context, '복원했습니다.');
                }
              }
            }),
          ),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('출처 · 라이선스'),
            onTap: () => push(context, const NoticesScreen()),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '일본어 TTS는 기기의 음성 엔진을 사용합니다. 오프라인 재생을 위해 기기 설정에서 일본어 음성 데이터를 다운로드해주세요.\n\n콘텐츠는 앱 업데이트로 교체되며 사용자 기록은 별도 DB에 유지됩니다. 앱 삭제 시 기기 내부 기록도 삭제되므로 백업 파일을 보관해주세요.',
            ),
          ),
        ],
      ),
    ),
  );
}

class NoticesScreen extends StatelessWidget {
  const NoticesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('출처 · 라이선스')),
    body: AsyncView(
      future: Future.wait([
        rootBundle.loadString('assets/DATA_NOTICE.txt'),
        rootBundle.loadString('assets/OPENJLPT_NOTICE.txt'),
        rootBundle.loadString('assets/LOCALIZATION_NOTICE.txt'),
      ]),
      builder: (texts) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SelectableText(texts.join('\n\n')),
      ),
    ),
  );
}

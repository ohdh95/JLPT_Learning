import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/parts_of_speech.dart';
import '../data/speech.dart';
import '../state/app_model.dart';
import 'cards.dart';
import 'common.dart';

class TestSetupScreen extends StatefulWidget {
  final AppModel model;
  final Speech speech;
  const TestSetupScreen({super.key, required this.model, required this.speech});
  @override
  State<TestSetupScreen> createState() => _TestSetupScreenState();
}

class _TestSetupScreenState extends State<TestSetupScreen> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('테스트 준비')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${widget.model.selected.length}개 단어를 무작위로 출제합니다.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy || widget.model.selected.isEmpty
                ? null
                : () => guard(context, () async {
                    setState(() => busy = true);
                    try {
                      final s = await widget.model.repo.start(
                        widget.model.selected,
                      );
                      widget.model.refresh();
                      if (context.mounted) {
                        await Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => TestScreen(
                              model: widget.model,
                              speech: widget.speech,
                              sessionId: s.id,
                            ),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  }),
            icon: const Icon(Icons.play_arrow),
            label: Text(busy ? '준비 중…' : '테스트 시작'),
          ),
          const SectionLabel('출제할 단어'),
          AsyncView(
            future: widget.model.repo.words(
              const WordFilter(selected: true),
              0,
              20,
            ),
            builder: (page) => Column(
              children: [
                for (final word in page.words)
                  ListTile(
                    title: Text(word.surface),
                    subtitle: Text(word.reading),
                    trailing: IconButton(
                      tooltip: '선택 해제',
                      icon: const Icon(Icons.close),
                      onPressed: () => guard(
                        context,
                        () => widget.model.select([word.id], false),
                      ),
                    ),
                  ),
                if (widget.model.selected.length > 20)
                  Text('처음 20개 미리보기 · 전체 ${widget.model.selected.length}개 출제'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class TestScreen extends StatefulWidget {
  final AppModel model;
  final Speech speech;
  final String sessionId;
  const TestScreen({
    super.key,
    required this.model,
    required this.speech,
    required this.sessionId,
  });
  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  late Future<TestSession> future;
  bool busy = false;
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    future = widget.model.repo.session(widget.sessionId);
  }

  Future<void> act(
    Future<void> Function() fn, {
    bool resetScroll = false,
  }) async {
    if (busy) return;
    setState(() => busy = true);
    await guard(context, () async {
      await fn();
      await widget.speech.stop();
      widget.model.refresh();
      if (mounted) {
        if (resetScroll && scroll.hasClients) scroll.jumpTo(0);
        setState(() {
          future = widget.model.repo.session(widget.sessionId);
        });
      }
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> retry(TestSession s) => act(() async {
    final next = await widget.model.repo.retryAll(s);
    if (mounted) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TestScreen(
            model: widget.model,
            speech: widget.speech,
            sessionId: next.id,
          ),
        ),
      );
    }
  });
  @override
  void dispose() {
    scroll.dispose();
    widget.speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('카드 테스트'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('나가기'),
        ),
      ],
    ),
    body: AsyncView(
      future: future,
      builder: (s) {
        if (s.complete) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    '테스트 완료',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text('${s.isKanji ? '한자' : '단어'} ${s.order.length}개 확인'),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : () => retry(s),
                    child: const Text('전체 재시험'),
                  ),
                ],
              ),
            ),
          );
        }
        final id = s.order[s.index];
        void reveal() => act(() => widget.model.repo.reveal(s.id));
        return Column(
          children: [
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(12),
                children: [
                  Text(
                    '${s.isKanji ? '한자' : '단어'} · ${s.index + 1} / ${s.order.length} · ${s.revealed ? '뒷면' : '앞면'}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: s.index / s.order.length),
                  if (s.isKanji)
                    KanjiQuizCard(
                      entry: s.kanjiSnapshot(id),
                      revealed: s.revealed,
                      onTap: s.revealed || busy ? null : reveal,
                    )
                  else
                    WordCard(
                      key: ValueKey(id),
                      model: widget.model,
                      speech: widget.speech,
                      word: s.snapshot(id),
                      profile: s.revealed ? 'test_back' : 'test_front',
                      onTap: s.revealed || busy ? null : reveal,
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  key: const ValueKey('test-action'),
                  onPressed: busy
                      ? null
                      : s.revealed
                      ? () => act(
                          () => widget.model.repo.advance(s.id, id),
                          resetScroll: true,
                        )
                      : reveal,
                  child: Text(
                    s.revealed
                        ? (s.index + 1 == s.order.length ? '테스트 완료' : '다음 문제')
                        : '정답 확인 · 뒤집기',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class KanjiQuizCard extends StatelessWidget {
  final Map<String, Object?> entry;
  final bool revealed;
  final VoidCallback? onTap;
  const KanjiQuizCard({
    super.key,
    required this.entry,
    required this.revealed,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              entry['character'] as String,
              locale: const Locale('ja'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 80),
            ),
            if (revealed) ...[
              const SectionLabel('한국식 훈 · 음'),
              Text(formatHunEum(entry)),
              const SectionLabel('일본어 음독'),
              Text(
                strings(entry['onyomi_json']).isEmpty
                    ? '읽기 정보 없음'
                    : strings(entry['onyomi_json']).join(' · '),
              ),
              const SectionLabel('일본어 훈독'),
              Text(
                strings(entry['kunyomi_json']).isEmpty
                    ? '읽기 정보 없음'
                    : strings(entry['kunyomi_json']).join(' · '),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

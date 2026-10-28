import 'package:flutter/material.dart';
import '../data/speech.dart';
import '../state/app_model.dart';

void toast(BuildContext context, String text) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

Future<void> guard(BuildContext context, Future<void> Function() fn) async {
  try {
    await fn();
  } catch (e) {
    if (context.mounted) {
      debugPrint('Operation failed: $e');
      final message = e is StateError
          ? e.message.toString()
          : e is ArgumentError
          ? (e.message ?? '입력값을 확인해주세요.').toString()
          : e is FormatException
          ? '백업 파일이 올바르지 않습니다. 다른 백업 파일을 선택해주세요.'
          : '작업을 완료하지 못했습니다. 저장 공간을 확인하고 다시 시도해주세요.';
      toast(context, message);
    }
  }
}

Future<void> speak(BuildContext context, Speech speech, String text) async {
  final error = await speech.speak(text);
  if (error != null && context.mounted) {
    toast(context, error);
  }
}

Future<T?> push<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

class AsyncView<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T) builder;
  const AsyncView({super.key, required this.future, required this.builder});
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, s) {
      if (s.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: const Text('불러오지 못했습니다. 화면을 다시 열어주세요.'),
          ),
        );
      }
      if (s.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return builder(s.data as T);
    },
  );
}

Future<void> pageSizeDialog(BuildContext context, AppModel model) async {
  final c = TextEditingController(text: '${model.pageSize}');
  String? error;
  final size = await showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, set) => AlertDialog(
        title: const Text('페이지 크기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 4,
              children: [
                for (final n in [10, 20, 30, 50, 100])
                  ActionChip(label: Text('$n'), onPressed: () => c.text = '$n'),
              ],
            ),
            TextField(
              controller: c,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '직접 입력 (1~200)',
                errorText: error,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(c.text);
              if (n == null || n < 1 || n > 200) {
                set(() => error = '1~200 사이의 정수를 입력하세요.');
              } else {
                Navigator.pop(context, n);
              }
            },
            child: const Text('적용'),
          ),
        ],
      ),
    ),
  );
  // The dialog's exit animation may still read its controller.
  if (size != null && context.mounted) {
    await guard(context, () => model.setPageSize(size));
  }
}

class StarButton extends StatelessWidget {
  final AppModel model;
  final String id;
  const StarButton({super.key, required this.model, required this.id});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => IconButton(
      tooltip: model.starred.contains(id) ? '별표 해제' : '별표 추가',
      onPressed: () => guard(context, () => model.star(id)),
      icon: Icon(
        model.starred.contains(id)
            ? Icons.star_rounded
            : Icons.star_outline_rounded,
        color: model.starred.contains(id) ? Colors.amber.shade700 : null,
      ),
    ),
  );
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class LearningMarkButton extends StatelessWidget {
  final AppModel model;
  final String kind, itemId;
  const LearningMarkButton({
    super.key,
    required this.model,
    required this.kind,
    required this.itemId,
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final marked = model.isLearned(kind, itemId);
      if (!marked) return const SizedBox.shrink();
      return IconButton(
        tooltip: marked ? '학습 표시 해제' : '학습 표시하기',
        onPressed: () => guard(
          context,
          () => marked
              ? model.clearVisits(kind, itemId: itemId)
              : model.visit(kind, itemId),
        ),
        icon: Icon(marked ? Icons.check_circle : Icons.check_circle_outline),
      );
    },
  );
}

Color completedTileColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF424242)
    : const Color(0xFFE0E0E0);

class LearningTile extends StatelessWidget {
  final AppModel model;
  final String kind, itemId;
  final Widget child;
  const LearningTile({
    super.key,
    required this.model,
    required this.kind,
    required this.itemId,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => Material(
      key: ValueKey('$kind-tile:$itemId'),
      color: model.isLearned(kind, itemId)
          ? completedTileColor(context)
          : Colors.transparent,
      child: child,
    ),
  );
}

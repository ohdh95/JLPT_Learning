import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// TextSpan keeps Japanese sentences naturally wrapped, including at 320px.
/// Offsets are UTF-16, as used by Dart strings. Recognizers live with this widget.
class LinkedExampleText extends StatefulWidget {
  final String text;
  final List<Map<String, Object?>> links;
  final ValueChanged<List<String>> onOpen;
  const LinkedExampleText({
    super.key,
    required this.text,
    required this.links,
    required this.onOpen,
  });
  @override
  State<LinkedExampleText> createState() => _LinkedExampleTextState();
}

class _LinkedExampleTextState extends State<LinkedExampleText> {
  final List<TapGestureRecognizer> recognizers = [];
  final List<({int start, int end, List<String> ids})> spans = [];
  @override
  void initState() {
    super.initState();
    prepare();
  }

  @override
  void didUpdateWidget(LinkedExampleText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.links != widget.links) {
      prepare();
    }
  }

  void clear() {
    for (final r in recognizers) {
      r.dispose();
    }
    recognizers.clear();
    spans.clear();
  }

  void prepare() {
    clear();
    final sorted = List<Map<String, Object?>>.of(widget.links)
      ..sort((a, b) {
        final first = (a['start_offset'] as int).compareTo(
          b['start_offset'] as int,
        );
        return first != 0
            ? first
            : (a['end_offset'] as int).compareTo(b['end_offset'] as int);
      });
    for (final link in sorted) {
      final start = link['start_offset'] as int,
          end = link['end_offset'] as int;
      if (start < 0 || end <= start || end > widget.text.length) continue;
      if (spans.isNotEmpty &&
          start == spans.last.start &&
          end == spans.last.end) {
        final id = link['word_id'] as String;
        if (!spans.last.ids.contains(id)) spans.last.ids.add(id);
      } else if (spans.isEmpty || start >= spans.last.end) {
        spans.add((start: start, end: end, ids: [link['word_id'] as String]));
      }
    }
    for (final span in spans) {
      recognizers.add(
        TapGestureRecognizer()..onTap = () => widget.onOpen(span.ids),
      );
    }
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final children = <InlineSpan>[];
    var offset = 0;
    for (var i = 0; i < spans.length; i++) {
      final span = spans[i];
      if (offset < span.start) {
        children.add(TextSpan(text: widget.text.substring(offset, span.start)));
      }
      children.add(
        TextSpan(
          text: widget.text.substring(span.start, span.end),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
          recognizer: recognizers[i],
          mouseCursor: SystemMouseCursors.click,
        ),
      );
      offset = span.end;
    }
    if (offset < widget.text.length) {
      children.add(TextSpan(text: widget.text.substring(offset)));
    }
    return Text.rich(
      TextSpan(children: children),
      locale: const Locale('ja'),
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}

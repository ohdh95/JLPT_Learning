import 'package:flutter/material.dart';
import '../data/kana.dart';

class KanaScreen extends StatefulWidget {
  const KanaScreen({super.key});
  @override
  State<KanaScreen> createState() => _KanaScreenState();
}

class _KanaScreenState extends State<KanaScreen> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    final group = kanaGroups[selected];
    final hasHiragana = group.rows
        .expand((row) => row)
        .any((e) => e?.hiragana != null);
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < kanaGroups.length; i++)
                ChoiceChip(
                  label: Text(kanaGroups[i].title),
                  selected: selected == i,
                  onSelected: (_) => setState(() => selected = i),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            key: ValueKey('kana-group:$selected'),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            children: [
              Text(hasHiragana ? '히라가나 · 가타카나 · 한글 발음' : '가타카나 · 한글 발음'),
              const SizedBox(height: 12),
              Table(
                border: TableBorder.all(color: colors.outlineVariant),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  for (final row in group.rows)
                    TableRow(
                      children: [
                        for (final entry in row)
                          entry == null
                              ? const SizedBox.shrink()
                              : Semantics(
                                  label:
                                      '${entry.hiragana == null ? '' : '히라가나 ${entry.hiragana}, '}가타카나 ${entry.katakana}, 발음 ${entry.korean}',
                                  excludeSemantics: true,
                                  child: Padding(
                                    key: ValueKey(
                                      'kana:${entry.hiragana ?? entry.katakana}',
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                      vertical: 8,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (entry.hiragana != null)
                                          Text(
                                            entry.hiragana!,
                                            locale: const Locale('ja'),
                                            style: TextStyle(
                                              fontSize: 23,
                                              color: colors.primary,
                                            ),
                                          ),
                                        Text(
                                          entry.katakana,
                                          locale: const Locale('ja'),
                                          style: TextStyle(
                                            fontSize: entry.hiragana == null
                                                ? 23
                                                : 18,
                                            color: entry.hiragana == null
                                                ? colors.primary
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          entry.korean,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

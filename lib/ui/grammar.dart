import 'package:flutter/material.dart';
import '../data/grammar.dart';
import 'common.dart';

class GrammarScreen extends StatelessWidget {
  const GrammarScreen({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      for (final lesson in grammarLessons)
        Card(
          child: ListTile(
            key: ValueKey('grammar-${lesson.id}'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(lesson.title),
            subtitle: Text(lesson.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => push(context, GrammarDetail(lesson: lesson)),
          ),
        ),
    ],
  );
}

class GrammarDetail extends StatelessWidget {
  final GrammarLesson lesson;
  const GrammarDetail({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${lesson.title} 활용')),
    body: ListView(
      key: ValueKey('grammar-detail-${lesson.id}'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(lesson.subtitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Text(lesson.summary),
        const SizedBox(height: 16),
        for (final section in lesson.sections)
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              key: PageStorageKey('${lesson.id}:${section.title}'),
              initiallyExpanded: section.expanded,
              title: Text(section.title),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final form in section.forms)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          form.label,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          form.example,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                locale: const Locale('ja'),
                                color: Theme.of(context).colorScheme.primary,
                                height: 1.5,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          form.rule,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SectionLabel('함께 기억하기'),
        for (final note in lesson.notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(note),
          ),
      ],
    ),
  );
}

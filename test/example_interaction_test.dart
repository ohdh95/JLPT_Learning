import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_study/ui/cards.dart';
import 'package:jlpt_study/ui/linked_example.dart';
import 'package:jlpt_study/ui/tests.dart';
import 'support.dart';
import 'widget_test.dart' show settle;

Future<void> tapLink(WidgetTester t, String sentence, String token) async {
  final widget = find.byWidgetPredicate(
    (w) => w is LinkedExampleText && w.text == sentence,
  );
  await t.ensureVisible(widget);
  await t.pumpAndSettle();
  final rich = find.descendant(of: widget, matching: find.byType(RichText));
  final render = t.renderObject<RenderParagraph>(rich);
  final start = sentence.indexOf(token);
  final box = render
      .getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + token.length),
      )
      .first;
  await t.tapAt(render.localToGlobal(box.toRect().center));
  await settle(t);
}

void main() {
  late Fixture f;
  setUp(() async {
    f = Fixture();
    await f.open();
    await f.model.allFields('study', true);
  });
  tearDown(() async {
    await f.close();
  });

  testWidgets(
    'each translation starts closed and closes again with the example group',
    (t) async {
      final examples = (await t.runAsync(() => f.repo.examples('ada066edfd')))!;
      await t.pumpWidget(
        MaterialApp(
          home: StudyScreen(
            model: f.model,
            speech: SilentSpeech(),
            ids: const ['ada066edfd', 'ebec658463'],
          ),
        ),
      );
      await settle(t);
      expect(find.textContaining('미검수'), findsNothing);
      expect(find.textContaining('초안'), findsNothing);
      if (find.text('정답 보기').evaluate().isNotEmpty) {
        await t.tap(find.text('정답 보기'));
        await settle(t);
      }
      await t.tap(find.textContaining('예문 ·'));
      await settle(t);
      for (final ex in examples) {
        expect(find.text(ex['text_ko'] as String), findsNothing);
      }
      await t.ensureVisible(find.text('해석 보기').first);
      await t.tap(find.text('해석 보기').first);
      await settle(t);
      expect(find.text(examples.first['text_ko'] as String), findsOneWidget);
      expect(find.text(examples.last['text_ko'] as String), findsNothing);
      t
          .widget<ListView>(find.byKey(const ValueKey('study-scroll')))
          .controller!
          .jumpTo(0);
      await settle(t);
      expect(find.textContaining('예문 ·').hitTestable(), findsOneWidget);
      if (find.text('정답 보기').evaluate().isNotEmpty) {
        await t.tap(find.text('정답 보기'));
        await settle(t);
      }
      await t.tap(find.textContaining('예문 ·'));
      await settle(t);
      expect(find.byType(LinkedExampleText), findsNothing);
      if (find.text('정답 보기').evaluate().isNotEmpty) {
        await t.tap(find.text('정답 보기'));
        await settle(t);
      }
      await t.tap(find.textContaining('예문 ·'));
      await settle(t);
      expect(find.text(examples.first['text_ko'] as String), findsNothing);
      await t.tap(find.text('다음'));
      await settle(t);
      expect(find.text('해석 보기'), findsNothing);
      expect(f.model.visibility('study')['translation'], false);
      expect(t.takeException(), null);
    },
  );

  testWidgets(
    'tap a real example word, navigate back and preserve parent state and selections',
    (t) async {
      await t.runAsync(() => f.model.select(['ada066edfd'], true));
      final examples = (await t.runAsync(() => f.repo.examples('ada066edfd')))!;
      await t.pumpWidget(
        MaterialApp(
          home: StudyScreen(
            model: f.model,
            speech: SilentSpeech(),
            ids: const ['ada066edfd', 'ebec658463'],
          ),
        ),
      );
      await settle(t);
      if (find.text('정답 보기').evaluate().isNotEmpty) {
        await t.tap(find.text('정답 보기'));
        await settle(t);
      }
      await t.tap(find.textContaining('예문 ·'));
      await settle(t);
      await tapLink(t, examples.last['text_ja'] as String, 'パーティー');
      expect(find.textContaining('/7811'), findsOneWidget);
      expect(find.text('パーティー'), findsWidgets);
      expect(find.text('일본어 예문'), findsNothing);
      await t.tap(find.byType(BackButton));
      await settle(t);
      expect(find.text('단어 학습 · 1/20'), findsNothing);
      expect(find.text('단어 학습 · 1/7811'), findsOneWidget);
      expect(find.byType(LinkedExampleText), findsNWidgets(2));
      expect(f.model.selected, {'ada066edfd'});
      expect(f.model.visibility('study')['translation'], false);
      expect(t.takeException(), null);
    },
  );

  testWidgets(
    'ambiguous links offer headwords and do not choose a reading silently',
    (t) async {
      await t.runAsync(() async {
        await f.repo.db.delete(
          'content.example_word_links',
          where: 'example_id=?',
          whereArgs: ['ada066edfd_1'],
        );
        await f.repo.db.update(
          'content.examples',
          {'text_ja': '今日'},
          where: 'example_id=?',
          whereArgs: ['ada066edfd_1'],
        );
        final words = await f.repo.db.rawQuery(
          "SELECT word_id FROM content.vocab WHERE surface='今日'",
        );
        expect(words.length, greaterThan(1));
        for (final w in words) {
          await f.repo.db.insert('content.example_word_links', {
            'example_id': 'ada066edfd_1',
            'start_offset': 0,
            'end_offset': 2,
            'word_id': w['word_id'],
            'match_form': '今日',
          });
        }
      });
      await t.pumpWidget(
        MaterialApp(
          home: StudyScreen(
            model: f.model,
            speech: SilentSpeech(),
            ids: const ['ada066edfd'],
          ),
        ),
      );
      await settle(t);
      if (find.text('정답 보기').evaluate().isNotEmpty) {
        await t.tap(find.text('정답 보기'));
        await settle(t);
      }
      await t.tap(find.textContaining('예문 ·'));
      await settle(t);
      await tapLink(t, '今日', '今日');
      expect(find.text('이동할 단어 선택'), findsOneWidget);
      expect(find.textContaining('きょう'), findsWidgets);
      expect(find.textContaining('こんにち'), findsWidgets);
      await t.tap(find.textContaining('きょう').last);
      await settle(t);
      expect(find.text('이동할 단어 선택'), findsNothing);
      expect(find.text('今日'), findsWidgets);
      expect(t.takeException(), null);
    },
  );

  testWidgets(
    'opening an example word from the test back does not advance the test',
    (t) async {
      await t.runAsync(() => f.model.allFields('test_front', true));
      final session = (await t.runAsync(() => f.repo.start(['ada066edfd'])))!;
      final examples = (await t.runAsync(() => f.repo.examples('ada066edfd')))!;
      await t.pumpWidget(
        MaterialApp(
          home: TestScreen(
            model: f.model,
            speech: SilentSpeech(),
            sessionId: session.id,
          ),
        ),
      );
      await settle(t);
      expect(find.textContaining('예문 ·'), findsNothing);
      await t.tap(find.text('정답 확인 · 뒤집기'));
      await settle(t);
      await t.ensureVisible(find.textContaining('예문 ·'));
      await settle(t);
      if (find.text('정답 보기').evaluate().isNotEmpty) {
        await t.tap(find.text('정답 보기'));
        await settle(t);
      }
      await t.tap(find.textContaining('예문 ·'));
      await settle(t);
      await tapLink(t, examples.last['text_ja'] as String, 'パーティー');
      expect(find.textContaining('/7811'), findsOneWidget);
      await t.tap(find.byType(BackButton));
      await settle(t);
      expect(find.text('테스트 완료'), findsOneWidget);
      final saved = (await t.runAsync(() => f.repo.session(session.id)))!;
      expect(saved.revealed, true);
      expect(saved.responses, isEmpty);
      expect(t.takeException(), null);
    },
  );

  testWidgets(
    'UTF16 links preserve emoji and update without keeping stale gestures',
    (t) async {
      List<String>? opened;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LinkedExampleText(
              text: '😀学校へ',
              links: const [
                {'start_offset': 2, 'end_offset': 4, 'word_id': 'school'},
              ],
              onOpen: (ids) => opened = ids,
            ),
          ),
        ),
      );
      await tapLink(t, '😀学校へ', '学校');
      expect(opened, ['school']);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LinkedExampleText(
              text: '😀学校へ',
              links: const [],
              onOpen: (ids) => opened = ids,
            ),
          ),
        ),
      );
      opened = null;
      await tapLink(t, '😀学校へ', '学校');
      expect(opened, null);
      expect(t.takeException(), null);
    },
  );
}

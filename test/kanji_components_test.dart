import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_study/ui/kanji_detail.dart';
import 'support.dart';
import 'widget_test.dart' show settle;

void main() {
  late Fixture f;
  setUp(() async {
    f = Fixture();
    await f.open();
  });
  tearDown(() async => f.close());

  Future<void> open(WidgetTester t, String character) async {
    final entry = await t.runAsync(() => f.repo.kanjiEntry(character));
    await t.pumpWidget(
      MaterialApp(
        home: KanjiDetail(
          model: f.model,
          speech: SilentSpeech(),
          entries: [entry!],
        ),
      ),
    );
    await settle(t);
  }

  test(
    'source variants, duplicates and supplemental targets resolve offline',
    () async {
      final rest = await f.repo.kanjiComponents('休');
      expect(rest.map((r) => r['glyph']), ['亻', '木']);
      expect(rest.map((r) => r['target_character']), ['人', '木']);
      final woods = await f.repo.kanjiComponents('林');
      expect(woods.map((r) => r['target_character']), ['木', '木']);
      expect(await f.repo.kanjiComponents('木'), isEmpty);
      expect(await f.repo.kanjiComponents('人'), isEmpty);
      expect(await f.repo.kanjiComponents('日'), isEmpty);
      final self = (await f.repo.kanjiEntry('吾'))!;
      expect(self['jlpt_level'], isNull);
      expect(self['korean_hun'], isNotEmpty);
      expect(self['onyomi_json'], isNot('[]'));
      expect(self['korean_hun_eum_status'], 'draft');
      expect(await f.repo.kanji('N1', true, '吾'), isEmpty);
    },
  );

  testWidgets(
    'components hide before reveal; variant drilldown preserves parent',
    (t) async {
      t.view.physicalSize = const Size(360, 720);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await open(t, '休');
      expect(find.text('한자 구성'), findsNothing);
      expect(f.model.isLearned('kanji', '休'), false);
      await t.tap(find.text('정답 보기'));
      await settle(t);
      final link = find.byKey(const ValueKey('kanji-component:0:亻'));
      await t.ensureVisible(link);
      await settle(t);
      expect(find.text('亻 → 人 사람 인'), findsOneWidget);
      final controller = t
          .widget<ListView>(find.byKey(const ValueKey('kanji-detail-scroll')))
          .controller!;
      final offset = controller.offset;
      await t.tap(link);
      await settle(t);
      expect(find.text('人 · 한자 상세'), findsOneWidget);
      expect(find.text('한자 구성'), findsNothing);
      expect(find.text('정답 보기'), findsOneWidget);
      expect(f.model.isLearned('kanji', '人'), false);
      await t.tap(find.byType(BackButton));
      await settle(t);
      expect(find.text('休 · 한자 상세'), findsOneWidget);
      expect(find.text('정답 숨기기'), findsOneWidget);
      expect(controller.offset, offset);
      expect(f.model.isLearned('kanji', '休'), true);
      await t.tap(find.text('정답 숨기기'));
      await settle(t);
      expect(find.text('한자 구성'), findsNothing);
      await t.tap(find.text('정답 보기'));
      await settle(t);
      expect(find.text('한자 구성'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('kanji-next')));
      await settle(t);
      expect(find.text('한자 구성'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('basic characters never display an empty composition section', (
    t,
  ) async {
    await open(t, '木');
    await t.tap(find.text('정답 보기'));
    await settle(t);
    expect(find.text('한국식 훈 · 음'), findsOneWidget);
    expect(find.text('한자 구성'), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('supplemental component supports recursive detail and return', (
    t,
  ) async {
    await open(t, '語');
    await t.tap(find.text('정답 보기'));
    await settle(t);
    final link = find.byKey(const ValueKey('kanji-component:1:吾'));
    await t.ensureVisible(link);
    await settle(t);
    await t.tap(link);
    await settle(t);
    expect(find.text('吾 · 한자 상세'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(
      t.widget<TextButton>(find.byKey(const ValueKey('kanji-next'))).onPressed,
      isNull,
    );
    await t.tap(find.text('정답 보기'));
    await settle(t);
    final five = find.byKey(const ValueKey('kanji-component:0:五'));
    await t.ensureVisible(five);
    await settle(t);
    await t.tap(five);
    await settle(t);
    expect(find.text('五 · 한자 상세'), findsOneWidget);
    expect(f.model.isLearned('kanji', '五'), false);
    await t.tap(find.byType(BackButton));
    await settle(t);
    expect(find.text('吾 · 한자 상세'), findsOneWidget);
    expect(find.text('정답 숨기기'), findsOneWidget);
    await t.tap(find.byType(BackButton));
    await settle(t);
    expect(find.text('語 · 한자 상세'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.runAsync(() async {
      f.model.dispose();
      await f.repo.close();
      await f.reopen();
    });
    expect(f.model.isLearned('kanji', '吾'), true);
  });
}

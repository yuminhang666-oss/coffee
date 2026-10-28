import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_journal/core/models.dart';
import 'package:coffee_journal/main.dart';
import 'package:coffee_journal/ui/app.dart';
import 'package:coffee_journal/ui/design.dart';
import 'package:coffee_journal/ui/editors.dart';
import 'package:coffee_journal/ui/flavor_picker.dart';
import 'package:coffee_journal/ui/sensory.dart';
import 'package:coffee_journal/ui/history_compare.dart';

import 'widget_test.dart' show MemoryStore, ready;

Finder field(String label) => find.ancestor(
  of: find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  ),
  matching: find.byType(TextFormField),
);
Cup sample({
  String id = 'c',
  double grams = 15.5,
  num water = 240.5,
  int? temperature = 0,
  List<String> tastes = const [],
  List<String> ids = const [],
}) => Cup(
  id: id,
  name: 'Synthetic QA',
  at: DateTime(2026, 10, 28),
  beanId: 'b',
  grams: grams,
  water: water,
  temperature: temperature,
  seconds: 150,
  tastes: tastes,
  tasteIds: ids,
);
void main() {
  test('Duration lexical validation distinguishes blank, zero, invalid seconds and upper bound', () {
    expect(parseDuration('2', '30'), 150);
    expect(durationText(150), '2分30秒');
    expect(parseDuration('0', '45'), 45);
    expect(durationText(45), '0分45秒');
    expect(parseDuration('1440', '0'), 86400);
    for (final pair in [
      ['', ''],
      ['0', '0'],
      ['2', '60'],
      ['2', '-1'],
      ['2', '1.5'],
      ['NaN', '30'],
      ['1440', '1'],
    ]) {
      expect(parseDuration(pair[0], pair[1]), null);
    }
    expect(parseDuration('', '45'), 45);
    expect(parseDuration('2', ''), 120);
  });
  test(
    'Every gram field rejects negative, nonfinite and extra decimal precision',
    () {
      expect(parseTenths('15'), 150);
      expect(parseTenths('15.5'), 155);
      expect(parseTenths('240.5'), 2405);
      for (final s in [
        '-1',
        'NaN',
        'Infinity',
        '15.55',
        '15.50',
        '1e2',
        '1.',
        '',
      ]) {
        expect(parseTenths(s), null, reason: s);
      }
      expect(gramsText(15), '15');
      expect(gramsText(15.5), '15.5');
      expect(ratioText(0, 240), '未记录');
      expect(ratioText(double.nan, 240), '未记录');
    },
  );
  test(
    'schema 2 migrates units, roast and origins without inventing information',
    () {
      final legacy = jsonDecode(
        File('test/fixtures/schema1-example.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      legacy['schema'] = 2;
      legacy['adjustments'] = [];
      for (final b in legacy['beans']) {
        b['weightTenths'] = (b.remove('weight') as int) * 10;
        b['origin'] = 'Unknown farm / producer / blend';
      }
      for (final c in legacy['cups']) {
        c['gramsTenths'] = ((c.remove('grams') as num) * 10).round();
        c['water'] = 240;
        c['temperature'] = null;
      }
      final d = CoffeeData.decode(jsonEncode(legacy));
      expect(d.toJson()['schema'], 3);
      expect(d.cups.first.waterTenths, 2400);
      expect(d.cups.first.seconds, 150);
      expect(d.beans.first.roast, 'light');
      expect(d.beans.first.origin, 'Unknown farm / producer / blend');
      expect(d.beans.first.country, '');
      expect(d.beans.first.farm, '');
      expect(d.beans.first.varieties, isEmpty);
      expect(d.beans.first.sensory, everyElement(isNull));
      expect(d.cups.first.temperature, null);
      expect(d.cups.first.tastes, contains('柑橘'));
      expect(d.cups.first.tastes, isNot(contains('柠檬')));
      expect(d.cups.first.resolvedTasteIds, contains(builtInFlavorId('柑橘')));
      for (final v in [0, 4, 999, 3.5]) {
        expect(
          () => CoffeeData.decode(jsonEncode({...d.toJson(), 'schema': v})),
          throwsFormatException,
        );
      }
    },
  );
  test('Decimal water and stock survive edit, move, restart, backup, restore and failure', () async {
    final store = MemoryStore();
    final ct = await ready(store);
    const b = Bean(id: 'b', name: 'Synthetic bag');
    const b2 = Bean(id: 'b2', name: 'Other bag');
    await ct.saveBean(b);
    await ct.saveBean(b2);
    expect(await ct.saveCup(sample()), true);
    await ct.saveCup(sample(id: 'c2', grams: 15.6));
    expect(ct.data.remainingTenths(b), 2189);
    final encoded = ct.data.encode();
    expect((jsonDecode(encoded)['cups'] as List).first['waterTenths'], 2405);
    final restarted = await ready(store);
    expect(restarted.data.cups.first.water, 240.5);
    await restarted.saveCup(
      Cup.fromJson({...sample().toJson(), 'beanId': 'b2'}),
    );
    expect(restarted.data.remainingTenths(b), 2344);
    expect(restarted.data.remainingTenths(b2), 2345);
    await restarted.removeCup('c');
    expect(restarted.data.remainingTenths(b2), 2500);
    await restarted.restore(CoffeeData.decode(encoded));
    expect(restarted.data.remainingTenths(b), 2189);
    final old = store.raw;
    store.fail = true;
    expect(await restarted.saveCup(sample(id: 'failure')), false);
    expect(store.raw, old);
    store.fail = false;
    expect(await restarted.saveCup(sample(water: 240.55)), false);
    expect(store.raw, old);
    expect(await restarted.saveCup(sample(temperature: 101)), false);
    expect(store.raw, old);
    final reuse = restarted.data.cups.first.parametersFor(
      b,
      DateTime(2026, 10, 29),
    );
    expect(reuse.water, 240.5);
    expect(reuse.note, '');
    expect(reuse.tastes, isEmpty);
    expect(reuse.favorite, false);
    expect(reuse.temperature, 0);
  });
  test('Six roast IDs and partial/zero/half sensory values persist without averaging', () async {
    final ct = await ready();
    for (final r in roastNames.keys) {
      expect(
        await ct.saveBean(
          Bean(
            id: 'b',
            name: 'Bag',
            roast: r,
            sensory: const [null, 0, 1, 5, 10, null],
          ),
        ),
        true,
      );
      expect(CoffeeData.decode(ct.data.encode()).beans.single.roast, r);
    }
    expect(ct.data.beans.single.sensory, [null, 0, 1, 5, 10, null]);
    await ct.saveCup(sample());
    expect(ct.data.beans.single.sensory, [null, 0, 1, 5, 10, null]);
    final invalid = {
      ...ct.data.beans.single.toJson(),
      'sensory': [0, 1, 2, 3, 4, 11],
    };
    expect(() => Bean.fromJson(invalid), throwsFormatException);
    final b = Bean.fromJson({
      ...ct.data.beans.single.toJson(),
      'sensory': List<int?>.filled(6, null),
    });
    expect(await ct.saveBean(b), true);
    expect(
      CoffeeData.decode(ct.data.encode()).beans.single.sensory,
      everyElement(isNull),
    );
  });
  test('Custom identities retain historical words after rename, deactivate, restore and undo', () async {
    final store = MemoryStore();
    final ct = await ready(store);
    const term = FlavorTerm(id: 'custom-qa', label: '合成香气', group: 'floral');
    await ct.saveFlavor(term);
    await ct.saveBean(const Bean(id: 'b', name: 'Bag', bagFlavors: ['茉莉']));
    await ct.saveCup(sample(tastes: ['合成香气'], ids: [term.id]));
    final before = ct.data.encode();
    await ct.saveFlavor(
      const FlavorTerm(
        id: 'custom-qa',
        label: '合成新名称',
        group: 'floral',
        active: false,
      ),
    );
    final after = ct.data.encode();
    expect(ct.data.cups.single.tastes, ['合成香气']);
    final restored = CoffeeData.decode(after);
    expect(restored.customFlavors.single.active, false);
    expect(restored.cups.single.tastes, ['合成香气']);
    await ct.restore(CoffeeData.decode(before));
    expect(store.previous, after);
    await ct.change((_) => CoffeeData.decode(store.previous!));
    expect(ct.data.customFlavors.single.label, '合成新名称');
    expect(
      await ct.saveFlavor(
        const FlavorTerm(id: 'custom-alias', label: 'Jasmine', group: 'floral'),
      ),
      false,
    );
    expect(ct.data.customFlavors.length, 1);
  });
  test('Vocabulary covers detailed light roasts and aliases without selecting anything', () {
    expect(builtInFlavors.length, greaterThan(100));
    expect(knownFlavor(' jasmine ')?.label, '茉莉');
    expect(knownFlavor(' Citrus ')?.id, builtInFlavorId('柑橘'));
    expect(knownFlavor('berries')?.label, '莓果');
    expect(knownFlavor('CREAM')?.label, '奶油');
    expect(knownFlavor(' 茉莉花 ')?.id, knownFlavor('茉莉')?.id);
    expect(
      roastRecommendations['ultraLight']!.split(' ').length,
      greaterThan(20),
    );
    expect(
      roastRecommendations['light'],
      isNot(roastRecommendations['ultraLight']),
    );
    expect(
      roastDays(
        Bean(id: 'b', name: 'B', roastedAt: DateTime(2026, 10, 27, 23, 59)),
        DateTime(2026, 10, 28, 0, 1),
      ),
      1,
    );
    expect(roastDays(const Bean(id: 'b', name: 'B'), DateTime.now()), null);
  });
  testWidgets(
    'New cup requires visible temperature; invalid seconds/precision preserve draft and prevent writes',
    (t) async {
      final ct = await ready();
      await ct.saveBean(const Bean(id: 'b', name: 'Bag'));
      await t.pumpWidget(
        MaterialApp(
          home: CupEditor(controller: ct, bean: ct.data.beans.single),
        ),
      );
      expect(field('水温 / °C'), findsOneWidget);
      expect(t.widget<TextFormField>(field('水温 / °C')).controller!.text, '');
      for (final e in {
        '粉量 / g': '15.5',
        '注水 / g': '240.55',
        '分': '2',
        '秒（0–59）': '60',
      }.entries) {
        await t.enterText(field(e.key), e.value);
      }
      await t.tap(find.text('保存这杯的记忆'));
      await t.pumpAndSettle();
      expect(ct.data.cups, isEmpty);
      expect(find.text('秒须为 0–59 的整数'), findsOneWidget);
      expect(find.text('请填写实际水温'), findsOneWidget);
      await t.enterText(field('注水 / g'), '240.5');
      await t.enterText(field('秒（0–59）'), '30');
      await t.enterText(field('水温 / °C'), '0');
      await t.tap(find.text('保存这杯的记忆'));
      await t.pumpAndSettle();
      expect(ct.data.cups.single.waterTenths, 2405);
      expect(ct.data.cups.single.seconds, 150);
      expect(ct.data.cups.single.temperature, 0);
    },
  );
  testWidgets(
    'Editing old missing-temperature cup keeps it null; duplicate taps debit only once',
    (t) async {
      final ct = await ready();
      await ct.saveBean(const Bean(id: 'b', name: 'Bag'));
      final old = sample(temperature: null);
      await ct.saveCup(old);
      await t.pumpWidget(
        MaterialApp(
          home: CupEditor(controller: ct, cup: old),
        ),
      );
      expect(t.widget<TextFormField>(field('分')).controller!.text, '2');
      expect(t.widget<TextFormField>(field('秒（0–59）')).controller!.text, '30');
      await t.tap(find.text('保存这杯的记忆'));
      await t.tap(find.text('保存这杯的记忆'));
      await t.pumpAndSettle();
      expect(ct.data.cups.length, 1);
      expect(ct.data.remainingTenths(ct.data.beans.single), 2345);
      expect(ct.data.cups.single.temperature, null);
    },
  );
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      '320px / 2x layout: bean editor, flavor selection, sensory and comparison $brightness',
      (t) async {
        t.view.physicalSize = const Size(320, 850);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final ct = await ready();
        final longLabel = '长' * 40;
        await ct.saveFlavor(
          FlavorTerm(id: 'custom-long', label: longLabel, group: 'floral'),
        );
        final b = Bean(
          id: 'b',
          name: '合成豆名' * 12,
          farm: '合成长庄园' * 20,
          varieties: ['V' * 80],
          roast: 'ultraLight',
        );
        await ct.saveBean(b);
        final widgets = <Widget>[
          BeanEditor(controller: ct, bean: b),
          FlavorPicker(
            controller: ct,
            selection: {
              for (final f in builtInFlavors.take(24)) f.id: f.label,
              'custom-long': longLabel,
            },
            roast: 'ultraLight',
          ),
          SensoryEditor(controller: ct, bean: b),
          HistoryCompare(
            cups: [
              sample(),
              sample(id: 'c2'),
            ],
          ),
          BeanDetail(controller: ct, id: 'b'),
        ];
        for (final w in widgets) {
          await t.pumpWidget(
            MaterialApp(
              key: UniqueKey(),
              theme: coffeeTheme(brightness),
              home: w,
            ),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: w.runtimeType.toString());
          t.view.viewInsets = const FakeViewPadding(bottom: 300);
          await t.pumpAndSettle();
          expect(
            t.takeException(),
            isNull,
            reason: '${w.runtimeType} keyboard',
          );
          t.view.resetViewInsets();
          await t.pumpAndSettle();
          final list = find.byType(Scrollable).last;
          for (var i = 0; i < 12; i++) {
            await t.drag(list, const Offset(0, -500));
            await t.pumpAndSettle();
            expect(
              t.takeException(),
              isNull,
              reason: '${w.runtimeType} scroll $i',
            );
          }
        }
      },
    );
  }

  testWidgets(
    'Flavor browsing keeps 24 selected snapshots across category and origin changes',
    (t) async {
      final ct = await ready();
      final selected = {for (final f in builtInFlavors.take(24)) f.id: f.label};
      Map<String, String>? result;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await pickFlavors(
                    context,
                    ct,
                    selected,
                    roast: 'ultraLight',
                  );
                },
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open picker'));
      await t.pumpAndSettle();
      await t.tap(find.text('极浅烘焙'));
      await t.pumpAndSettle();
      await t.tap(find.text('浅度烘焙').last);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('全部分类'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await t.tap(find.text('全部分类'));
      await t.pumpAndSettle();
      await t.tap(find.text('柑橘').last);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('不按产区推荐'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await t.tap(find.text('不按产区推荐'));
      await t.pumpAndSettle();
      await t.tap(find.text('埃塞俄比亚').last);
      await t.pumpAndSettle();
      await t.tap(find.text('完成'));
      await t.pumpAndSettle();
      expect(result, selected);
      expect(ct.data.cups, isEmpty);
    },
  );
  testWidgets(
    'Custom vocabulary editor protects unsaved text and retains it on write failure',
    (t) async {
      final store = MemoryStore();
      final ct = await ready(store);
      store.fail = true;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FlavorEditor(controller: ct),
                  ),
                ),
                child: const Text('Open custom'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open custom'));
      await t.pumpAndSettle();
      await t.enterText(field('风味名称'), 'QA distinct aroma');
      await t.tap(find.text('保存风味词'));
      await t.pumpAndSettle();
      expect(ct.data.customFlavors, isEmpty);
      expect(
        t.widget<TextFormField>(field('风味名称')).controller!.text,
        'QA distinct aroma',
      );
      await t.tap(find.byTooltip('返回'));
      await t.pumpAndSettle();
      expect(find.text('放弃风味词编辑？'), findsOneWidget);
      await t.tap(find.text('取消'));
      await t.pumpAndSettle();
      store.fail = false;
      await t.tap(find.text('保存风味词'));
      await t.pumpAndSettle();
      expect(ct.data.customFlavors.single.label, 'QA distinct aroma');
    },
  );

  testWidgets(
    'Restoring another bean collection clears an unavailable journal bean filter',
    (t) async {
      final ct = await ready(
        MemoryStore(
          const CoffeeData(
            onboarded: true,
            beans: [Bean(id: 'b', name: 'QA filter bag')],
          ).encode(),
        ),
      );
      await t.pumpWidget(CoffeeApp(controller: ct));
      await t.pumpAndSettle();
      await t.tap(find.text('手记').last);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('所有豆子'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await t.tap(find.text('所有豆子'));
      await t.pumpAndSettle();
      await t.tap(find.text('QA filter bag').last);
      await t.pumpAndSettle();
      await ct.restore(CoffeeData.example(DateTime(2026, 10, 28)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('所有豆子'), findsOneWidget);
    },
  );

  testWidgets(
    'Deleting a cup shows actual stock-correction impact instead of an expression',
    (t) async {
      final ct = await ready();
      const b = Bean(id: 'b', name: 'QA impact');
      await ct.saveBean(b);
      final c = sample();
      await ct.saveCup(c);
      await ct.adjustStock(b, 2000, 'QA correction');
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showCup(context, ct, c),
                child: const Text('Open impact'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open impact'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('删除手记'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await t.tap(find.text('删除手记'));
      await t.pumpAndSettle();
      expect(find.textContaining('已有库存校正'), findsOneWidget);
      expect(find.textContaining('200 → 215.5 g'), findsOneWidget);
      expect(find.textContaining('ct.stockImpact'), findsNothing);
      expect(ct.data.cups.length, 1);
    },
  );
}

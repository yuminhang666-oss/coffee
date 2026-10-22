import 'dart:convert';
import 'dart:io';

import 'package:coffee_journal/core/controller.dart';
import 'package:coffee_journal/core/models.dart';
import 'package:coffee_journal/main.dart';
import 'package:coffee_journal/ui/app.dart';
import 'package:coffee_journal/ui/design.dart';
import 'package:coffee_journal/ui/editors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show MemoryStore, ready, cup;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final legacy = File('test/fixtures/schema1-example.json').readAsStringSync();
  test('Explicit schema 1 migration preserves every old field and ID', () {
    final old = jsonDecode(legacy) as Map;
    final migrated = CoffeeData.decode(legacy);
    expect(migrated.toJson()['schema'], 2);
    for (var i = 0; i < migrated.cups.length; i++) {
      final original = Map<String, dynamic>.from(old['cups'][i] as Map);
      final newCup = migrated.cups[i].toJson();
      final grams = original.remove('grams');
      for (final e in original.entries) {
        expect(newCup[e.key], e.value);
      }
      expect(newCup['gramsTenths'], ((grams as num) * 10).round());
      expect(newCup['temperature'], null);
      expect(newCup['grind'], '');
    }
    for (var i = 0; i < migrated.beans.length; i++) {
      final original = Map<String, dynamic>.from(old['beans'][i] as Map);
      final weight = original.remove('weight');
      for (final e in original.entries) {
        expect(migrated.beans[i].toJson()[e.key], e.value);
      }
      expect(migrated.beans[i].weightTenths, (weight as int) * 10);
      expect(migrated.beans[i].photo, '');
    }
    expect(migrated.theme, old['theme']);
    expect(migrated.demo, old['demo']);
    expect(migrated.onboarded, old['onboarded']);
    expect(migrated.adjustments, isEmpty);
    expect(
      () =>
          CoffeeData.decode(legacy.replaceFirst('"schema": 1', '"schema": 99')),
      throwsFormatException,
    );
  });
  test(
    'Parameter reuse carries equipment only and resets completed-record fields',
    () {
      final source = Cup(
        id: 'old',
        name: 'Old',
        at: DateTime(2020),
        beanId: 'b',
        grams: 15.5,
        water: 240,
        seconds: 145,
        note: 'Private feelings',
        rating: 5,
        favorite: true,
        cents: 880,
        tastes: const ['花香'],
        shop: 'Cafe',
        brewer: 'V60',
        grinder: 'C40',
        grind: '22 clicks',
        temperature: 93,
      );
      final now = DateTime(2026, 10, 22, 12);
      final reused = source.parametersFor(
        const Bean(id: 'b', name: 'Bag'),
        now,
      );
      expect(reused.at, now);
      expect(reused.id, isNot(source.id));
      expect(reused.note, '');
      expect(reused.rating, 0);
      expect(reused.favorite, false);
      expect(reused.cents, 0);
      expect(reused.tastes, isEmpty);
      expect(reused.shop, '');
      expect(reused.gramsTenths, 155);
      expect(reused.water, 240);
      expect(reused.seconds, 145);
      expect(reused.brewer, 'V60');
      expect(reused.grinder, 'C40');
      expect(reused.grind, '22 clicks');
      expect(reused.temperature, 93);
    },
  );
  test('Corrections remain independent across edit, move, delete, restart and finance', () async {
    final store = MemoryStore();
    final c = await ready(store);
    const a = Bean(id: 'b', name: 'A', weight: 100.1, cents: 8800);
    const b = Bean(id: 'b2', name: 'B', weight: 100);
    await c.saveBean(a);
    await c.saveBean(b);
    await c.saveCup(cup('c', grams: 10.1));
    expect(c.data.remainingTenths(a), 900);
    expect(await c.adjustStock(a, 800, '调磨损耗'), true);
    final correction = c.data.adjustments.single.toJson();
    expect(correction['before'], 900);
    expect(correction['after'], 800);
    expect(c.data.cups.length, 1);
    expect(c.data.beans.fold<int>(0, (s, b) => s + b.cents), 8800);
    await c.saveCup(cup('c', grams: 20.1));
    expect(c.data.remainingTenths(a), 700);
    await c.saveCup(cup('c', beanId: 'b2', grams: 20.1));
    expect(c.data.remainingTenths(a), 901);
    expect(c.data.remainingTenths(b), 799);
    await c.removeCup('c');
    expect(c.data.remainingTenths(b), 1000);
    expect(c.data.adjustments.single.toJson(), correction);
    final restarted = await ready(store);
    expect(restarted.data.remainingTenths(a), 901);
    await restarted.removeBean('b');
    expect(restarted.data.adjustments.single.beanName, 'A');
    expect(restarted.data.adjustments.single.beanId, '');
  });
  test(
    'Conflicting historical edit cannot truncate stock or discard corrections',
    () async {
      final store = MemoryStore();
      final c = await ready(store);
      const b = Bean(id: 'b', name: 'A', weight: 20);
      await c.saveBean(b);
      await c.saveCup(cup('c', grams: 10));
      await c.adjustStock(b, 200, '称量校正');
      final before = store.raw;
      expect(await c.removeCup('c'), false);
      expect(store.raw, before);
      expect(c.data.adjustments.length, 1);
      expect(c.error, contains('30.0 g'));
      expect(c.error, contains('先校正'));
      await c.adjustStock(b, 100, '先撤回重复校正');
      expect(await c.removeCup('c'), true);
      expect(c.data.remaining(b), 20);
    },
  );
  test(
    'Repeated tenth-gram cups and adjustments have no accumulation error',
    () async {
      final c = await ready();
      const b = Bean(id: 'b', name: 'A', weight: 50.1);
      await c.saveBean(b);
      for (var i = 0; i < 100; i++) {
        await c.saveCup(cup('$i', grams: .1));
      }
      for (var i = 0; i < 100; i++) {
        await c.adjustStock(b, c.data.remainingTenths(b) - 1, '0.1 g');
      }
      expect(c.data.remainingTenths(b), 301);
      expect(c.data.cups.length, 100);
      expect(CoffeeData.decode(c.data.encode()).remaining(b), 30.1);
    },
  );
  test(
    'Photo references, adjustment IDs and integer units are strictly validated',
    () {
      final map = CoffeeData.example(DateTime.now()).toJson();
      (map['beans'] as List).first['photo'] = '../other.jpg';
      expect(() => CoffeeData.decode(jsonEncode(map)), throwsFormatException);
      (map['beans'] as List).first['photo'] = '';
      (map['cups'] as List).first['gramsTenths'] = 150.5;
      expect(() => CoffeeData.decode(jsonEncode(map)), throwsFormatException);
    },
  );

  group('Android storage bridge', () {
    String? raw, previous, imported;
    bool fail = false, migrationFail = false;
    final calls = <String>[];
    setUp(() {
      raw = null;
      previous = null;
      imported = null;
      fail = false;
      migrationFail = false;
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidStore.channel, (call) async {
            calls.add(call.method);
            switch (call.method) {
              case 'read':
                return raw;
              case 'previous':
                return previous;
              case 'mediaRoot':
                return '/private/photos';
              case 'preserveMigration':
                if (migrationFail) {
                  throw PlatformException(code: 'DISK');
                }
                return null;
              case 'validatePhotos':
                return null;
              case 'import':
                return imported;
              case 'photo':
                return '11111111-1111-1111-1111-111111111111.jpg';
              case 'write':
                if (fail) {
                  throw PlatformException(code: 'DISK');
                }
                final args = call.arguments as Map;
                if (args['preserve'] == true) previous = raw;
                raw = args['json'] as String;
                return null;
              default:
                return null;
            }
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidStore.channel, null),
    );
    test(
      'Migration preserves original before writing; backup failure locks data',
      () async {
        raw = legacy;
        final c = CoffeeController(AndroidStore());
        await c.load();
        expect(c.locked, false);
        expect(jsonDecode(raw!)['schema'], 2);
        expect(
          calls.indexOf('preserveMigration'),
          lessThan(calls.indexOf('write')),
        );
        raw = legacy;
        migrationFail = true;
        calls.clear();
        await c.load();
        expect(c.locked, true);
        expect(raw, legacy);
        expect(calls, isNot(contains('write')));
      },
    );
    test(
      'Photo replacement, restart and undo preserve original references',
      () async {
        final c = CoffeeController(AndroidStore());
        await c.load();
        final photo = await c.pickPhoto();
        final bean = Bean(id: 'b', name: 'A', photo: photo!);
        await c.saveBean(bean);
        final old = raw;
        final restarted = CoffeeController(AndroidStore());
        await restarted.load();
        expect(restarted.data.beans.single.photo, photo);
        await restarted.restore(CoffeeData.example(DateTime.now()));
        expect(previous, old);
        expect(restarted.canUndo, true);
        expect(await restarted.undoRestore(), true);
        expect(restarted.data.beans.single.photo, photo);
        expect(raw, old);
      },
    );
    test('Old JSON restore is staged until confirmation; invalid imports never write', () async {
      final c = CoffeeController(AndroidStore());
      await c.load();
      await c.saveBean(const Bean(id: 'b', name: 'Current'));
      final before = raw;
      imported = legacy;
      final candidate = await c.prepareImport();
      expect(raw, before);
      expect(candidate!.demo, true);
      imported = legacy.replaceFirst('"schema": 1', '"schema": 999');
      expect(await c.prepareImport(), null);
      expect(raw, before);
      fail = true;
      expect(await c.restore(candidate), false);
      expect(raw, before);
    });
  });

  testWidgets(
    'Reused form consumes nothing before save and Back retains long feelings',
    (t) async {
      final c = await ready();
      const b = Bean(id: 'b', name: 'A');
      await c.saveBean(b);
      final old = cup('old');
      await c.saveCup(old);
      await t.pumpWidget(
        MaterialApp(
          theme: coffeeTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => editCup(context, c, bean: b, reuse: old),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(c.data.cups.length, 1);
      expect(c.data.remaining(b), 234.5);
      expect(find.widgetWithText(TextFormField, '15.5'), findsOneWidget);
      final feeling = '花香和甜感。' * 200;
      await t.enterText(find.byType(TextFormField).at(3), feeling);
      await t.tap(find.byTooltip('返回'));
      await t.pumpAndSettle();
      expect(find.text('放弃这次编辑？'), findsOneWidget);
      await t.tap(find.text('取消'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, feeling), findsOneWidget);
      expect(c.data.cups.length, 1);
      await t.tap(find.byTooltip('返回'));
      await t.pumpAndSettle();
      await t.tap(find.text('放弃编辑'));
      await t.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
    },
  );
  testWidgets('A new cup after stock correction saves in one step', (t) async {
    final c = await ready();
    const b = Bean(id: 'b', name: 'A');
    await c.saveBean(b);
    await c.adjustStock(b, 2000, '调磨损耗');
    await t.pumpWidget(
      MaterialApp(
        theme: coffeeTheme(Brightness.light),
        home: CupEditor(controller: c, bean: b),
      ),
    );
    final fields = find.byType(TextFormField);
    await t.enterText(fields.at(0), '15.5');
    await t.enterText(fields.at(1), '240');
    await t.enterText(fields.at(2), '145');
    await t.tap(find.text('保存这杯的记忆'));
    await t.pumpAndSettle();
    expect(find.text('核对校正后的余量'), findsNothing);
    expect(c.data.cups.length, 1);
    expect(c.data.remainingTenths(b), 1845);
  });
  for (final theme in ['light', 'dark']) {
    testWidgets(
      '320px, 2x text: long names/feelings, zero stock and optional fields in $theme',
      (t) async {
        t.view.physicalSize = const Size(320, 900);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final c = await ready(
          MemoryStore(
            CoffeeData(
              onboarded: true,
              theme: theme,
              beans: [
                Bean(
                  id: 'b',
                  name: 'LongCoffeeBeanName不间断长名称' * 3,
                  roaster: 'LongRoaster烘焙商' * 4,
                ),
              ],
              cups: [
                Cup(
                  id: 'c',
                  name: 'Coffee',
                  at: DateTime.now(),
                  beanId: 'b',
                  grams: 250,
                  note: '长感受。' * 300,
                ),
              ],
            ).encode(),
          ),
        );
        await t.pumpWidget(CoffeeApp(controller: c));
        await t.pumpAndSettle();
        await t.tap(find.text('已喝完'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.pumpWidget(
          MaterialApp(
            theme: coffeeTheme(
              theme == 'dark' ? Brightness.dark : Brightness.light,
            ),
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: BeanDetail(controller: c, id: 'b'),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.pumpWidget(
          MaterialApp(
            theme: coffeeTheme(
              theme == 'dark' ? Brightness.dark : Brightness.light,
            ),
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: CupEditor(controller: c, bean: c.data.beans.single),
          ),
        );
        await t.pumpAndSettle();
        await t.scrollUntilVisible(
          find.text('更多参数（选填）'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await t.tap(find.text('更多参数（选填）'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.scrollUntilVisible(
          find.text('研磨刻度（原文，如 22 clicks）'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      },
    );
  }
}

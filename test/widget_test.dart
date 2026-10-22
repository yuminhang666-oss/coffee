import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_journal/main.dart';
import 'package:coffee_journal/core/controller.dart';
import 'package:coffee_journal/core/models.dart';
import 'package:coffee_journal/ui/editors.dart';

class MemoryStore implements CoffeeStore {
  String? raw;
  String? previous;
  bool fail = false;
  final writes = <String>[];
  MemoryStore([this.raw]);
  @override
  Future<String?> read() async => raw;
  @override
  Future<void> write(String json, {bool preserve = false}) async {
    await Future<void>.value();
    if (fail) throw StateError('disk unavailable');
    if (preserve) previous = raw;
    raw = json;
    writes.add(json);
  }
}

Future<CoffeeController> ready([MemoryStore? store]) async {
  final c = CoffeeController(store ?? MemoryStore());
  await c.load();
  return c;
}

Cup cup(String id, {double grams = 15.5, String beanId = 'b'}) => Cup(
  id: id,
  name: 'Test coffee',
  at: DateTime(2026, 10, 21),
  beanId: beanId,
  grams: grams,
  water: 240,
  seconds: 150,
  note: 'Sweet and floral',
);

void main() {
  test('Examples require an explicit choice and survive JSON round trip', () {
    const fresh = CoffeeData();
    expect(fresh.demo, false);
    expect(fresh.beans, isEmpty);
    expect(fresh.onboarded, false);
    final d = CoffeeData.decode(
      CoffeeData.example(DateTime(2026, 10, 21)).encode(),
    );
    expect(d.demo, true);
    expect(d.beans.length, 2);
    expect(d.cups.length, 3);
    expect(d.remaining(d.beans.first), 235);
  });
  test(
    'Adding, editing and deleting cups adjust inventory without rounding drift',
    () async {
      final c = await ready();
      await c.saveBean(const Bean(id: 'b', name: 'Bag', weight: 100));
      expect(await c.saveCup(cup('c')), true);
      expect(c.data.remaining(c.data.beans.first), 84.5);
      await c.saveCup(cup('c', grams: 12.3));
      expect(c.data.remaining(c.data.beans.first), 87.7);
      await c.removeCup('c');
      expect(c.data.remaining(c.data.beans.first), 100);
    },
  );
  test('Moving a record to another bean returns original stock', () async {
    final c = await ready();
    await c.saveBean(const Bean(id: 'b', name: 'A'));
    await c.saveBean(const Bean(id: 'b2', name: 'B'));
    await c.saveCup(cup('c'));
    await c.saveCup(cup('c', beanId: 'b2'));
    expect(c.data.used('b'), 0);
    expect(c.data.used('b2'), 15.5);
  });
  test(
    'Deleting a bean retains tasting notes and detaches its records',
    () async {
      final c = await ready();
      await c.saveBean(const Bean(id: 'b', name: 'A'));
      await c.saveCup(cup('c'));
      await c.removeBean('b');
      expect(c.data.beans, isEmpty);
      expect(c.data.cups.single.note, 'Sweet and floral');
      expect(c.data.cups.single.beanId, '');
    },
  );
  test('Over-consumption and reducing bag weight below consumption cannot overwrite data', () async {
    final c = await ready();
    await c.saveBean(const Bean(id: 'b', name: 'Bag', weight: 20));
    await c.saveCup(cup('c'));
    expect(await c.saveCup(cup('too-much')), false);
    expect(c.data.cups.length, 1);
    expect(
      await c.saveBean(const Bean(id: 'b', name: 'Bag', weight: 10)),
      false,
    );
    expect(c.data.beans.single.weight, 20);
  });
  test(
    'Write failure leaves memory and persisted state unchanged; retry succeeds',
    () async {
      final store = MemoryStore();
      final c = await ready(store);
      store.fail = true;
      expect(await c.saveBean(const Bean(id: 'b', name: 'Bag')), false);
      expect(c.data.beans, isEmpty);
      expect(store.raw, isNull);
      store.fail = false;
      expect(await c.saveBean(const Bean(id: 'b', name: 'Bag')), true);
      expect(c.error, isNull);
    },
  );
  test(
    'Concurrent mutations are queued against the latest durable snapshot',
    () async {
      final store = MemoryStore();
      final c = await ready(store);
      await Future.wait([
        c.saveBean(const Bean(id: 'b', name: 'A')),
        c.saveBean(const Bean(id: 'b2', name: 'B')),
        c.change((d) => d.copy(theme: 'dark')),
      ]);
      final loaded = CoffeeData.decode(store.raw!);
      expect(loaded.beans.length, 2);
      expect(loaded.theme, 'dark');
      expect(store.writes.length, 3);
    },
  );
  test(
    'Unreadable data locks editing and preserves the original file',
    () async {
      final store = MemoryStore('{broken');
      final c = await ready(store);
      expect(c.locked, true);
      expect(await c.saveBean(const Bean(id: 'b', name: 'A')), false);
      expect(store.raw, '{broken');
      store.raw = const CoffeeData().encode();
      await c.load();
      expect(c.locked, false);
    },
  );
  test(
    'Restore preserves previous data and requires supported schema',
    () async {
      final store = MemoryStore();
      final c = await ready(store);
      await c.saveBean(const Bean(id: 'old', name: 'Old'));
      final old = store.raw;
      expect(await c.restore(CoffeeData.example(DateTime(2026, 10, 21))), true);
      expect(store.previous, old);
      expect(c.data.demo, true);
      expect(
        () => CoffeeData.decode(
          c.data.encode().replaceFirst('"schema": 2', '"schema": 99'),
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'Backup validation rejects duplicate IDs, orphan links and invalid dates',
    () {
      final valid = CoffeeData(
        beans: const [Bean(id: 'b', name: 'Bag')],
        cups: [cup('c')],
      );
      expect(
        () =>
            CoffeeData.decode(valid.copy(cups: [cup('c'), cup('c')]).encode()),
        throwsFormatException,
      );
      expect(
        () => CoffeeData.decode(valid.copy(beans: []).encode()),
        throwsFormatException,
      );
      expect(
        () => CoffeeData.decode(
          valid.encode().replaceFirst('2026-10-21', '2026-02-31'),
        ),
        throwsFormatException,
      );
      expect(
        () => CoffeeData.decode(valid.encode().replaceFirst('155', '155.5')),
        throwsFormatException,
      );
    },
  );
  test('Decimal grams are exact to tenths over many records', () {
    final d = CoffeeData(
      beans: const [Bean(id: 'b', name: 'Bag', weight: 50)],
      cups: List.generate(100, (i) => cup('$i', grams: .1)),
    );
    expect(d.used('b'), 10);
    expect(CoffeeData.decode(d.encode()).remaining(d.beans.single), 40);
  });
  test('Money uses exact integer cents and rejects malformed values', () {
    expect(parseMoney('28.90'), 2890);
    expect(parseMoney('0.01'), 1);
    expect(parseMoney(''), 0);
    expect(parseMoney('-2'), isNull);
    expect(parseMoney('1.234'), isNull);
    expect(parseMoney('NaN'), isNull);
  });
  testWidgets('First launch is empty and starts on the bean pantry', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = await ready();
    await t.pumpWidget(CoffeeApp(controller: c));
    await t.pumpAndSettle();
    expect(find.text('开启我的豆仓'), findsOneWidget);
    expect(c.data.demo, false);
    await t.ensureVisible(find.text('开启我的豆仓'));
    await t.tap(find.text('开启我的豆仓'));
    await t.pumpAndSettle();
    expect(find.text('我的豆仓'), findsOneWidget);
    expect(find.text('给下一杯，留一个位置'), findsOneWidget);
    expect(c.data.beans, isEmpty);
  });
  testWidgets(
    'Post-brew form validates required parameters and saves feelings',
    (t) async {
      final c = await ready();
      await c.saveBean(const Bean(id: 'b', name: 'Bag'));
      await t.pumpWidget(
        MaterialApp(
          home: CupEditor(controller: c, bean: c.data.beans.single),
        ),
      );
      await t.tap(find.text('保存这杯的记忆'));
      await t.pumpAndSettle();
      expect(find.text('填 0.1–1000'), findsOneWidget);
      final fields = find.byType(TextFormField);
      await t.enterText(fields.at(0), '15.5');
      await t.enterText(fields.at(1), '240');
      await t.enterText(fields.at(2), '145');
      await t.enterText(fields.at(3), 'A bright and sweet cup');
      await t.tap(find.text('保存这杯的记忆'));
      await t.pumpAndSettle();
      expect(c.data.cups.single.grams, 15.5);
      expect(c.data.cups.single.note, 'A bright and sweet cup');
      expect(c.data.remaining(c.data.beans.single), 234.5);
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Pantry, journal, insights and editor fit 320px at text scale $scale',
      (t) async {
        t.view.physicalSize = const Size(320, 900);
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final c = await ready(
          MemoryStore(CoffeeData.example(DateTime.now()).encode()),
        );
        await t.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: CoffeeApp(controller: c),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        for (final label in ['手记', '回味']) {
          await t.tap(find.text(label).last);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        await t.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: CupEditor(controller: c, bean: c.data.beans.first),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      },
    );
  }
}

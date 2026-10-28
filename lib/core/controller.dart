import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dart:convert';

import 'models.dart';

String _validatedSnapshot(CoffeeData data) {
  for (final value in [
    ...data.beans.map((b) => b.weight),
    ...data.cups.map((c) => c.grams),
    ...data.cups.map((c) => c.water),
  ]) {
    if (!value.isFinite || (value * 10 - (value * 10).round()).abs() > .00001) {
      throw const FormatException('克数必须保留最多一位小数');
    }
  }
  final json = data.encode();
  CoffeeData.decode(json);
  return json;
}

abstract class CoffeeStore {
  Future<String?> read();
  Future<void> write(String json, {bool preserve = false});
}

class AndroidStore implements CoffeeStore {
  static const channel = MethodChannel('coffee_journal/storage');
  @override
  Future<String?> read() => channel.invokeMethod<String>('read');
  @override
  Future<void> write(String json, {bool preserve = false}) async {
    await channel.invokeMethod<void>('write', {
      'json': json,
      'preserve': preserve,
    });
  }

  Future<bool> export(String json) async =>
      await channel.invokeMethod<bool>('export', json) ?? false;
  Future<String?> importFile() => channel.invokeMethod<String>('import');
  Future<String?> previous() => channel.invokeMethod<String>('previous');
  Future<String> mediaRoot() async =>
      (await channel.invokeMethod<String>('mediaRoot'))!;
  Future<String?> pickPhoto() => channel.invokeMethod<String>('photo');
  Future<void> preserveMigration() =>
      channel.invokeMethod<void>('preserveMigration');
  Future<void> validatePhotos(String json) =>
      channel.invokeMethod<void>('validatePhotos', json);
}

class CoffeeController extends ChangeNotifier {
  final CoffeeStore store;
  CoffeeData data = const CoffeeData();
  bool loading = true, locked = false, busy = false;
  String? error;
  String? mediaDirectory;
  bool canUndo = false;
  Future<void> _queue = Future.value();
  CoffeeController(this.store);
  Future<void> load() {
    final result = _queue.then((_) => _load());
    _queue = result;
    return result;
  }

  Future<void> _load() async {
    loading = true;
    notifyListeners();
    try {
      final raw = await store.read();
      final loaded = raw == null
          ? const CoffeeData()
          : raw.length > 100000
          ? await compute(CoffeeData.decode, raw)
          : CoffeeData.decode(raw);
      if (store case final AndroidStore android) {
        mediaDirectory = await android.mediaRoot();
        if (raw != null) {
          await android.validatePhotos(loaded.encode());
          if ((jsonDecode(raw) as Map)['schema'] != 3) {
            await android.preserveMigration();
            await android.write(loaded.encode());
          }
        }
        canUndo = await android.previous() != null;
      }
      data = loaded;
      locked = false;
      error = null;
    } catch (_) {
      locked = true;
      error = '无法读取本机记录。原文件已保留，请重试。';
    }
    loading = false;
    notifyListeners();
  }

  Future<bool> change(
    CoffeeData Function(CoffeeData) update, {
    bool preserve = false,
  }) => _enqueue(() async {
    final next = update(data);
    final json =
        next.beans.length + next.cups.length + next.adjustments.length > 200
        ? await compute(_validatedSnapshot, next)
        : _validatedSnapshot(next);
    if (store case final AndroidStore android) {
      await android.validatePhotos(json);
    }
    await store.write(json, preserve: preserve);
    data = next;
    if (preserve && store is AndroidStore) canUndo = true;
  });

  Future<bool> _enqueue(Future<void> Function() operation) {
    final result = _queue.then((_) async {
      if (locked) return false;
      busy = true;
      notifyListeners();
      try {
        await operation();
        error = null;
        return true;
      } catch (e) {
        error = e is FormatException
            ? e.message
            : e is PlatformException
            ? '${e.message ?? '本机操作失败'}。当前豆仓已保留，请核对后重试。'
            : '未能保存，请重试。刚才的操作没有覆盖已存记录。';
        return false;
      } finally {
        busy = false;
        notifyListeners();
      }
    });
    _queue = result.then((_) {});
    return result;
  }

  Future<bool> saveCup(Cup cup) => change(
    (d) => d.copy(cups: [cup, ...d.cups.where((x) => x.id != cup.id)]),
  );
  Future<bool> saveFlavor(FlavorTerm term) => change(
    (d) => d.copy(
      customFlavors: [term, ...d.customFlavors.where((t) => t.id != term.id)],
    ),
  );
  Future<bool> removeCup(String id) =>
      change((d) => d.copy(cups: d.cups.where((x) => x.id != id).toList()));
  Future<bool> saveBean(Bean bean) => change(
    (d) => d.copy(beans: [bean, ...d.beans.where((x) => x.id != bean.id)]),
  );
  Future<bool> removeBean(String id) => change(
    (d) => d.copy(
      beans: d.beans.where((x) => x.id != id).toList(),
      adjustments: d.adjustments
          .map(
            (a) => a.beanId == id
                ? StockAdjustment.fromJson({
                    ...a.toJson(),
                    'beanId': '',
                    'beanName': d.beans.firstWhere((b) => b.id == id).name,
                  })
                : a,
          )
          .toList(),
      cups: d.cups
          .map(
            (c) => c.beanId == id
                ? Cup.fromJson({...c.toJson(), 'beanId': ''})
                : c,
          )
          .toList(),
    ),
  );
  Future<bool> restore(CoffeeData candidate) =>
      change((_) => candidate.copy(onboarded: true), preserve: true);
  Future<bool> adjustStock(Bean bean, int after, String reason) => change((d) {
    final current = d.beans.firstWhere((b) => b.id == bean.id);
    return d.copy(
      adjustments: [
        ...d.adjustments,
        StockAdjustment(
          id: newId(),
          beanId: bean.id,
          at: DateTime.now(),
          before: d.remainingTenths(current),
          after: after,
          reason: reason,
          beanName: current.name,
        ),
      ],
    );
  });
  String stockImpact(CoffeeData next, Set<String> ids) {
    final affected = data.beans.where(
      (b) =>
          ids.contains(b.id) && data.adjustments.any((a) => a.beanId == b.id),
    );
    if (affected.isEmpty) return '';
    return '\n已有库存校正，历史修改会重新计算：\n${affected.map((b) => '${b.name}：${gramsText(data.remaining(b))} → ${gramsText(next.remaining(b))} g（有效范围 0–${gramsText(b.weight)} g）').join('\n')}\n校正记录保持不变；如结果越界，请先校正余量或取消本次修改。';
  }

  // Media mutations and restore preparation share the business queue.
  Future<String?> pickPhoto() async {
    String? photo;
    final ok = await _enqueue(() async {
      if (store case final AndroidStore android) {
        photo = await android.pickPhoto();
      }
    });
    return ok ? photo : null;
  }

  Future<bool> exportBackup() async {
    var exported = false;
    await _enqueue(() async {
      if (store case final AndroidStore android) {
        exported = await android.export(data.encode());
      }
    });
    return exported;
  }

  Future<CoffeeData?> prepareImport() async {
    CoffeeData? candidate;
    final ok = await _enqueue(() async {
      if (store case final AndroidStore android) {
        final raw = await android.importFile();
        if (raw != null) {
          candidate = await compute(CoffeeData.decode, raw);
          await android.validatePhotos(candidate!.encode());
        }
      }
    });
    return ok ? candidate : null;
  }

  Future<bool> undoRestore() => _enqueue(() async {
    if (store case final AndroidStore android) {
      final previous = await android.previous();
      if (previous == null) throw const FormatException('没有可撤销的恢复');
      final candidate = CoffeeData.decode(previous);
      await android.validatePhotos(candidate.encode());
      await android.write(candidate.encode());
      data = candidate;
    }
  });
}

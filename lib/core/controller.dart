import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';

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
}

class CoffeeController extends ChangeNotifier {
  final CoffeeStore store;
  CoffeeData data = const CoffeeData();
  bool loading = true, locked = false, busy = false;
  String? error;
  Future<void> _queue = Future.value();
  CoffeeController(this.store);
  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      final raw = await store.read();
      data = raw == null ? const CoffeeData() : CoffeeData.decode(raw);
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
  }) {
    final result = _queue.then((_) async {
      if (locked) return false;
      busy = true;
      notifyListeners();
      try {
        final next = update(data);
        CoffeeData.decode(next.encode());
        await store.write(next.encode(), preserve: preserve);
        data = next;
        error = null;
        return true;
      } catch (_) {
        error = '未能保存，请重试。刚才的操作没有覆盖已存记录。';
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
  Future<bool> removeCup(String id) =>
      change((d) => d.copy(cups: d.cups.where((x) => x.id != id).toList()));
  Future<bool> saveBean(Bean bean) => change(
    (d) => d.copy(beans: [bean, ...d.beans.where((x) => x.id != bean.id)]),
  );
  Future<bool> removeBean(String id) => change(
    (d) => d.copy(
      beans: d.beans.where((x) => x.id != id).toList(),
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
}

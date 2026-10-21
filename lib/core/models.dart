import 'dart:convert';

String newId() => DateTime.now().microsecondsSinceEpoch.toString();
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
const methods = ['手冲', '拿铁', '美式', '浓缩', '冷萃', '其他'];
const flavors = ['柑橘', '花香', '莓果', '坚果', '可可', '焦糖', '茶感', '奶油'];
String str(
  Map<String, dynamic> m,
  String k, {
  String fallback = '',
  int max = 2000,
}) {
  final v = m[k] ?? fallback;
  if (v is! String || v.length > max) throw const FormatException('文字字段无效');
  return v;
}

int integer(
  Map<String, dynamic> m,
  String k,
  int min,
  int max, [
  int? fallback,
]) {
  final v = m[k] ?? fallback;
  if (v is! int || v < min || v > max) throw const FormatException('数字字段无效');
  return v;
}

double decimal(Map<String, dynamic> m, String k, double min, double max) {
  final v = m[k];
  if (v is! num ||
      !v.isFinite ||
      v < min ||
      v > max ||
      (v * 10 - (v * 10).round()).abs() > .00001) {
    throw const FormatException('克数字段无效');
  }
  return v.toDouble();
}

DateTime date(Map<String, dynamic> m, String k) {
  final s = str(m, k);
  final d = DateTime.tryParse(s);
  if (d == null || !s.startsWith(dayKey(d)) || d.year < 2000 || d.year > 2100) {
    throw const FormatException('日期无效');
  }
  return d;
}

bool boolean(Map<String, dynamic> m, String k, [bool fallback = false]) {
  final v = m[k] ?? fallback;
  if (v is! bool) throw const FormatException('布尔字段无效');
  return v;
}

class Cup {
  final String id, name, method, shop, note, beanId;
  final DateTime at;
  final int cents, rating, water, seconds;
  final double grams;
  final bool favorite;
  final List<String> tastes;
  const Cup({
    required this.id,
    required this.name,
    required this.at,
    this.method = '手冲',
    this.shop = '',
    this.note = '',
    this.beanId = '',
    this.cents = 0,
    this.rating = 0,
    this.grams = 0,
    this.water = 0,
    this.seconds = 0,
    this.favorite = false,
    this.tastes = const [],
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'at': at.toIso8601String(),
    'method': method,
    'shop': shop,
    'note': note,
    'beanId': beanId,
    'cents': cents,
    'rating': rating,
    'grams': grams,
    'water': water,
    'seconds': seconds,
    'favorite': favorite,
    'tastes': tastes,
  };
  factory Cup.fromJson(Map<String, dynamic> m) {
    final name = str(m, 'name', max: 80).trim();
    final id = str(m, 'id', max: 100);
    final method = str(m, 'method');
    final ts = m['tastes'];
    if (name.isEmpty ||
        id.isEmpty ||
        !methods.contains(method) ||
        ts is! List ||
        ts.length > 8 ||
        ts.any((t) => !flavors.contains(t))) {
      throw const FormatException('咖啡记录无效');
    }
    return Cup(
      id: id,
      name: name,
      at: date(m, 'at'),
      method: method,
      shop: str(m, 'shop', max: 80),
      note: str(m, 'note'),
      beanId: str(m, 'beanId', max: 100),
      cents: integer(m, 'cents', 0, 10000000),
      rating: integer(m, 'rating', 0, 5),
      grams: decimal(m, 'grams', 0, 1000),
      water: integer(m, 'water', 0, 30000, 0),
      seconds: integer(m, 'seconds', 0, 86400, 0),
      favorite: boolean(m, 'favorite'),
      tastes: ts.cast<String>().toList(),
    );
  }
  Cup liked() => Cup.fromJson({...toJson(), 'favorite': !favorite});
}

class Bean {
  final String id, name, origin, roast, process, note, roaster;
  final int weight, cents;
  final DateTime? boughtAt, roastedAt;
  const Bean({
    required this.id,
    required this.name,
    this.origin = '',
    this.roast = '浅烘',
    this.process = '',
    this.note = '',
    this.roaster = '',
    this.weight = 250,
    this.cents = 0,
    this.boughtAt,
    this.roastedAt,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'origin': origin,
    'roast': roast,
    'process': process,
    'note': note,
    'roaster': roaster,
    'weight': weight,
    'cents': cents,
    'boughtAt': boughtAt?.toIso8601String(),
    'roastedAt': roastedAt?.toIso8601String(),
  };
  factory Bean.fromJson(Map<String, dynamic> m) {
    final b = Bean(
      id: str(m, 'id', max: 100),
      name: str(m, 'name', max: 80).trim(),
      origin: str(m, 'origin', max: 80),
      roast: str(m, 'roast'),
      process: str(m, 'process', max: 80),
      note: str(m, 'note'),
      roaster: str(m, 'roaster', max: 80),
      weight: integer(m, 'weight', 1, 50000),
      cents: integer(m, 'cents', 0, 10000000),
      boughtAt: m['boughtAt'] == null ? null : date(m, 'boughtAt'),
      roastedAt: m['roastedAt'] == null ? null : date(m, 'roastedAt'),
    );
    if (b.id.isEmpty ||
        b.name.isEmpty ||
        !['浅烘', '中烘', '深烘'].contains(b.roast)) {
      throw const FormatException('豆单无效');
    }
    return b;
  }
}

class CoffeeData {
  final List<Cup> cups;
  final List<Bean> beans;
  final bool onboarded, demo;
  final String theme;
  const CoffeeData({
    this.cups = const [],
    this.beans = const [],
    this.onboarded = false,
    this.demo = false,
    this.theme = 'system',
  });
  CoffeeData copy({
    List<Cup>? cups,
    List<Bean>? beans,
    bool? onboarded,
    bool? demo,
    String? theme,
  }) => CoffeeData(
    cups: cups ?? this.cups,
    beans: beans ?? this.beans,
    onboarded: onboarded ?? this.onboarded,
    demo: demo ?? this.demo,
    theme: theme ?? this.theme,
  );
  double used(String id) =>
      cups
          .where((c) => c.beanId == id)
          .fold<int>(0, (s, c) => s + (c.grams * 10).round()) /
      10;
  double remaining(Bean bean) =>
      (bean.weight * 10 - (used(bean.id) * 10).round()) / 10;
  Map<String, dynamic> toJson({bool backup = false}) => {
    'app': 'coffee-journal',
    'schema': 1,
    'cups': cups.map((x) => x.toJson()).toList(),
    'beans': beans.map((x) => x.toJson()).toList(),
    'onboarded': onboarded,
    'demo': demo,
    'theme': theme,
  };
  String encode({bool backup = false}) =>
      const JsonEncoder.withIndent('  ').convert(toJson(backup: backup));
  factory CoffeeData.decode(String raw) {
    if (utf8.encode(raw).length > 5000000) {
      throw const FormatException('备份超过 5 MB');
    }
    final m = jsonDecode(raw);
    if (m is! Map<String, dynamic> ||
        m['app'] != 'coffee-journal' ||
        m['schema'] != 1 ||
        m['cups'] is! List ||
        m['beans'] is! List) {
      throw const FormatException('不是受支持的咖啡手记备份');
    }
    if ((m['cups'] as List).length > 10000 ||
        (m['beans'] as List).length > 2000) {
      throw const FormatException('记录过多');
    }
    final cups = (m['cups'] as List)
        .map((e) => Cup.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final beans = (m['beans'] as List)
        .map((e) => Bean.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (cups.map((e) => e.id).toSet().length != cups.length ||
        beans.map((e) => e.id).toSet().length != beans.length) {
      throw const FormatException('备份中有重复 ID');
    }
    final theme = str(m, 'theme');
    if (!['system', 'light', 'dark'].contains(theme)) {
      throw const FormatException('外观设置无效');
    }
    if (cups.any(
      (c) => c.beanId.isNotEmpty && !beans.any((b) => b.id == c.beanId),
    )) {
      throw const FormatException('记录关联的咖啡豆缺失');
    }
    final result = CoffeeData(
      cups: cups,
      beans: beans,
      onboarded: boolean(m, 'onboarded'),
      demo: boolean(m, 'demo'),
      theme: theme,
    );
    if (beans.any((b) => result.remaining(b) < 0)) {
      throw const FormatException('用豆量超过购入克数');
    }
    return result;
  }
  factory CoffeeData.example(DateTime now) => CoffeeData(
    onboarded: true,
    demo: true,
    beans: [
      Bean(
        id: 'demo-b1',
        name: '耶加雪菲 · 花见',
        origin: '埃塞俄比亚',
        roast: '浅烘',
        process: '水洗',
        roaster: '晨间烘焙（示例）',
        cents: 8800,
        boughtAt: now,
        roastedAt: DateTime(now.year, now.month, now.day - 5),
        note: '示例豆单，可在正式空间记录自己的豆子。',
      ),
      Bean(
        id: 'demo-b2',
        name: '山野拼配',
        origin: '巴西 / 哥伦比亚',
        roast: '中烘',
        process: '日晒',
        roaster: '山野烘焙（示例）',
        cents: 6800,
        boughtAt: now,
      ),
    ],
    cups: [
      Cup(
        id: 'demo-c1',
        name: '一杯花香，慢慢醒来',
        at: now,
        method: '手冲',
        beanId: 'demo-b1',
        shop: '在家冲煮',
        rating: 5,
        tastes: ['花香', '柑橘', '茶感'],
        favorite: true,
        grams: 15,
        water: 225,
        seconds: 150,
        note: '示例记录：轻盈的柑橘酸，放凉后有淡淡的茉莉花香。',
      ),
      Cup(
        id: 'demo-c2',
        name: '午后，给自己留一杯',
        at: now.subtract(const Duration(days: 1)),
        method: '手冲',
        shop: '在家冲煮',
        beanId: 'demo-b2',
        grams: 18,
        water: 270,
        seconds: 165,
        note: '示例记录：坚果和奶油的香气，口感圆润。',
        rating: 4,
        tastes: ['坚果', '奶油'],
      ),
      Cup(
        id: 'demo-c3',
        name: '留一点可可的余韵',
        at: now.subtract(const Duration(days: 3)),
        method: '手冲',
        shop: '在家冲煮',
        beanId: 'demo-b2',
        grams: 15,
        water: 225,
        seconds: 140,
        note: '示例记录：可可香气明显，下次试试再细一点的研磨。',
        rating: 4,
        tastes: ['可可', '焦糖'],
      ),
    ],
  );
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/controller.dart';
import '../core/models.dart';
import 'design.dart';
import 'flavor_picker.dart';

Future<bool> confirm(
  BuildContext context,
  String title,
  String body, {
  String action = '确认',
  bool destructive = false,
}) async =>
    await showCupertinoDialog<bool>(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: destructive,
            onPressed: () => Navigator.pop(c, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
Future<bool?> editBean(
  BuildContext c,
  CoffeeController controller, {
  Bean? bean,
}) => Navigator.of(c).push<bool>(
  CoffeeRoute(
    context: c,
    builder: (_) => BeanEditor(controller: controller, bean: bean),
  ),
);
Future<bool?> editCup(
  BuildContext c,
  CoffeeController controller, {
  Cup? cup,
  Bean? bean,
  Cup? reuse,
}) => Navigator.of(c).push<bool>(
  CoffeeRoute(
    context: c,
    builder: (_) =>
        CupEditor(controller: controller, cup: cup, bean: bean, reuse: reuse),
  ),
);
InputDecoration fieldLabel(String s) =>
    InputDecoration(labelText: s, counterText: '', errorMaxLines: 3);
Widget spaceTitle(CoffeeController controller, String title) => Text(
  '$title${controller.data.demo ? ' · 示例' : ''}',
  style: const TextStyle(fontSize: 18),
);
int? parseMoney(String s) {
  if (s.trim().isEmpty) return 0;
  if (!RegExp(r'^\d{1,6}(\.\d{1,2})?$').hasMatch(s.trim())) return null;
  final parts = s.trim().split('.');
  final v =
      int.parse(parts[0]) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  return v <= 10000000 ? v : null;
}

class CupEditor extends StatefulWidget {
  final CoffeeController controller;
  final Cup? cup;
  final Bean? bean;
  final Cup? reuse;
  const CupEditor({
    super.key,
    required this.controller,
    this.cup,
    this.bean,
    this.reuse,
  });
  @override
  State<CupEditor> createState() => _CupEditorState();
}

class _CupEditorState extends State<CupEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name,
      grams,
      water,
      seconds,
      minutes,
      note,
      shop,
      price;
  late final TextEditingController temperature, brewer, grinder, grind;
  late String initialDraft;
  bool allowPop = false;
  late String beanId, method;
  late DateTime at;
  late int rating;
  late Map<String, String> tastes;
  bool saving = false;
  final recordId = newId();
  bool reviewing = false;
  @override
  void initState() {
    super.initState();
    final c =
        widget.cup ??
        (widget.reuse != null && widget.bean != null
            ? widget.reuse!.parametersFor(widget.bean!, DateTime.now())
            : null);
    name = TextEditingController(text: c?.name ?? '');
    grams = TextEditingController(text: c == null ? '' : gramsText(c.grams));
    water = TextEditingController(text: c == null ? '' : gramsText(c.water));
    minutes = TextEditingController(
      text: c == null ? '' : (c.seconds ~/ 60).toString(),
    );
    seconds = TextEditingController(
      text: c == null ? '' : (c.seconds % 60).toString(),
    );
    note = TextEditingController(text: c?.note ?? '');
    shop = TextEditingController(text: c?.shop ?? '');
    price = TextEditingController(
      text: c == null || c.cents == 0 ? '' : money(c.cents),
    );
    beanId = c?.beanId ?? widget.bean?.id ?? '';
    method = c?.method ?? '手冲';
    at = c?.at ?? DateTime.now();
    rating = c?.rating ?? 0;
    tastes = {
      if (c != null)
        for (var i = 0; i < c.tastes.length; i++)
          c.resolvedTasteIds[i]: c.tastes[i],
    };
    temperature = TextEditingController(text: c?.temperature?.toString() ?? '');
    brewer = TextEditingController(text: c?.brewer ?? '');
    grinder = TextEditingController(text: c?.grinder ?? '');
    grind = TextEditingController(text: c?.grind ?? '');
    initialDraft = draft;
  }

  String get draft => [
    name.text,
    grams.text,
    water.text,
    seconds.text,
    minutes.text,
    note.text,
    shop.text,
    price.text,
    temperature.text,
    brewer.text,
    grinder.text,
    grind.text,
    beanId,
    method,
    at.toIso8601String(),
    rating,
    ...tastes.entries.map((e) => '${e.key}:${e.value}'),
  ].join('|');

  Future<void> leave() async {
    if (saving) return;
    if (draft == initialDraft ||
        await confirm(
          context,
          '放弃这次编辑？',
          '个人感受和参数尚未保存。选择取消可留在这里继续编辑。',
          action: '放弃编辑',
          destructive: true,
        )) {
      if (!mounted) return;
      setState(() => allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  void dispose() {
    for (final t in [
      name,
      grams,
      water,
      seconds,
      minutes,
      note,
      shop,
      price,
      temperature,
      brewer,
      grinder,
      grind,
    ]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving || reviewing || !form.currentState!.validate()) return;
    final g = double.parse(grams.text),
        w = parseTenths(water.text, max: 300000)! / 10,
        s = parseDuration(minutes.text, seconds.text)!;
    final beans = widget.controller.data.beans.where((b) => b.id == beanId);
    final selected = beans.isEmpty ? null : beans.first;
    final available = selected == null
        ? 1000.0
        : widget.controller.data.remaining(selected) +
              (widget.cup?.beanId == beanId ? (widget.cup?.grams ?? 0) : 0);
    if (g > available + .00001) {
      message(context, '豆仓还剩 ${gramsText(available)} g，请核对用量或购入克数。');
      return;
    }
    final c = Cup(
      id: widget.cup?.id ?? recordId,
      name: selected?.name ?? name.text.trim(),
      at: at,
      method: method,
      beanId: beanId,
      grams: g,
      water: w,
      seconds: s,
      note: note.text.trim(),
      rating: rating,
      tastes: tastes.values.toList(),
      tasteIds: tastes.keys.toList(),
      shop: shop.text.trim(),
      cents: parseMoney(price.text)!,
      favorite: widget.cup?.favorite ?? false,
      temperature: int.tryParse(temperature.text),
      brewer: brewer.text.trim(),
      grinder: grinder.text.trim(),
      grind: grind.text.trim(),
    );
    final ct = widget.controller;
    final impact = widget.cup == null
        ? ''
        : ct.stockImpact(
            ct.data.copy(cups: [c, ...ct.data.cups.where((x) => x.id != c.id)]),
            {beanId, widget.cup?.beanId ?? ''},
          );
    if (impact.isNotEmpty) {
      reviewing = true;
      final accepted = await confirm(
        context,
        '核对校正后的余量',
        impact,
        action: '确认保存',
      );
      reviewing = false;
      if (!accepted) return;
    }
    if (!mounted) return;
    setState(() => saving = true);
    final ok = await widget.controller.saveCup(c);
    if (!mounted) return;
    setState(() => saving = ok);
    if (ok) {
      setState(() => allowPop = true);
      HapticFeedback.lightImpact();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } else {
      message(context, widget.controller.error!);
    }
  }

  @override
  Widget build(BuildContext c) {
    final beans = widget.controller.data.beans;
    final g = double.tryParse(grams.text) ?? 0,
        w = (parseTenths(water.text, max: 300000) ?? 0) / 10;
    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: spaceTitle(
            widget.controller,
            widget.cup == null ? '记下一杯' : '编辑手记',
          ),
          leading: IconButton(
            tooltip: '返回',
            onPressed: saving ? null : leave,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 14),
            child: FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? '正在保存…' : '保存这杯的记忆'),
            ),
          ),
        ),
        body: Form(
          key: form,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              24 + MediaQuery.viewInsetsOf(c).bottom,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              if (widget.reuse != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    '已沿用所选参数 · 日期为今天，请填写这次的感受',
                    style: TextStyle(color: muted(c), fontSize: 12),
                  ),
                ),
              DropdownButtonFormField<String>(
                key: ValueKey('$beanId-${beans.length}'),
                initialValue: beanId,
                isExpanded: true,
                decoration: fieldLabel('这次用了哪款豆子'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('不关联豆仓，手动填写')),
                  for (final b in beans)
                    DropdownMenuItem(
                      value: b.id,
                      child: Text(
                        b.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: saving
                    ? null
                    : (v) => setState(() => beanId = v ?? ''),
              ),
              if (beanId.isEmpty) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: name,
                  maxLength: 80,
                  decoration: fieldLabel('咖啡名称'),
                  validator: (v) => v!.trim().isEmpty ? '请填写名称或选择豆子' : null,
                ),
              ],
              if (beans.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final ok = await editBean(c, widget.controller);
                      if (ok == true && mounted) {
                        setState(
                          () => beanId = widget.controller.data.beans.first.id,
                        );
                      }
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('先把豆子放进豆仓'),
                  ),
                ),
              const SectionTitle('冲煮参数', aside: '冲煮后填写'),
              LayoutBuilder(
                builder: (c, box) {
                  final fields = [
                    _number(grams, '粉量 / g', decimal: true, max: 1000),
                    _number(water, '注水 / g', decimal: true, max: 30000),
                  ];
                  return box.maxWidth < 330 ||
                          MediaQuery.textScalerOf(c).scale(1) > 1.3
                      ? Column(
                          children: [
                            for (final f in fields)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: f,
                              ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < fields.length; i++) ...[
                              if (i > 0) const SizedBox(width: 10),
                              Expanded(child: fields[i]),
                            ],
                          ],
                        );
                },
              ),
              const SizedBox(height: 12),
              const Text('冲煮总时长（含滴滤）'),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: minutes,
                      keyboardType: TextInputType.number,
                      decoration: fieldLabel('分'),
                      onChanged: (_) => setState(() {}),
                      validator: (_) =>
                          durationError(minutes.text, seconds.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: seconds,
                      keyboardType: TextInputType.number,
                      decoration: fieldLabel('秒（0–59）'),
                      onChanged: (_) => setState(() {}),
                      validator: (v) =>
                          v!.trim().isEmpty ||
                              (RegExp(r'^\d+$').hasMatch(v.trim()) &&
                                  int.tryParse(v.trim()) != null &&
                                  int.parse(v.trim()) <= 59)
                          ? null
                          : '秒须为 0–59 的整数',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: temperature,
                keyboardType: TextInputType.number,
                decoration: fieldLabel('水温 / °C'),
                validator: (v) {
                  if (v!.trim().isEmpty) {
                    return widget.cup != null && widget.cup!.temperature == null
                        ? null
                        : '请填写实际水温';
                  }
                  final n = int.tryParse(v.trim());
                  return RegExp(r'^\d+$').hasMatch(v.trim()) &&
                          n != null &&
                          n >= 0 &&
                          n <= 100
                      ? null
                      : '请输入 0–100 °C 整数';
                },
              ),
              if (widget.cup != null && widget.cup!.temperature == null)
                const Text('旧记录水温未记录，可留空。', style: TextStyle(fontSize: 12)),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  g > 0 && g.isFinite && w > 0
                      ? '粉水比  1 : ${(w / g).toStringAsFixed(1)}'
                      : '填写粉量和注水量，自动计算粉水比',
                  style: TextStyle(fontSize: 12, color: muted(c)),
                ),
              ),
              const SectionTitle('这一杯，感觉如何？'),
              TextFormField(
                controller: note,
                minLines: 5,
                maxLines: 8,
                maxLength: 2000,
                decoration: const InputDecoration(
                  hintText: '比如：入口有柑橘香，凉下来更甜。\n下次想把研磨调粗一点……',
                  hintStyle: TextStyle(fontSize: 13, height: 1.8),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 18),
              Text('喜欢程度（选填）', style: TextStyle(fontSize: 13, color: muted(c))),
              const SizedBox(height: 6),
              Wrap(
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      tooltip: '$i 星',
                      onPressed: () =>
                          setState(() => rating = rating == i ? 0 : i),
                      icon: Icon(
                        i <= rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: Theme.of(c).colorScheme.primary,
                        size: 30,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final matches = widget.controller.data.beans.where(
                    (b) => b.id == beanId,
                  );
                  final bean = matches.isEmpty ? null : matches.first;
                  final result = await pickFlavors(
                    c,
                    widget.controller,
                    tastes,
                    roast: bean?.roast ?? 'light',
                    country: bean?.country ?? '',
                  );
                  if (result != null && mounted) {
                    setState(() => tastes = result);
                  }
                },
                icon: const Icon(Icons.local_florist_outlined),
                label: Text('这一杯我喝到的风味（${tastes.length}）'),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final e in tastes.entries) FlavorTag(e.value, id: e.key),
                ],
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('记录日期', style: TextStyle(fontSize: 14)),
                trailing: Text(
                  '${at.year}.${at.month}.${at.day}',
                  style: TextStyle(color: muted(c)),
                ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: c,
                    initialDate: at,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => at = d);
                },
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('更多参数（选填）', style: TextStyle(fontSize: 14)),
                childrenPadding: const EdgeInsets.only(bottom: 20),
                children: [
                  TextFormField(
                    controller: brewer,
                    maxLength: 80,
                    decoration: fieldLabel('冲煮器具（选填）'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: grinder,
                    maxLength: 80,
                    decoration: fieldLabel('磨豆机（选填）'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: grind,
                    maxLength: 80,
                    decoration: fieldLabel('研磨刻度（原文，如 22 clicks）'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField(
                    initialValue: method,
                    isExpanded: true,
                    decoration: fieldLabel('饮用方式'),
                    items: [
                      for (final m in methods)
                        DropdownMenuItem(value: m, child: Text(m)),
                    ],
                    onChanged: (v) => setState(() => method = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: shop,
                    maxLength: 80,
                    decoration: fieldLabel('地点 / 咖啡店'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: fieldLabel('本杯额外支出 / 元（不含购豆）'),
                    validator: (v) =>
                        parseMoney(v!) == null ? '请输入最多两位小数的有效金额' : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _number(
    TextEditingController controller,
    String label, {
    bool decimal = false,
    required int max,
  }) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),

    decoration: fieldLabel(label),
    onChanged: (_) => setState(() {}),
    validator: (v) {
      final n = num.tryParse(v ?? '');
      return n == null ||
              !n.isFinite ||
              n <= 0 ||
              n > max ||
              (decimal && parseTenths(v ?? '', min: 1, max: max * 10) == null)
          ? (decimal ? '填 0.1–$max，最多一位小数' : '填 1–$max')
          : null;
    },
  );
}

class BeanEditor extends StatefulWidget {
  final CoffeeController controller;
  final Bean? bean;
  const BeanEditor({super.key, required this.controller, this.bean});
  @override
  State<BeanEditor> createState() => _BeanEditorState();
}

class _BeanEditorState extends State<BeanEditor> {
  final form = GlobalKey<FormState>();
  final selectedVarieties = <String>{};
  static const varietyChoices = [
    '瑰夏',
    '波旁',
    '铁皮卡',
    '卡杜拉',
    '卡杜艾',
    'SL28',
    'SL34',
    '74110',
  ];
  late final TextEditingController name,
      origin,
      roaster,
      process,
      note,
      weight,
      price;
  late final TextEditingController country, region, farm, station, variety;
  late Map<String, String> bagFlavors;
  bool originReviewed = false;
  late String roast;
  late String photo;
  late String initialDraft;
  bool allowPop = false;
  DateTime? boughtAt, roastedAt;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final b = widget.bean;
    name = TextEditingController(text: b?.name ?? '');
    origin = TextEditingController(text: b?.origin ?? '');
    country = TextEditingController(text: b?.country ?? '');
    region = TextEditingController(text: b?.region ?? '');
    farm = TextEditingController(text: b?.farm ?? '');
    station = TextEditingController(text: b?.station ?? '');
    variety = TextEditingController();
    bagFlavors = {
      if (b != null)
        for (var i = 0; i < b.bagFlavors.length; i++)
          b.bagFlavorIds.isEmpty
                  ? builtInFlavorId(b.bagFlavors[i])
                  : b.bagFlavorIds[i]:
              b.bagFlavors[i],
    };
    selectedVarieties.addAll(b?.varieties ?? []);
    originReviewed = b?.originReviewed ?? false;
    roaster = TextEditingController(text: b?.roaster ?? '');
    process = TextEditingController(text: b?.process ?? '');
    note = TextEditingController(text: b?.note ?? '');
    weight = TextEditingController(text: (b?.weight ?? 250).toString());
    price = TextEditingController(
      text: b == null || b.cents == 0 ? '' : money(b.cents),
    );
    roast = roastId(b?.roast ?? 'light');
    boughtAt = b == null ? DateTime.now() : b.boughtAt;
    roastedAt = b?.roastedAt;
    photo = b?.photo ?? '';
    initialDraft = draft;
  }

  String get draft => [
    name.text,
    origin.text,
    country.text,
    region.text,
    farm.text,
    station.text,
    variety.text,
    ...selectedVarieties,
    ...bagFlavors.entries.map((e) => '${e.key}:${e.value}'),
    originReviewed,
    roaster.text,
    process.text,
    note.text,
    weight.text,
    price.text,
    roast,
    photo,
    boughtAt,
    roastedAt,
  ].join('|');
  Future<void> leave() async {
    if (saving) return;
    if (draft == initialDraft ||
        await confirm(
          context,
          '放弃这次编辑？',
          '豆子资料和照片更改尚未保存。选择取消可继续编辑。',
          action: '放弃编辑',
          destructive: true,
        )) {
      if (!mounted) return;
      setState(() => allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> choosePhoto() async {
    setState(() => saving = true);
    final selected = await widget.controller.pickPhoto();
    if (!mounted) return;
    setState(() {
      saving = false;
      if (selected != null) photo = selected;
    });
    if (widget.controller.error != null) {
      message(context, widget.controller.error!);
    }
  }

  @override
  void dispose() {
    for (final t in [
      name,
      origin,
      country,
      region,
      farm,
      station,
      variety,
      roaster,
      process,
      note,
      weight,
      price,
    ]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() => saving = true);
    final ok = await widget.controller.saveBean(
      Bean(
        id: widget.bean?.id ?? newId(),
        name: name.text.trim(),
        origin: widget.bean?.origin ?? '',
        country: country.text.trim(),
        region: region.text.trim(),
        farm: farm.text.trim(),
        station: station.text.trim(),
        varieties: {
          ...selectedVarieties,
          if (variety.text.trim().isNotEmpty) variety.text.trim(),
        }.toList(),
        bagFlavors: bagFlavors.values.toList(),
        bagFlavorIds: bagFlavors.keys.toList(),
        sensory:
            widget.bean?.sensory ?? const [null, null, null, null, null, null],
        originReviewed: originReviewed,
        roaster: roaster.text.trim(),
        roast: roast,
        process: process.text.trim(),
        note: note.text.trim(),
        weight: double.parse(weight.text),
        cents: parseMoney(price.text)!,
        boughtAt: boughtAt,
        roastedAt: roastedAt,
        photo: photo,
      ),
    );
    if (!mounted) return;
    setState(() => saving = ok);
    if (ok) {
      setState(() => allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } else {
      message(context, widget.controller.error!);
    }
  }

  @override
  Widget build(BuildContext c) => PopScope(
    canPop: allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: spaceTitle(
          widget.controller,
          widget.bean == null ? '收一袋好豆' : '编辑豆子',
        ),
        leading: IconButton(
          tooltip: '返回',
          onPressed: saving ? null : leave,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 14),
          child: FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? '正在保存…' : '放进我的豆仓'),
          ),
        ),
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            30 + MediaQuery.viewInsetsOf(c).bottom,
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Press(
              label: '查看豆袋大图',
              onTap: photo.isEmpty
                  ? null
                  : () => showBeanPhoto(
                      c,
                      photo,
                      widget.controller.mediaDirectory,
                    ),
              child: BeanPhoto(
                photo: photo,
                directory: widget.controller.mediaDirectory,
                height: 170,
              ),
            ),
            Wrap(
              spacing: 12,
              children: [
                TextButton.icon(
                  onPressed: saving ? null : choosePhoto,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(photo.isEmpty ? '添加豆袋照片' : '更换照片'),
                ),
                if (photo.isNotEmpty)
                  TextButton(
                    onPressed: saving ? null : () => setState(() => photo = ''),
                    child: const Text('移除照片'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _text(name, '咖啡豆名称', required: true),
            const SizedBox(height: 14),
            _text(roaster, '烘焙商（选填）'),
            const SizedBox(height: 14),
            const SectionTitle('产地信息'),
            _text(country, '国家或地区（可填未知、拼配或其他国家）'),
            const SizedBox(height: 14),
            _text(region, '具体产区', max: 160),
            const SizedBox(height: 14),
            _text(farm, '庄园／农场／合作社（选填）', max: 160),
            const SizedBox(height: 14),
            _text(station, '处理站（选填）', max: 160),
            if (origin.text.isNotEmpty)
              ExpansionTile(
                initiallyExpanded: !originReviewed,
                title: const Text('原产地信息（迁移原文）'),
                children: [
                  SelectableText(origin.text),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('已整理，可收起原文'),
                    value: originReviewed,
                    onChanged: (v) => setState(() => originReviewed = v!),
                  ),
                ],
              ),
            const SectionTitle('豆子信息'),
            Text('豆种／品种（多选，也可自定义）', style: TextStyle(color: muted(c))),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final v in {...varietyChoices, ...selectedVarieties})
                  FilterChip(
                    label: Text(v),
                    selected: selectedVarieties.contains(v),
                    onSelected: (_) => setState(
                      () => selectedVarieties.contains(v)
                          ? selectedVarieties.remove(v)
                          : selectedVarieties.add(v),
                    ),
                  ),
              ],
            ),
            TextFormField(
              controller: variety,
              maxLength: 80,
              decoration: fieldLabel('自定义品种（填写后点添加）'),
            ),
            TextButton(
              onPressed: () {
                final v = variety.text.trim();
                if (v.isNotEmpty && selectedVarieties.length < 20) {
                  setState(() {
                    selectedVarieties.add(v);
                    variety.clear();
                  });
                }
              },
              child: const Text('添加品种'),
            ),
            const SizedBox(height: 20),
            Text('烘焙程度', style: TextStyle(fontSize: 13, color: muted(c))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                for (final r in roastChoices)
                  ChoiceChip(
                    label: Text(roastName(r)),
                    selected: roast == r,
                    onSelected: (_) => setState(() => roast = r),
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _text(process, '处理法（保留原文，可自定义）', max: 300),
            Wrap(
              spacing: 6,
              children: [
                for (final p in ['水洗', '日晒', '蜜处理', '厌氧发酵'])
                  ActionChip(
                    label: Text(p),
                    onPressed: () => setState(() => process.text = p),
                  ),
              ],
            ),
            const Text(
              '烘焙程度是记录标签，不代表跨烘焙商统一量化标准。',
              style: TextStyle(fontSize: 12),
            ),
            const SectionTitle('购入信息'),
            TextFormField(
              controller: weight,
              decoration: fieldLabel('购入净重 / g'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),

              validator: (v) {
                final n = double.tryParse(v ?? '');
                return n == null ||
                        !n.isFinite ||
                        n < .1 ||
                        n > 50000 ||
                        parseTenths(v ?? '', min: 1, max: 500000) == null
                    ? '请输入 0.1–50000 g，最多一位小数'
                    : null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: price,
              decoration: fieldLabel('购入价格 / 元（选填）'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) =>
                  parseMoney(v!) == null ? '请输入有效金额，最多两位小数' : null,
            ),
            const SizedBox(height: 12),
            _dateRow('购入日期', boughtAt, (v) => setState(() => boughtAt = v)),
            _dateRow(
              '烘焙日期（选填）',
              roastedAt,
              (v) => setState(() => roastedAt = v),
            ),
            const SectionTitle('风味与感受'),
            OutlinedButton(
              onPressed: () async {
                final result = await pickFlavors(
                  c,
                  widget.controller,
                  bagFlavors,
                  roast: roast,
                  country: country.text.trim(),
                );
                if (result != null && mounted) {
                  setState(() => bagFlavors = result);
                }
              },
              child: const Text('豆袋标注风味（与每杯实际风味分开）'),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final e in bagFlavors.entries)
                  FlavorTag(e.value, id: e.key),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: note,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: '备注、购买时的期待，或者任何想记住的事。',
                hintStyle: TextStyle(fontSize: 13, height: 1.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '每次冲煮后记录的粉量，会自动从豆仓余量中扣减。',
              style: TextStyle(fontSize: 12, color: muted(c), height: 1.7),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _text(
    TextEditingController t,
    String label, {
    bool required = false,
    int max = 80,
  }) => TextFormField(
    controller: t,
    maxLength: max,
    decoration: fieldLabel(label),
    validator: (v) => required && v!.trim().isEmpty ? '请填写咖啡豆名称' : null,
  );
  Widget _dateRow(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> changed,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label, style: const TextStyle(fontSize: 14)),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value == null ? '未填写' : '${value.year}.${value.month}.${value.day}',
          style: TextStyle(color: muted(context)),
        ),
        if (value != null)
          IconButton(
            tooltip: '清除$label',
            onPressed: () => changed(null),
            icon: const Icon(Icons.close_rounded, size: 16),
          ),
      ],
    ),
    onTap: () async {
      final d = await showDatePicker(
        context: context,
        initialDate: value ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
      );
      if (d != null) changed(d);
    },
  );
}

Future<void> adjustStock(
  BuildContext c,
  CoffeeController controller,
  Bean bean,
) => Navigator.of(c).push(
  CoffeeRoute(
    context: c,
    builder: (_) => StockEditor(controller: controller, bean: bean),
  ),
);

class StockEditor extends StatefulWidget {
  final CoffeeController controller;
  final Bean bean;
  const StockEditor({super.key, required this.controller, required this.bean});
  @override
  State<StockEditor> createState() => _StockEditorState();
}

class _StockEditorState extends State<StockEditor> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(), reason = TextEditingController();
  bool saving = false;
  @override
  void dispose() {
    amount.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() => saving = true);
    final before = widget.controller.data.remaining(widget.bean);
    final after = double.parse(amount.text);
    if (!await confirm(
      context,
      '确认库存校正',
      '余量 ${gramsText(before)} → ${gramsText(after)} g。\n原因：${reason.text.trim()}\n这是一条独立校正，不改变杯数、历史用量或购豆支出。',
      action: '保存校正',
    )) {
      if (mounted) setState(() => saving = false);
      return;
    }
    if (!mounted) return;
    setState(() => saving = true);
    final ok = await widget.controller.adjustStock(
      widget.bean,
      (after * 10).round(),
      reason.text.trim(),
    );
    if (!mounted) return;
    setState(() => saving = ok);
    if (ok) {
      Navigator.pop(context);
    } else {
      message(context, widget.controller.error!);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('校正余量')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            widget.bean.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            '当前计算余量 ${gramsText(widget.controller.data.remaining(widget.bean))} g',
            style: TextStyle(color: muted(c)),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: amount,
            decoration: fieldLabel('实际剩余 / g'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              final n = double.tryParse(v ?? '');
              return n == null ||
                      !n.isFinite ||
                      n < 0 ||
                      n > widget.bean.weight ||
                      parseTenths(v ?? '', max: widget.bean.weightTenths) ==
                          null
                  ? '填 0–${gramsText(widget.bean.weight)} g，最多一位小数'
                  : null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: reason,
            maxLength: 200,
            minLines: 3,
            maxLines: 5,
            decoration: fieldLabel('调整原因，如漏记、调磨损耗、赠送或称量校正'),
            validator: (v) => v!.trim().isEmpty ? '请填写调整原因' : null,
          ),
          Text(
            '校正保留前后克数和时间。以后编辑历史手记会重新计算余量；已有校正不会被覆盖。',
            style: TextStyle(color: muted(c), height: 1.7),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? '正在保存…' : '核对并保存校正'),
          ),
        ],
      ),
    ),
  );
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/controller.dart';
import '../core/models.dart';
import 'design.dart';

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
}) => Navigator.of(c).push<bool>(
  CoffeeRoute(
    context: c,
    builder: (_) => CupEditor(controller: controller, cup: cup, bean: bean),
  ),
);
String gramsText(num g) =>
    g == g.roundToDouble() ? g.toInt().toString() : g.toStringAsFixed(1);
InputDecoration fieldLabel(String s) =>
    InputDecoration(labelText: s, counterText: '');
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
  const CupEditor({super.key, required this.controller, this.cup, this.bean});
  @override
  State<CupEditor> createState() => _CupEditorState();
}

class _CupEditorState extends State<CupEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name,
      grams,
      water,
      seconds,
      note,
      shop,
      price;
  late String beanId, method;
  late DateTime at;
  late int rating;
  late Set<String> tastes;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final c = widget.cup;
    name = TextEditingController(text: c?.name ?? '');
    grams = TextEditingController(text: c == null ? '' : gramsText(c.grams));
    water = TextEditingController(text: c == null ? '' : c.water.toString());
    seconds = TextEditingController(
      text: c == null ? '' : c.seconds.toString(),
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
    tastes = {...?c?.tastes};
  }

  @override
  void dispose() {
    for (final t in [name, grams, water, seconds, note, shop, price]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    final g = double.parse(grams.text),
        w = int.parse(water.text),
        s = int.parse(seconds.text);
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
    setState(() => saving = true);
    final c = Cup(
      id: widget.cup?.id ?? newId(),
      name: selected?.name ?? name.text.trim(),
      at: at,
      method: method,
      beanId: beanId,
      grams: g,
      water: w,
      seconds: s,
      note: note.text.trim(),
      rating: rating,
      tastes: tastes.toList(),
      shop: shop.text.trim(),
      cents: parseMoney(price.text)!,
      favorite: widget.cup?.favorite ?? false,
    );
    final ok = await widget.controller.saveCup(c);
    if (!mounted) return;
    setState(() => saving = false);
    if (ok) {
      HapticFeedback.lightImpact();
      Navigator.pop(context, true);
    } else {
      message(context, widget.controller.error!);
    }
  }

  @override
  Widget build(BuildContext c) {
    final beans = widget.controller.data.beans;
    final g = double.tryParse(grams.text) ?? 0,
        w = int.tryParse(water.text) ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: spaceTitle(
          widget.controller,
          widget.cup == null ? '记下一杯' : '编辑手记',
        ),
        leading: IconButton(
          tooltip: '返回',
          onPressed: saving ? null : () => Navigator.maybePop(c),
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
            const Eyebrow('AFTER THE BREW'),
            const SizedBox(height: 12),
            const Text(
              '喝完了，再慢慢记。',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '留住这次的参数，也留住你的感受。',
              style: TextStyle(color: muted(c), fontSize: 13),
            ),
            const SizedBox(height: 26),
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
                  _number(water, '注水 / g', max: 30000),
                  _number(seconds, '时长 / 秒', max: 86400),
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
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                g > 0 && w > 0
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
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in flavors)
                  FilterChip(
                    label: Text(t),
                    selected: tastes.contains(t),
                    onSelected: (v) =>
                        setState(() => v ? tastes.add(t) : tastes.remove(t)),
                    showCheckmark: false,
                  ),
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
              title: const Text('更多信息（选填）', style: TextStyle(fontSize: 14)),
              childrenPadding: const EdgeInsets.only(bottom: 20),
              children: [
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
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.]' : r'[0-9]')),
    ],
    maxLength: 7,
    decoration: fieldLabel(label),
    onChanged: (_) => setState(() {}),
    validator: (v) {
      final n = num.tryParse(v ?? '');
      return n == null ||
              !n.isFinite ||
              n <= 0 ||
              n > max ||
              (decimal && (n * 10 - (n * 10).round()).abs() > .00001)
          ? (decimal ? '填 0.1–$max' : '填 1–$max')
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
  late final TextEditingController name,
      origin,
      roaster,
      process,
      note,
      weight,
      price;
  late String roast;
  DateTime? boughtAt, roastedAt;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final b = widget.bean;
    name = TextEditingController(text: b?.name ?? '');
    origin = TextEditingController(text: b?.origin ?? '');
    roaster = TextEditingController(text: b?.roaster ?? '');
    process = TextEditingController(text: b?.process ?? '');
    note = TextEditingController(text: b?.note ?? '');
    weight = TextEditingController(text: (b?.weight ?? 250).toString());
    price = TextEditingController(
      text: b == null || b.cents == 0 ? '' : money(b.cents),
    );
    roast = b?.roast ?? '浅烘';
    boughtAt = b?.boughtAt ?? DateTime.now();
    roastedAt = b?.roastedAt;
  }

  @override
  void dispose() {
    for (final t in [name, origin, roaster, process, note, weight, price]) {
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
        origin: origin.text.trim(),
        roaster: roaster.text.trim(),
        roast: roast,
        process: process.text.trim(),
        note: note.text.trim(),
        weight: int.parse(weight.text),
        cents: parseMoney(price.text)!,
        boughtAt: boughtAt,
        roastedAt: roastedAt,
      ),
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      message(context, widget.controller.error!);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: spaceTitle(
        widget.controller,
        widget.bean == null ? '收一袋好豆' : '编辑豆子',
      ),
      leading: IconButton(
        tooltip: '返回',
        onPressed: saving ? null : () => Navigator.maybePop(c),
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
          const Eyebrow('A NEW BAG, A NEW STORY'),
          const SizedBox(height: 12),
          const Text(
            '期待下一杯的味道。',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 26),
          _text(name, '咖啡豆名称', required: true),
          const SizedBox(height: 14),
          _text(roaster, '烘焙商（选填）'),
          const SizedBox(height: 14),
          _text(origin, '产地 / 庄园（选填）'),
          const SizedBox(height: 20),
          Text('烘焙程度', style: TextStyle(fontSize: 13, color: muted(c))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [
              for (final r in ['浅烘', '中烘', '深烘'])
                ChoiceChip(
                  label: Text(r),
                  selected: roast == r,
                  onSelected: (_) => setState(() => roast = r),
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _text(process, '处理法（选填，如水洗、日晒、厌氧）'),
          const SectionTitle('购入信息'),
          TextFormField(
            controller: weight,
            decoration: fieldLabel('购入净重 / g'),
            maxLength: 5,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              final n = int.tryParse(v ?? '');
              final used = widget.bean == null
                  ? 0
                  : widget.controller.data.used(widget.bean!.id);
              return n == null || n < 1 || n > 50000
                  ? '请输入 1–50000 g'
                  : n < used
                  ? '已记录用豆 ${gramsText(used)} g，购入量不能更小'
                  : null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: price,
            decoration: fieldLabel('购入价格 / 元（选填）'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => parseMoney(v!) == null ? '请输入有效金额，最多两位小数' : null,
          ),
          const SizedBox(height: 12),
          _dateRow('购入日期', boughtAt, (v) => setState(() => boughtAt = v)),
          _dateRow('烘焙日期（选填）', roastedAt, (v) => setState(() => roastedAt = v)),
          const SectionTitle('给这袋豆子留句话'),
          TextFormField(
            controller: note,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            decoration: const InputDecoration(
              hintText: '包装上的风味、购买时的期待，或者任何想记住的事。',
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
  );
  Widget _text(
    TextEditingController t,
    String label, {
    bool required = false,
  }) => TextFormField(
    controller: t,
    maxLength: 80,
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

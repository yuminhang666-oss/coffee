import 'package:flutter/material.dart';

import '../core/models.dart';
import 'design.dart';
import 'flavor_picker.dart';

class HistoryCompare extends StatefulWidget {
  final List<Cup> cups;
  const HistoryCompare({super.key, required this.cups});
  @override
  State<HistoryCompare> createState() => _HistoryCompareState();
}

class _HistoryCompareState extends State<HistoryCompare> {
  late String left, right;
  @override
  void initState() {
    super.initState();
    left = widget.cups.first.id;
    right = widget.cups[1].id;
  }

  Widget selector(
    String value,
    ValueChanged<String> changed,
  ) => DropdownButtonFormField<String>(
    key: ValueKey(value),
    initialValue: value,
    isExpanded: true,
    decoration: const InputDecoration(labelText: '选择手记'),
    items: [
      for (final c in widget.cups)
        DropdownMenuItem(
          value: c.id,
          child: Text(
            '${widget.cups.indexOf(c) + 1}. ${dayKey(c.at)} ${c.at.hour.toString().padLeft(2, '0')}:${c.at.minute.toString().padLeft(2, '0')} · ${gramsText(c.grams)} g · ${durationText(c.seconds)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: (v) => changed(v!),
  );
  @override
  Widget build(BuildContext c) {
    final a = widget.cups.firstWhere((c) => c.id == left),
        b = widget.cups.firstWhere((c) => c.id == right);
    final rows = <String, List<String>>{
      '粉量': [
        for (final x in [a, b]) x.grams > 0 ? '${gramsText(x.grams)} g' : '未记录',
      ],
      '注水': [
        for (final x in [a, b]) x.water > 0 ? '${gramsText(x.water)} g' : '未记录',
      ],
      '粉水比': [
        for (final x in [a, b]) ratioText(x.grams, x.water),
      ],
      '总时长（含滴滤）': [
        for (final x in [a, b]) x.seconds > 0 ? durationText(x.seconds) : '未记录',
      ],
      '水温': [
        for (final x in [a, b])
          x.temperature == null ? '未记录' : '${x.temperature} °C',
      ],
      '器具': [a.brewer, b.brewer],
      '磨豆机': [a.grinder, b.grinder],
      '研磨刻度（原文）': [a.grind, b.grind],
      '个人感受': [a.note, b.note],
    };
    return Scaffold(
      appBar: AppBar(title: const Text('同豆历史对照')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('对照两次记录，不推断某个参数导致更好喝；不同磨豆机的刻度不比较粗细。'),
          const SizedBox(height: 16),
          selector(left, (v) => setState(() => left = v)),
          const SizedBox(height: 12),
          selector(right, (v) => setState(() => right = v)),
          if (left == right)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('请选择两次不同的手记。'),
            ),
          for (final e in rows.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.key,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < 2; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${i == 0 ? 'A' : 'B'} · ${e.value[i].isEmpty ? '未记录' : e.value[i]}',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SectionTitle('这一杯我喝到的风味'),
          for (final x in [a, b])
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${x == a ? 'A' : 'B'} · ${dayKey(x.at)}'),
                  const SizedBox(height: 8),
                  x.tastes.isEmpty
                      ? const Text('未记录')
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (var i = 0; i < x.tastes.length; i++)
                              FlavorTag(x.tastes[i], id: x.resolvedTasteIds[i]),
                          ],
                        ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

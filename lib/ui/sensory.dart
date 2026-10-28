import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/models.dart';
import 'design.dart';
import 'editors.dart' show confirm;

class SensoryProfile extends StatelessWidget {
  final List<int?> values;
  const SensoryProfile({super.key, required this.values});
  @override
  Widget build(BuildContext c) {
    final complete = values.every((v) => v != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '个人感官描述 · 0–5，数值大不等于更好。不是 SCA 分数，与单杯喜欢程度分开。',
          style: TextStyle(fontSize: 12, height: 1.6),
        ),
        if (!complete)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('尚未填完六项，已填值会保留；填完后才绘制闭合面积。'),
          ),
        Semantics(
          label: '六项感官图，轴编号 1 到 6 对应下方文字，刻度 0 到 5',
          image: true,
          child: AspectRatio(
            aspectRatio: 1.1,
            child: CustomPaint(
              painter: _Radar(
                values,
                Theme.of(c).colorScheme.primary,
                muted(c),
              ),
            ),
          ),
        ),
        for (var i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${i + 1}. ${sensoryNames[i]}：${values[i] == null ? '未填写' : (values[i]! / 2).toStringAsFixed(1)}',
            ),
          ),
      ],
    );
  }
}

class _Radar extends CustomPainter {
  final List<int?> values;
  final Color color, line;
  _Radar(this.values, this.color, this.line);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2),
        r = math.min(size.width, size.height) / 2 - 46;
    Offset point(int i, double value) =>
        center +
        Offset(
              math.cos(-math.pi / 2 + i * math.pi / 3),
              math.sin(-math.pi / 2 + i * math.pi / 3),
            ) *
            r *
            value /
            5;
    Path polygon(List<Offset> points) {
      final p = Path()..moveTo(points.first.dx, points.first.dy);
      for (final o in points.skip(1)) {
        p.lineTo(o.dx, o.dy);
      }
      return p..close();
    }

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..color = line.withValues(alpha: .3)
      ..strokeWidth = 1;
    for (var n = 1; n <= 5; n++) {
      canvas.drawPath(
        polygon([for (var i = 0; i < 6; i++) point(i, n.toDouble())]),
        grid,
      );
    }
    void text(String value, Offset at) {
      final t = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(color: line, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(canvas, at - Offset(t.width / 2, t.height / 2));
    }

    for (var i = 0; i < 6; i++) {
      canvas.drawLine(center, point(i, 5), grid);
      text(
        '${i + 1} ${sensoryNames[i]}',
        point(i, 5) +
            Offset(
                  math.cos(-math.pi / 2 + i * math.pi / 3),
                  math.sin(-math.pi / 2 + i * math.pi / 3),
                ) *
                17,
      );
    }
    text('0', center + const Offset(8, 7));
    for (var n = 1; n <= 5; n++) {
      text('$n', point(0, n.toDouble()) + const Offset(11, 0));
    }
    if (values.every((v) => v != null)) {
      final p = polygon([for (var i = 0; i < 6; i++) point(i, values[i]! / 2)]);
      canvas.drawPath(p, Paint()..color = color.withValues(alpha: .14));
      canvas.drawPath(
        p,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    for (var i = 0; i < 6; i++) {
      if (values[i] != null) {
        canvas.drawCircle(
          point(i, values[i]! / 2),
          3.5,
          Paint()..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Radar old) =>
      old.values.toString() != values.toString() ||
      old.color != color ||
      old.line != line;
}

class SensoryEditor extends StatefulWidget {
  final CoffeeController controller;
  final Bean bean;
  const SensoryEditor({
    super.key,
    required this.controller,
    required this.bean,
  });
  @override
  State<SensoryEditor> createState() => _SensoryEditorState();
}

class _SensoryEditorState extends State<SensoryEditor> {
  late List<int?> values;
  bool saving = false, allowPop = false;
  @override
  void initState() {
    super.initState();
    values = [...widget.bean.sensory];
  }

  Future<void> leave() async {
    if (saving) return;
    if (values.toString() == widget.bean.sensory.toString() ||
        await confirm(context, '放弃感官档案编辑？', '未保存的六项输入将丢弃。', action: '放弃')) {
      if (!mounted) return;
      setState(() => allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> save() async {
    if (saving) return;
    setState(() => saving = true);
    final latest = widget.controller.data.beans.where(
      (b) => b.id == widget.bean.id,
    );
    if (latest.isEmpty) {
      setState(() => saving = false);
      message(context, '这袋豆子已移除');
      return;
    }
    final ok = await widget.controller.saveBean(
      Bean.fromJson({...latest.first.toJson(), 'sensory': values}),
    );
    if (!mounted) return;
    setState(() => saving = ok);
    if (ok) {
      setState(() => allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
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
        title: const Text('我的感官档案'),
        leading: IconButton(
          tooltip: '返回',
          onPressed: leave,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? '正在保存…' : '保存感官档案'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(widget.bean.name, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 12),
          const Text('每项 0–5，步进 0.5；初始未填写。可保存不完整档案，不会以 0 补齐。'),
          TextButton(
            onPressed: saving
                ? null
                : () => setState(() => values = List<int?>.filled(6, null)),
            child: const Text('清空六项'),
          ),
          for (var i = 0; i < 6; i++)
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sensoryNames[i],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(sensoryHints[i], style: const TextStyle(fontSize: 12)),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        tooltip: '减少${sensoryNames[i]}',
                        onPressed: saving
                            ? null
                            : () => setState(
                                () => values[i] = math.max(
                                  0,
                                  (values[i] ?? 1) - 1,
                                ),
                              ),
                        icon: const Icon(Icons.remove),
                      ),
                      Text(
                        values[i] == null
                            ? '未填写'
                            : (values[i]! / 2).toStringAsFixed(1),
                      ),
                      IconButton(
                        tooltip: '增加${sensoryNames[i]}',
                        onPressed: saving
                            ? null
                            : () => setState(
                                () => values[i] = math.min(
                                  10,
                                  (values[i] ?? -1) + 1,
                                ),
                              ),
                        icon: const Icon(Icons.add),
                      ),
                      TextButton(
                        onPressed: saving
                            ? null
                            : () => setState(() => values[i] = null),
                        child: const Text('清除'),
                      ),
                    ],
                  ),
                  Slider(
                    label: values[i] == null
                        ? '未填写'
                        : (values[i]! / 2).toStringAsFixed(1),
                    value: (values[i] ?? 0) / 2,
                    min: 0,
                    max: 5,
                    divisions: 10,
                    onChanged: saving
                        ? null
                        : (v) => setState(() => values[i] = (v * 2).round()),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          SensoryProfile(values: values),
        ],
      ),
    ),
  );
}

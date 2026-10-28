import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/models.dart';
import 'design.dart';
import 'editors.dart' show confirm;

Color flavorColor(BuildContext c, String group) {
  const colors = {
    'floral': 0xff8a739c,
    'citrus': 0xffad873f,
    'berry': 0xffa36b7c,
    'stone': 0xffb48366,
    'orchard': 0xff8d9163,
    'tropical': 0xff9a995e,
    'sweet': 0xffa48658,
    'tea': 0xff778b78,
    'nut': 0xff947e69,
    'cocoa': 0xff897069,
    'grain': 0xff9a8972,
    'spice': 0xff9b7766,
    'ferment': 0xff927c8f,
    'texture': 0xff8c8982,
    'fault': 0xff7f8587,
  };
  final color = Color(colors[group] ?? 0xff8c8982);
  return Theme.of(c).brightness == Brightness.dark
      ? Color.lerp(color, Colors.white, .3)!
      : color;
}

class FlavorPalette extends InheritedWidget {
  final List<FlavorTerm> terms;
  const FlavorPalette({super.key, required this.terms, required super.child});
  @override
  bool updateShouldNotify(FlavorPalette old) => old.terms != terms;
}

class FlavorTag extends StatelessWidget {
  final String label;
  final String? group, id;
  const FlavorTag(this.label, {super.key, this.group, this.id});
  @override
  Widget build(BuildContext c) {
    final color = flavorColor(
      c,
      group ??
          c
              .dependOnInheritedWidgetOfExactType<FlavorPalette>()
              ?.terms
              .where(
                (t) => t.id == id || flavorKey(t.label) == flavorKey(label),
              )
              .firstOrNull
              ?.group ??
          knownFlavor(label)?.group ??
          'texture',
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color)),
    );
  }
}

Future<Map<String, String>?> pickFlavors(
  BuildContext c,
  CoffeeController ct,
  Map<String, String> selection, {
  String roast = 'light',
  String country = '',
}) => Navigator.of(c).push<Map<String, String>>(
  CoffeeRoute(
    context: c,
    builder: (_) => FlavorPicker(
      controller: ct,
      selection: selection,
      roast: roast,
      country: country,
    ),
  ),
);

class FlavorPicker extends StatefulWidget {
  final CoffeeController controller;
  final Map<String, String> selection;
  final String roast, country;
  const FlavorPicker({
    super.key,
    required this.controller,
    required this.selection,
    this.roast = 'light',
    this.country = '',
  });
  @override
  State<FlavorPicker> createState() => _FlavorPickerState();
}

class _FlavorPickerState extends State<FlavorPicker> {
  late Map<String, String> selected;
  final search = TextEditingController();
  String browse = 'recommended', group = '', country = '';
  late String recommendedRoast;
  bool allowPop = false;
  @override
  void initState() {
    super.initState();
    selected = {...widget.selection};
    recommendedRoast = roastId(widget.roast);
    country = countryRecommendations.containsKey(widget.country)
        ? widget.country
        : '';
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> close({bool save = false}) async {
    final dirty =
        selected.length != widget.selection.length ||
        selected.entries.any((e) => widget.selection[e.key] != e.value);
    if (save ||
        !dirty ||
        await confirm(context, '放弃风味选择？', '当前选择尚未带回表单。', action: '放弃')) {
      if (!mounted) return;
      setState(() => allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, save ? selected : null);
      });
    }
  }

  Future<void> editTerm([FlavorTerm? term]) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await Navigator.of(context).push<FlavorTerm>(
      CoffeeRoute(
        context: context,
        builder: (_) => FlavorEditor(
          controller: widget.controller,
          term: term,
          initial: search.text,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      if (result != null && term == null && selected.length < 40) {
        selected[result.id] = result.label;
      }
    });
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: widget.controller,
    builder: (c, _) {
      final d = widget.controller.data,
          terms = [...builtInFlavors, ...widget.controller.data.customFlavors];
      final usage = <String, int>{}, recent = <String>[];
      final cups = [...d.cups]..sort((a, b) => b.at.compareTo(a.at));
      for (final cup in cups) {
        for (final id in cup.resolvedTasteIds) {
          usage[id] = (usage[id] ?? 0) + 1;
          if (!recent.contains(id)) recent.add(id);
        }
      }
      final recommended =
              (roastRecommendations[recommendedRoast] ??
                      roastRecommendations['light']!)
                  .split(' '),
          countryWords = (countryRecommendations[country] ?? '').split(' ');
      var visible = (browse == 'custom' ? d.customFlavors : terms)
          .where(
            (t) =>
                (t.active || browse == 'custom') &&
                (group.isEmpty || group == t.group),
          )
          .toList();
      final query = canonicalFlavor(search.text).toLowerCase();
      if (query.isNotEmpty) {
        visible = visible
            .where((t) => t.label.toLowerCase().contains(query))
            .toList();
      } else if (browse == 'recent') {
        visible = visible.where((t) => recent.contains(t.id)).toList()
          ..sort(
            (a, b) => recent.indexOf(a.id).compareTo(recent.indexOf(b.id)),
          );
      } else if (browse == 'frequent') {
        visible = visible.where((t) => (usage[t.id] ?? 0) > 0).toList()
          ..sort((a, b) => (usage[b.id] ?? 0).compareTo(usage[a.id] ?? 0));
      } else if (browse == 'custom') {
        visible = d.customFlavors
            .where((t) => group.isEmpty || group == t.group)
            .toList();
      } else if (browse == 'recommended') {
        int priority(FlavorTerm t) {
          final a = recommended.indexOf(t.label),
              b = countryWords.indexOf(t.label);
          return b >= 0
              ? b
              : a >= 0
              ? 100 + a
              : 200 + terms.indexOf(t);
        }

        visible.sort((a, b) => priority(a).compareTo(priority(b)));
      }
      String groupFor(String id) {
        for (final t in terms) {
          if (t.id == id) return t.group;
        }
        return 'texture';
      }

      return PopScope(
        canPop: allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) close();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('选择风味'),
            leading: IconButton(
              tooltip: '返回',
              onPressed: () => close(),
              icon: const Icon(Icons.arrow_back),
            ),
            actions: [
              TextButton(
                onPressed: () => close(save: true),
                child: const Text('完成'),
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('已选 ${selected.length}/40 · 切换分类保留选择'),
              ),
              if (selected.isNotEmpty)
                SizedBox(
                  height: 112,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final e in selected.entries)
                          InputChip(
                            label: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Text(e.value),
                            ),
                            avatar: const Icon(Icons.check, size: 16),
                            onDeleted: () =>
                                setState(() => selected.remove(e.key)),
                            backgroundColor: flavorColor(
                              c,
                              groupFor(e.key),
                            ).withValues(alpha: .15),
                          ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(
                      controller: search,
                      decoration: const InputDecoration(
                        labelText: '搜索风味（支持常见英文名）',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: browse,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '找词方式'),
                      items: [
                        for (final e in {
                          'recommended':
                              '${roastName(recommendedRoast)}推荐（优先排序）',
                          'all': '全部风味',
                          'recent': '最近使用',
                          'frequent': '常用风味',
                          'custom': '自定义与管理',
                        }.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => browse = v!),
                    ),
                    const SizedBox(height: 12),
                    if (browse == 'recommended') ...[
                      DropdownButtonFormField<String>(
                        initialValue: recommendedRoast,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '推荐烘焙程度（只改变排序）',
                        ),
                        items: [
                          for (final r in roastChoices)
                            DropdownMenuItem(
                              value: r,
                              child: Text(roastName(r)),
                            ),
                        ],
                        onChanged: (v) => setState(() => recommendedRoast = v!),
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: group,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '风味大类'),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('全部分类')),
                        for (final e in flavorGroups.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => group = v!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: country,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '可选产区推荐'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('不按产区推荐'),
                        ),
                        for (final k in countryRecommendations.keys)
                          DropdownMenuItem(value: k, child: Text(k)),
                      ],
                      onChanged: (v) => setState(() => country = v!),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '推荐仅帮助找词，不会自动勾选。参考术语示例：花香、茉莉、杏仁、菠萝、椰子、纸感（WCR 属性的中文简译）。其余为日常记录补充词，不是完整官方标准；口感和问题描述单独分类。',
                      style: TextStyle(fontSize: 12),
                    ),
                    TextButton.icon(
                      onPressed: () => editTerm(),
                      icon: const Icon(Icons.add),
                      label: const Text('找不到？新增自定义风味'),
                    ),
                    if (browse == 'custom')
                      for (final t in visible)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(t.label),
                          subtitle: Text(
                            '${flavorGroups[t.group]} · ${t.active ? '可用' : '已停用（历史保留）'}',
                          ),
                          trailing: IconButton(
                            tooltip: '修改或停用 ${t.label}',
                            onPressed: () => editTerm(t),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final t in visible.where((t) => t.active))
                          FilterChip(
                            label: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Text(t.label),
                            ),
                            selected: selected.containsKey(t.id),
                            showCheckmark: true,
                            selectedColor: flavorColor(
                              c,
                              t.group,
                            ).withValues(alpha: .22),
                            side: BorderSide(color: flavorColor(c, t.group)),
                            onSelected: (v) {
                              if (v && selected.length >= 40) {
                                message(c, '每条记录最多 40 个风味');
                                return;
                              }
                              setState(
                                () => v
                                    ? selected[t.id] = t.label
                                    : selected.remove(t.id),
                              );
                            },
                          ),
                      ],
                    ),
                    if (visible.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('没有找到，可以新增自定义词。'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class FlavorEditor extends StatefulWidget {
  final CoffeeController controller;
  final FlavorTerm? term;
  final String initial;
  const FlavorEditor({
    super.key,
    required this.controller,
    this.term,
    this.initial = '',
  });
  @override
  State<FlavorEditor> createState() => _FlavorEditorState();
}

class _FlavorEditorState extends State<FlavorEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController label;
  late String group, initial;
  late bool active;
  bool saving = false, allowPop = false;
  String get draft => '${label.text}|$group|$active';
  @override
  void initState() {
    super.initState();
    label = TextEditingController(text: widget.term?.label ?? widget.initial);
    group = widget.term?.group ?? 'texture';
    active = widget.term?.active ?? true;
    initial = draft;
  }

  @override
  void dispose() {
    label.dispose();
    super.dispose();
  }

  Future<void> leave() async {
    if (saving) return;
    if (draft == initial ||
        await confirm(context, '放弃风味词编辑？', '尚未保存的名称和分类将丢弃。', action: '放弃')) {
      if (!mounted) return;
      setState(() => allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() => saving = true);
    final term = FlavorTerm(
      id: widget.term?.id ?? 'custom-${newId()}',
      label: label.text.trim(),
      group: group,
      active: active,
    );
    final ok = await widget.controller.saveFlavor(term);
    if (!mounted) return;
    setState(() => saving = ok);
    if (ok) {
      setState(() => allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, term);
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
        title: Text(widget.term == null ? '新增风味词' : '编辑风味词'),
        leading: IconButton(
          tooltip: '返回',
          onPressed: leave,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: label,
              maxLength: 40,
              decoration: const InputDecoration(labelText: '风味名称'),
              validator: (v) {
                final value = canonicalFlavor(v ?? '');
                if (value.isEmpty) return '请填写风味词';
                if (knownFlavor(value) != null ||
                    widget.controller.data.customFlavors.any(
                      (t) =>
                          t.id != widget.term?.id &&
                          flavorKey(t.label) == flavorKey(value),
                    )) {
                  return '已有同名或别名词，请搜索后选择';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: group,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '分类'),
              items: [
                for (final e in flavorGroups.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => group = v!),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('可用于新记录'),
              subtitle: const Text('修改或停用不改写历史记录中的文字。'),
              value: active,
              onChanged: (v) => setState(() => active = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? '正在保存…' : '保存风味词'),
            ),
          ],
        ),
      ),
    ),
  );
}

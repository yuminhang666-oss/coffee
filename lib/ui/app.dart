import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/models.dart';
import 'design.dart';
import 'editors.dart';

class CoffeeRoot extends StatefulWidget {
  final CoffeeController controller;
  const CoffeeRoot({super.key, required this.controller});
  @override
  State<CoffeeRoot> createState() => _CoffeeRootState();
}

class _CoffeeRootState extends State<CoffeeRoot> {
  int tab = 0;
  @override
  Widget build(BuildContext c) {
    final ct = widget.controller, d = ct.data;
    if (ct.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (ct.locked) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: EmptyState(
                '暂时没能打开豆仓',
                ct.error!,
                action: '重新读取',
                onTap: ct.load,
              ),
            ),
          ),
        ),
      );
    }
    if (!d.onboarded) return Welcome(controller: ct);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (d.demo)
              Container(
                width: double.infinity,
                color: Theme.of(c).colorScheme.primary.withValues(alpha: .08),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 14,
                      color: Theme.of(c).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '示例豆仓 · 非个人记录',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(c).colorScheme.primary,
                        ),
                      ),
                    ),
                    Press(
                      label: '离开示例',
                      onTap: () => exitDemo(c, ct),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        child: Text(
                          '开始正式记录',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (ct.error != null)
              MaterialBanner(
                content: Text(ct.error!, style: const TextStyle(fontSize: 12)),
                actions: [
                  TextButton(
                    onPressed: () {
                      ct.error = null;
                      setState(() {});
                    },
                    child: const Text('知道了'),
                  ),
                ],
              ),
            Expanded(
              child: IndexedStack(
                index: tab,
                children: [
                  Pantry(controller: ct),
                  Journal(controller: ct),
                  Insights(controller: ct),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: panel(c),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: ink(c).withValues(alpha: .06)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Semantics(
                    selected: tab == i,
                    child: Press(
                      label: ['豆仓', '手记', '回味'][i],
                      onTap: () => setState(() => tab = i),
                      child: AnimatedContainer(
                        duration: Duration(
                          milliseconds: MediaQuery.disableAnimationsOf(c)
                              ? 0
                              : 180,
                        ),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tab == i
                              ? Theme.of(c).colorScheme.primary
                                    .withValues(alpha: .09)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              [
                                Icons.inventory_2_outlined,
                                Icons.auto_stories_outlined,
                                Icons.donut_small_rounded,
                              ][i],
                              size: 22,
                              color: tab == i
                                  ? Theme.of(c).colorScheme.primary
                                  : muted(c),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ['豆仓', '手记', '回味'][i],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: tab == i
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: tab == i
                                    ? Theme.of(c).colorScheme.primary
                                    : muted(c),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> exitDemo(BuildContext c, CoffeeController ct) async {
  if (await confirm(
    c,
    '开启自己的豆仓？',
    '这会移除示例空间中的所有内容，之后从空白豆仓开始。',
    action: '空白开始',
    destructive: true,
  )) {
    await ct.change(
      (d) => CoffeeData(onboarded: true, theme: d.theme),
      preserve: true,
    );
  }
}

class Welcome extends StatelessWidget {
  final CoffeeController controller;
  const Welcome({super.key, required this.controller});
  @override
  Widget build(BuildContext c) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(30, 36, 30, 30),
        children: [
          const Eyebrow('THE COFFEE JOURNAL'),
          const SizedBox(height: 28),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEFE4D3),
              ),
              child: const Padding(
                padding: EdgeInsets.all(28),
                child: CoffeeArt(),
              ),
            ),
          ),
          const SizedBox(height: 38),
          const Text(
            '一杯一记。\n每一袋，都有故事。',
            style: TextStyle(
              fontSize: 33,
              fontWeight: FontWeight.w600,
              height: 1.5,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '收藏买过的豆子。\n冲好、喝过，再写下属于你的风味。',
            style: TextStyle(fontSize: 15, height: 1.9, color: muted(c)),
          ),
          const SizedBox(height: 34),
          FilledButton(
            onPressed: controller.busy
                ? null
                : () => controller.change((d) => d.copy(onboarded: true)),
            child: const Text('开启我的豆仓'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: controller.busy
                ? null
                : () => controller.change(
                    (_) => CoffeeData.example(DateTime.now()),
                  ),
            child: const Text('先看看示例'),
          ),
          const SizedBox(height: 18),
          Text(
            '离线保存  ·  无需账号  ·  没有广告',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: muted(c), letterSpacing: 1),
          ),
          if (controller.error != null)
            Text(
              controller.error!,
              style: TextStyle(color: Theme.of(c).colorScheme.error),
            ),
        ],
      ),
    ),
  );
}

Widget settingsButton(BuildContext c, CoffeeController ct) => IconButton(
  tooltip: '设置与备份',
  onPressed: () => Navigator.of(c).push(
    CoffeeRoute(
      context: c,
      builder: (_) => SettingsPage(controller: ct),
    ),
  ),
  icon: const Icon(Icons.tune_rounded, size: 22),
);

class Pantry extends StatefulWidget {
  final CoffeeController controller;
  const Pantry({super.key, required this.controller});
  @override
  State<Pantry> createState() => _PantryState();
}

class _PantryState extends State<Pantry> {
  String filter = '在喝', query = '';
  @override
  Widget build(BuildContext c) {
    final ct = widget.controller, d = ct.data;
    final active = d.beans.where((b) => d.remaining(b) > 0).length;
    final grams = d.beans.fold<double>(0, (s, b) => s + d.remaining(b));
    final bs = d.beans
        .where(
          (b) =>
              (filter == '全部' ||
                  (filter == '在喝'
                      ? d.remaining(b) > 0
                      : d.remaining(b) == 0)) &&
              '${b.name} ${b.origin} ${b.roaster} ${b.process}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 26),
      children: [
        PageHeading(
          'THE COFFEE JOURNAL',
          '我的豆仓',
          '好豆子值得收藏，也值得慢慢喝。',
          trailing: settingsButton(c, ct),
        ),
        Press(
          label: '添加咖啡豆',
          onTap: () => editBean(c, ct),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF3B2B23),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BEANS FOR BETTER DAYS',
                  style: TextStyle(
                    color: Color(0xFFCCB8A1),
                    fontSize: 9,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 26,
                        runSpacing: 16,
                        children: [
                          _heroMetric('$active', '袋在喝'),
                          _heroMetric(gramsText(grams), 'g 豆仓余量'),
                        ],
                      ),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9D1AF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: espresso,
                        size: 26,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  '收一袋新豆，让日常多一点香气。',
                  style: TextStyle(color: Color(0xFFCCB8A1), fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                children: [
                  for (final f in ['在喝', '已喝完', '全部'])
                    ChoiceChip(
                      label: Text(f, style: const TextStyle(fontSize: 12)),
                      selected: filter == f,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => filter = f),
                      side: BorderSide.none,
                    ),
                ],
              ),
            ),
            Text(
              '${bs.length} 袋',
              style: TextStyle(color: muted(c), fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(
            hintText: '找豆子、产地或烘焙商',
            hintStyle: TextStyle(fontSize: 12, color: muted(c)),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            isDense: true,
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 18),
        if (bs.isEmpty)
          EmptyState(
            d.beans.isEmpty ? '给下一杯，留一个位置' : '这里还没有豆子',
            d.beans.isEmpty
                ? '买到喜欢的咖啡豆，就收进这里。\n每一袋的风味和余量，都有迹可循。'
                : '试试其他分类或搜索词。',
            action: '添加咖啡豆',
            onTap: d.beans.isEmpty ? () => editBean(c, ct) : null,
          ),
        for (final b in bs)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: BeanCard(
              bean: b,
              data: d,
              onTap: () => Navigator.of(c).push(
                CoffeeRoute(
                  context: c,
                  builder: (_) => BeanDetail(controller: ct, id: b.id),
                ),
              ),
            ),
          ),
        if (bs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: Center(
              child: Text(
                '把每一次相遇，留在豆仓里。',
                style: TextStyle(fontSize: 11, color: muted(c)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _heroMetric(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Color(0xFFFFF5E6),
          fontSize: 30,
          fontFamily: 'serif',
          height: 1.1,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        label,
        style: const TextStyle(color: Color(0xFFCCB8A1), fontSize: 10),
      ),
    ],
  );
}

class BeanCard extends StatelessWidget {
  final Bean bean;
  final CoffeeData data;
  final VoidCallback onTap;
  const BeanCard({
    super.key,
    required this.bean,
    required this.data,
    required this.onTap,
  });
  @override
  Widget build(BuildContext c) {
    final left = data.remaining(bean);
    return Press(
      onTap: onTap,
      child: Surface(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 76,
                  decoration: BoxDecoration(
                    color: bean.roast == '浅烘'
                        ? const Color(0xFFEDE7D9)
                        : const Color(0xFFE3D1BF),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const CoffeeArt(bean: true),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bean.origin.isEmpty ? '一袋好豆' : bean.origin,
                        style: TextStyle(
                          fontSize: 10,
                          color: muted(c),
                          letterSpacing: .5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        bean.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Tag(bean.roast),
                          if (bean.process.isNotEmpty) Tag(bean.process),
                        ],
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Icon(Icons.chevron_right_rounded, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 19),
            Row(
              children: [
                Expanded(
                  child: Text(
                    left == 0 ? '这一袋，喝完了' : '余量 ${gramsText(left)} g',
                    style: TextStyle(
                      fontSize: 11,
                      color: left == 0
                          ? muted(c)
                          : Theme.of(c).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '购入 ${bean.weight} g',
                  style: TextStyle(fontSize: 10, color: muted(c)),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: left / bean.weight,
                minHeight: 3,
                color: Theme.of(c).colorScheme.primary.withValues(alpha: .65),
                backgroundColor: muted(c).withValues(alpha: .1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BeanDetail extends StatelessWidget {
  final CoffeeController controller;
  final String id;
  const BeanDetail({super.key, required this.controller, required this.id});
  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: controller,
    builder: (c, _) {
      final found = controller.data.beans.where((b) => b.id == id);
      if (found.isEmpty) {
        return const Scaffold(body: Center(child: Text('这款豆子已移除')));
      }
      final b = found.first,
          logs = controller.data.cups.where((x) => x.beanId == id).toList()
            ..sort((a, b) => b.at.compareTo(a.at));
      return Scaffold(
        appBar: AppBar(
          title: spaceTitle(controller, '豆子档案'),
          actions: [
            IconButton(
              tooltip: '编辑咖啡豆',
              onPressed: () => editBean(c, controller, bean: b),
              icon: const Icon(Icons.edit_outlined, size: 21),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 14),
            child: FilledButton.icon(
              onPressed: controller.data.remaining(b) <= 0
                  ? null
                  : () => editCup(c, controller, bean: b),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                controller.data.remaining(b) <= 0 ? '这袋已经喝完了' : '用这款豆子，记一杯',
              ),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
          children: [
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE1CE),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: CoffeeArt(bean: true),
              ),
            ),
            const SizedBox(height: 24),
            const Eyebrow('THE BEAN FILE'),
            const SizedBox(height: 10),
            Text(
              b.name,
              style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tag(b.roast),
                if (b.origin.isNotEmpty) Tag(b.origin),
                if (b.process.isNotEmpty) Tag(b.process),
              ],
            ),
            const SizedBox(height: 24),
            Surface(
              child: Column(
                children: [
                  _fact(c, '烘焙商', b.roaster.isEmpty ? '未填写' : b.roaster),
                  _fact(
                    c,
                    '购入 / 剩余',
                    '${b.weight} g / ${gramsText(controller.data.remaining(b))} g',
                  ),
                  _fact(c, '购入价格', b.cents == 0 ? '未填写' : '¥${money(b.cents)}'),
                  _fact(
                    c,
                    '购入日期',
                    b.boughtAt == null ? '未填写' : dayKey(b.boughtAt!),
                  ),
                  _fact(
                    c,
                    '烘焙日期',
                    b.roastedAt == null ? '未填写' : dayKey(b.roastedAt!),
                  ),
                ],
              ),
            ),
            if (b.note.isNotEmpty) ...[
              const SectionTitle('关于这袋豆子'),
              Surface(
                child: Text(
                  b.note,
                  style: const TextStyle(fontSize: 14, height: 1.8),
                ),
              ),
            ],
            SectionTitle('这一袋的手记', aside: '${logs.length} 杯'),
            if (logs.isEmpty) const EmptyState('还没有冲煮记录', '喝完第一杯，再来记下参数和感受。'),
            for (final cup in logs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CupCard(
                  cup: cup,
                  onTap: () => showCup(c, controller, cup),
                ),
              ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () async {
                if (await confirm(
                  c,
                  '移除这款豆子？',
                  '已有手记会保留，但不再关联这款豆子。',
                  action: '移除',
                  destructive: true,
                )) {
                  final ok = await controller.removeBean(id);
                  if (ok && c.mounted) Navigator.pop(c);
                }
              },
              child: Text(
                '移除这款豆子',
                style: TextStyle(color: Theme.of(c).colorScheme.error),
              ),
            ),
          ],
        ),
      );
    },
  );
  Widget _fact(BuildContext c, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(label, style: TextStyle(fontSize: 12, color: muted(c))),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}

class Journal extends StatefulWidget {
  final CoffeeController controller;
  const Journal({super.key, required this.controller});
  @override
  State<Journal> createState() => _JournalState();
}

class _JournalState extends State<Journal> {
  String query = '';
  bool liked = false;
  @override
  Widget build(BuildContext c) {
    final ct = widget.controller;
    final cups =
        ct.data.cups
            .where(
              (x) =>
                  (!liked || x.favorite) &&
                  '${x.name} ${x.note} ${x.tastes.join(' ')}'
                      .toLowerCase()
                      .contains(query.toLowerCase()),
            )
            .toList()
          ..sort((a, b) => b.at.compareTo(a.at));
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 26),
      children: [
        PageHeading(
          'SIP, SAVOUR, REMEMBER',
          '咖啡手记',
          '参数留给下次，感受留给自己。',
          trailing: settingsButton(c, ct),
        ),
        Press(
          onTap: () => editCup(c, ct),
          child: Surface(
            color: Theme.of(c).colorScheme.primary.withValues(alpha: .08),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(
                  Icons.add_circle_outline_rounded,
                  color: Theme.of(c).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '喝完了，记下这一杯',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 19),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        TextField(
          decoration: const InputDecoration(
            hintText: '搜索豆子、风味或感受',
            hintStyle: TextStyle(fontSize: 12),
            prefixIcon: Icon(Icons.search_rounded, size: 20),
            isDense: true,
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text('全部手记'),
              selected: !liked,
              onSelected: (_) => setState(() => liked = false),
              showCheckmark: false,
            ),
            ChoiceChip(
              label: const Text('我的偏爱'),
              selected: liked,
              onSelected: (_) => setState(() => liked = true),
              showCheckmark: false,
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (cups.isEmpty)
          EmptyState(
            '等一杯值得记住的咖啡',
            ct.data.cups.isEmpty
                ? '选一款豆子，填写粉量、注水和时长。\n再给今天的风味，留几句话。'
                : '试试其他搜索词，或收藏喜欢的手记。',
            onTap: ct.data.cups.isEmpty ? () => editCup(c, ct) : null,
          ),
        for (var i = 0; i < cups.length; i++) ...[
          if (i == 0 || dayKey(cups[i].at) != dayKey(cups[i - 1].at))
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Eyebrow(
                '${cups[i].at.month.toString().padLeft(2, '0')} / ${cups[i].at.day.toString().padLeft(2, '0')}    ${cups[i].at.year}',
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: CupCard(cup: cups[i], onTap: () => showCup(c, ct, cups[i])),
          ),
        ],
      ],
    );
  }
}

class CupCard extends StatelessWidget {
  final Cup cup;
  final VoidCallback onTap;
  const CupCard({super.key, required this.cup, required this.onTap});
  @override
  Widget build(BuildContext c) => Press(
    onTap: onTap,
    child: Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  cup.method,
                  style: TextStyle(
                    fontSize: 10,
                    color: muted(c),
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (cup.favorite)
                Icon(
                  Icons.favorite_rounded,
                  size: 16,
                  color: Theme.of(c).colorScheme.primary,
                ),
              if (cup.rating > 0) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: Theme.of(c).colorScheme.primary,
                ),
                Text(
                  ' ${cup.rating}',
                  style: TextStyle(
                    color: Theme.of(c).colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 9),
          Text(
            cup.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${gramsText(cup.grams)} g 粉  /  ${cup.water} g 水  /  ${cup.seconds} 秒',
            style: TextStyle(fontSize: 11, color: muted(c)),
          ),
          if (cup.note.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              cup.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.75,
                color: ink(c).withValues(alpha: .8),
              ),
            ),
          ],
          if (cup.tastes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final t in cup.tastes) Tag(t)],
            ),
          ],
        ],
      ),
    ),
  );
}

Future<void> showCup(BuildContext c, CoffeeController ct, Cup initial) async {
  await showModalBottomSheet<void>(
    context: c,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: AnimationStyle(
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(c) ? 0 : 260,
      ),
      reverseDuration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(c) ? 0 : 200,
      ),
    ),
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .78,
      minChildSize: .4,
      maxChildSize: .94,
      builder: (context, scroll) => ListenableBuilder(
        listenable: ct,
        builder: (context, _) {
          final found = ct.data.cups.where((x) => x.id == initial.id);
          if (found.isEmpty) return const SizedBox();
          final cup = found.first;
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Eyebrow(
                      ct.data.demo
                          ? '示例手记 · A MOMENT IN YOUR CUP'
                          : 'A MOMENT IN YOUR CUP',
                    ),
                  ),
                  IconButton(
                    tooltip: cup.favorite ? '取消偏爱' : '加入偏爱',
                    onPressed: ct.busy ? null : () => ct.saveCup(cup.liked()),
                    icon: Icon(
                      cup.favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: Theme.of(c).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                cup.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${dayKey(cup.at)}  ·  ${cup.method}',
                style: TextStyle(fontSize: 12, color: muted(c)),
              ),
              const SizedBox(height: 24),
              Surface(
                child: Wrap(
                  spacing: 26,
                  runSpacing: 20,
                  children: [
                    _parameter(c, '${gramsText(cup.grams)} g', '粉量'),
                    _parameter(c, '${cup.water} g', '注水'),
                    _parameter(c, '${cup.seconds} s', '时长'),
                    _parameter(
                      c,
                      cup.grams > 0
                          ? '1 : ${(cup.water / cup.grams).toStringAsFixed(1)}'
                          : '—',
                      '粉水比',
                    ),
                  ],
                ),
              ),
              const SectionTitle('当时的感受'),
              Text(
                cup.note.isEmpty ? '这一杯，暂时没有写下感受。' : cup.note,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.9,
                  color: cup.note.isEmpty ? muted(c) : ink(c),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final t in cup.tastes) Tag(t)],
              ),
              if (cup.rating > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    '${'★' * cup.rating}${'☆' * (5 - cup.rating)}',
                    style: TextStyle(
                      fontSize: 21,
                      letterSpacing: 3,
                      color: Theme.of(c).colorScheme.primary,
                    ),
                  ),
                ),
              if (cup.shop.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(cup.shop, style: TextStyle(color: muted(c))),
                ),
              if (cup.cents > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '本杯额外支出 ¥${money(cup.cents)}',
                    style: TextStyle(color: muted(c), fontSize: 12),
                  ),
                ),
              const SizedBox(height: 26),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(sheet);
                  await editCup(c, ct, cup: cup);
                },
                child: const Text('编辑这篇手记'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  if (await confirm(
                    sheet,
                    '删除这篇手记？',
                    '删除后，相应的用豆量会返还豆仓。',
                    action: '删除',
                    destructive: true,
                  )) {
                    final ok = await ct.removeCup(cup.id);
                    if (ok && sheet.mounted) Navigator.pop(sheet);
                  }
                },
                child: Text(
                  '删除手记',
                  style: TextStyle(color: Theme.of(c).colorScheme.error),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

Widget _parameter(BuildContext c, String value, String label) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(value, style: const TextStyle(fontSize: 23, fontFamily: 'serif')),
    const SizedBox(height: 6),
    Text(label, style: TextStyle(fontSize: 11, color: muted(c))),
  ],
);

class Insights extends StatefulWidget {
  final CoffeeController controller;
  const Insights({super.key, required this.controller});
  @override
  State<Insights> createState() => _InsightsState();
}

class _InsightsState extends State<Insights> {
  bool all = false;
  @override
  Widget build(BuildContext c) {
    final ct = widget.controller, d = ct.data, now = DateTime.now();
    bool within(DateTime? v) =>
        all || (v != null && v.year == now.year && v.month == now.month);
    final cups = d.cups.where((x) => within(x.at)).toList();
    final beans = d.beans.where((x) => within(x.boughtAt)).toList();
    final beanCents = beans.fold<int>(0, (s, b) => s + b.cents),
        cupCents = cups.fold<int>(0, (s, x) => s + x.cents);
    final rated = cups.where((x) => x.rating > 0).toList();
    final avg = rated.isEmpty
        ? '—'
        : (rated.fold<int>(0, (s, x) => s + x.rating) / rated.length)
              .toStringAsFixed(1);
    final tasteCounts = {
      for (final t in flavors)
        t: cups.where((x) => x.tastes.contains(t)).length,
    };
    final tastes = tasteCounts.entries.where((x) => x.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 26),
      children: [
        PageHeading(
          'A TASTE OF YOUR DAYS',
          '慢慢回味',
          '喜欢什么味道，答案藏在每一杯里。',
          trailing: settingsButton(c, ct),
        ),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text('${now.month} 月'),
              selected: !all,
              onSelected: (_) => setState(() => all = false),
              showCheckmark: false,
            ),
            ChoiceChip(
              label: const Text('全部时光'),
              selected: all,
              onSelected: (_) => setState(() => all = true),
              showCheckmark: false,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(all ? 'YOUR COFFEE STORY' : 'THIS MONTH, IN COFFEE'),
              const SizedBox(height: 20),
              Text(
                '${cups.length}',
                style: const TextStyle(
                  fontSize: 64,
                  fontFamily: 'serif',
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '杯被好好记住的咖啡',
                style: TextStyle(fontSize: 12, color: muted(c)),
              ),
              const SizedBox(height: 22),
              const Divider(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 32,
                runSpacing: 22,
                children: [
                  _parameter(c, '${beans.length}', '袋购入'),
                  _parameter(c, avg, '平均喜爱度 / 5'),
                  _parameter(
                    c,
                    '${cups.where((x) => x.favorite).length}',
                    '篇偏爱手记',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SectionTitle('最近七天', aside: '每天记录的杯数'),
        Surface(
          child: _WeekChart(cups: d.cups, now: now),
        ),
        const SectionTitle('关于风味', aside: '按手记标签统计'),
        if (tastes.isEmpty)
          Surface(
            child: Text(
              '为手记加上风味标签，这里会慢慢长出你的偏好。',
              style: TextStyle(color: muted(c), height: 1.8, fontSize: 13),
            ),
          )
        else
          Surface(
            child: Column(
              children: [
                for (final t in tastes.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: Text(
                            t.key,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              minHeight: 5,
                              value: t.value / cups.length,
                              color: Theme.of(c).colorScheme.primary
                                  .withValues(alpha: .65),
                              backgroundColor: muted(c).withValues(alpha: .08),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          '${t.value} 杯',
                          style: TextStyle(fontSize: 11, color: muted(c)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SectionTitle('为喜欢买单', aside: '人民币'),
        Surface(
          child: Column(
            children: [
              _spend(c, '购豆支出', beanCents),
              const SizedBox(height: 16),
              _spend(c, '本杯额外支出', cupCents),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 12),
              _spend(c, '合计', beanCents + cupCents),
              const SizedBox(height: 16),
              Text(
                '按填写的购入日期与记录日期统计；购豆价不再摊入每杯，避免重复计费。未填价格按 0 元统计。',
                style: TextStyle(fontSize: 11, height: 1.7, color: muted(c)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _spend(BuildContext c, String label, int cents) => Row(
    children: [
      Expanded(
        child: Text(label, style: TextStyle(fontSize: 13, color: muted(c))),
      ),
      Text(
        '¥ ${money(cents)}',
        style: const TextStyle(fontSize: 20, fontFamily: 'serif'),
      ),
    ],
  );
}

class _WeekChart extends StatelessWidget {
  final List<Cup> cups;
  final DateTime now;
  const _WeekChart({required this.cups, required this.now});
  @override
  Widget build(BuildContext c) {
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(
      7,
      (i) => DateTime(today.year, today.month, today.day - 6 + i),
    );
    final counts = days
        .map((d) => cups.where((x) => dayKey(x.at) == dayKey(d)).length)
        .toList();
    final max = counts.fold<int>(1, (a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Semantics(
              label: '${dayKey(days[i])}，${counts[i]} 杯',
              excludeSemantics: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${counts[i]}',
                    style: TextStyle(fontSize: 11, color: muted(c)),
                  ),
                  const SizedBox(height: 9),
                  SizedBox(
                    height: 80,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 18,
                        height: counts[i] == 0 ? 3 : (counts[i] / max) * 80,
                        decoration: BoxDecoration(
                          color: counts[i] == 0
                              ? muted(c).withValues(alpha: .12)
                              : Theme.of(c).colorScheme.primary
                                    .withValues(alpha: i == 6 ? 1 : .45),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    i == 6 ? '今天' : '${days[i].day}',
                    style: TextStyle(fontSize: 10, color: muted(c)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class SettingsPage extends StatefulWidget {
  final CoffeeController controller;
  const SettingsPage({super.key, required this.controller});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool working = false;
  Future<void> export() async {
    final store = widget.controller.store;
    if (store is! AndroidStore) return;
    setState(() => working = true);
    try {
      final ok = await store.export(
        widget.controller.data.encode(backup: true),
      );
      if (ok && mounted) message(context, '备份已保存到你选择的位置。');
    } catch (_) {
      if (mounted) message(context, '备份未导出，请检查所选位置后重试。');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> restore() async {
    final store = widget.controller.store;
    if (store is! AndroidStore) return;
    setState(() => working = true);
    try {
      final raw = await store.importFile();
      if (raw == null) return;
      final candidate = CoffeeData.decode(raw);
      if (!mounted) return;
      if (await confirm(
        context,
        '恢复这份备份？',
        '包含 ${candidate.beans.length} 袋豆子、${candidate.cups.length} 篇手记${candidate.demo ? '（示例空间）' : ''}。\n将替换当前豆仓。替换前会在应用内保留一份原数据副本。',
        action: '替换并恢复',
        destructive: true,
      )) {
        final ok = await widget.controller.restore(candidate);
        if (mounted) message(context, ok ? '豆仓已恢复。' : widget.controller.error!);
      }
    } catch (_) {
      if (mounted) message(context, '无法恢复：文件格式、数据内容或版本不受支持。当前豆仓未被替换。');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: widget.controller,
    builder: (c, _) {
      final ct = widget.controller;
      final enabled = !working && !ct.busy;
      return Scaffold(
        appBar: AppBar(title: spaceTitle(ct, '设置与备份')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
          children: [
            const Eyebrow('MAKE YOURSELF AT HOME'),
            const SectionTitle('外观'),
            Surface(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final entry in {
                    'system': '跟随系统',
                    'light': '奶油浅色',
                    'dark': '浓咖深色',
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: ct.data.theme == entry.key,
                      showCheckmark: false,
                      onSelected: enabled
                          ? (_) => ct.change((d) => d.copy(theme: entry.key))
                          : null,
                    ),
                ],
              ),
            ),
            const SectionTitle('留住你的记录'),
            Surface(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.file_upload_outlined),
                    title: const Text('导出豆仓备份', style: TextStyle(fontSize: 14)),
                    subtitle: const Text(
                      'JSON 文件，保存到自己选择的位置',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                    enabled: enabled,
                    onTap: enabled ? export : null,
                  ),
                  const Divider(indent: 54),
                  ListTile(
                    leading: const Icon(Icons.file_download_outlined),
                    title: const Text('从备份恢复', style: TextStyle(fontSize: 14)),
                    subtitle: const Text(
                      '先校验内容，确认后替换当前豆仓',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                    enabled: enabled,
                    onTap: enabled ? restore : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '记录只保存在这台设备中。卸载应用会清除本机数据，请定期导出备份；备份文件未加密。',
              style: TextStyle(color: muted(c), fontSize: 12, height: 1.8),
            ),
            if (ct.data.demo) ...[
              const SectionTitle('示例空间'),
              OutlinedButton(
                onPressed: enabled ? () => exitDemo(c, ct) : null,
                child: const Text('移除示例，开始正式记录'),
              ),
            ],
            const SizedBox(height: 40),
            const Center(
              child: SizedBox(
                width: 82,
                height: 76,
                child: CoffeeArt(bean: true),
              ),
            ),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                '咖啡手记',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '0.1.0 · 本地体验版',
                style: TextStyle(color: muted(c), fontSize: 11),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                '为每一袋好豆，和每一杯日常。',
                style: TextStyle(color: muted(c), fontSize: 12),
              ),
            ),
          ],
        ),
      );
    },
  );
}

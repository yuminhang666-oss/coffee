// Original everyday vocabulary. IDs are immutable; labels are snapshots in records.
const flavorGroups = <String, String>{
  'floral': '花香',
  'citrus': '柑橘',
  'berry': '莓果',
  'stone': '核果',
  'orchard': '苹果梨与葡萄',
  'tropical': '热带水果',
  'sweet': '糖与甜香',
  'tea': '茶香',
  'nut': '坚果',
  'cocoa': '可可与巧克力',
  'grain': '谷物与烘焙',
  'spice': '香料',
  'ferment': '发酵与酒香',
  'texture': '口感与其他感受',
  'fault': '问题描述',
};
const _words = <String, String>{
  'floral': '花香 茉莉 橙花 玫瑰 白花 金银花 栀子花 桂花 洋甘菊 紫罗兰',
  'citrus': '柑橘 柠檬 青柠 佛手柑 甜橙 橘子 葡萄柚 柚子 金橘 柑橘皮',
  'berry': '莓果 蓝莓 草莓 树莓 黑莓 黑加仑 红醋栗 蔓越莓 莓果果酱',
  'stone': '白桃 黄桃 杏 油桃 李子 樱桃',
  'orchard': '青苹果 红苹果 梨 白葡萄 红葡萄 葡萄干 无花果 熟果',
  'tropical': '菠萝 芒果 百香果 荔枝 番石榴 甜瓜 西瓜 木瓜 椰子 龙眼',
  'sweet': '蜂蜜 蔗糖 冰糖 红糖 焦糖 太妃糖 枫糖 糖蜜 深焦糖',
  'tea': '茶感 白茶 绿茶 红茶 乌龙茶 伯爵茶 茉莉花茶',
  'nut': '坚果 杏仁 榛子 花生 核桃 腰果 夏威夷果 烘烤坚果',
  'cocoa': '可可 可可碎 牛奶巧克力 黑巧克力 巧克力 轻可可',
  'grain': '麦芽 烤谷物 吐司 饼干',
  'spice': '肉桂 丁香 肉豆蔻 香草',
  'ferment': '发酵水果 红酒 朗姆酒 白兰地',
  'texture': '奶油 丝滑 果汁感',
  'fault': '纸感 木质 生青 烟熏 焦苦',
};
String flavorKey(String text) =>
    text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
const flavorAliases = <String, String>{
  'citrus': '柑橘',
  'floral': '花香',
  'flowers': '花香',
  'berry': '莓果',
  'berries': '莓果',
  'nut': '坚果',
  'nuts': '坚果',
  'tea': '茶感',
  'cream': '奶油',
  'creamy': '奶油',
  'black currant': '黑加仑',
  'dark chocolate': '黑巧克力',
  'milk chocolate': '牛奶巧克力',
  'jasmine': '茉莉',
  'bergamot': '佛手柑',
  'lemon': '柠檬',
  'lime': '青柠',
  'orange': '甜橙',
  'blueberry': '蓝莓',
  'strawberry': '草莓',
  'blackcurrant': '黑加仑',
  'honey': '蜂蜜',
  'caramel': '焦糖',
  'cocoa': '可可',
  'chocolate': '巧克力',
  'black tea': '红茶',
  'white tea': '白茶',
  'green tea': '绿茶',
  'almond': '杏仁',
  '茉莉花': '茉莉',
  '佛手柑橘': '佛手柑',
  '茶香': '茶感',
  '黑加仑子': '黑加仑',
};
String canonicalFlavor(String text) =>
    flavorAliases[flavorKey(text)] ?? text.trim();
String builtInFlavorId(String label) =>
    'f-${label.runes.map((r) => r.toRadixString(16)).join('-')}';

class FlavorTerm {
  final String id, label, group;
  final bool active;
  const FlavorTerm({
    required this.id,
    required this.label,
    required this.group,
    this.active = true,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'group': group,
    'active': active,
  };
}

final builtInFlavors = [
  for (final e in _words.entries)
    for (final label in e.value.split(' '))
      FlavorTerm(id: builtInFlavorId(label), label: label, group: e.key),
];
FlavorTerm? knownFlavor(String text) {
  final label = canonicalFlavor(text);
  for (final t in builtInFlavors) {
    if (flavorKey(t.label) == flavorKey(label)) return t;
  }
  return null;
}

const roastNames = <String, String>{
  'dark': '深度烘焙',
  'mediumDark': '中深烘焙',
  'medium': '中度烘焙',
  'mediumLight': '浅中烘焙',
  'light': '浅度烘焙',
  'ultraLight': '极浅烘焙',
};
String roastId(String value) =>
    const {'浅烘': 'light', '中烘': 'medium', '深烘': 'dark'}[value] ?? value;
String roastName(String value) => roastNames[roastId(value)] ?? value;
const roastChoices = [
  'light',
  'ultraLight',
  'mediumLight',
  'medium',
  'mediumDark',
  'dark',
];
const roastRecommendations = <String, String>{
  'dark': '黑巧克力 烘烤坚果 深焦糖 烤谷物',
  'mediumDark': '可可 坚果 焦糖 肉桂 香草',
  'medium': '巧克力 红糖 坚果 熟果 黄桃 樱桃',
  'mediumLight': '甜橙 白桃 黄桃 杏 蜂蜜 红茶 轻可可',
  'light': '茉莉 橙花 玫瑰 桂花 柠檬 佛手柑 甜橙 葡萄柚 蓝莓 草莓 树莓 黑加仑 白桃 黄桃 杏 菠萝 芒果 百香果 荔枝 白茶 红茶 蜂蜜 青苹果 白葡萄',
  'ultraLight': '白花 茉莉 佛手柑 青苹果 白葡萄 白桃 白茶 金银花 栀子花 橙花 紫罗兰 玫瑰 青柠 柠檬 金橘 红醋栗 树莓 蓝莓 梨 荔枝 番石榴 乌龙茶 甜橙 蜂蜜',
};
const countryRecommendations = <String, String>{
  '埃塞俄比亚': '茉莉 花香 佛手柑 白桃 蓝莓 红茶',
  '哥伦比亚': '甜橙 柠檬 白桃 樱桃 树莓 百香果 红糖',
  '秘鲁': '柠檬 白桃 花香 蜂蜜 红糖 可可',
  '哥斯达黎加': '甜橙 蓝莓 白桃 蜂蜜 焦糖',
  '肯尼亚': '黑加仑 莓果 葡萄柚 红茶',
  '巴拿马': '花香 茉莉 佛手柑 白桃 百香果 白茶',
};

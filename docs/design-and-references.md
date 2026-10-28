# 设计取舍与来源

## 0.3.0：查阅、采用与边界（2026-10-28）

本轮独立用 Flutter 实现交互，未复制第三方代码、图片、词轮视觉布局或色值体系；未安装依赖。仍是豆仓／手记／回味，主流程是选豆 → 主参数 → 宽敞感受区 → 选填风味和评分 → 保存。

| 来源 | 本次实际读取与适用点 | 实际采用 | 未采用 |
| --- | --- | --- | --- |
| [WCR Sensory Lexicon](https://worldcoffeeresearch.org/resources/sensory-lexicon) | 官方介绍，包含风味、香气和质地属性，并说明强度描述用途 | 区分香气味道、口感与问题描述；花香、茉莉、杏仁、菠萝、椰子、纸感标为参考属性的中文简译 | 未下载或复制整份词典定义；不把扩展词库或个人图变成官方标准 |
| [SCA 风味轮资料](https://sca.coffee/store) | 商店公开说明，分层寻找描述的组织思路及使用范围 | 大类 → 具体词；采用独立下拉分类、搜索和勾选交互 | 未复刻轮图、完整视觉编排、品牌色或大段定义 |
| [Beanconqueror 风味选择源码](https://github.com/graphefruit/Beanconqueror/blob/develop/src/app/brew/brew-flavor-picker/brew-flavor-picker.component.ts) | 读取选词组件：分开预设与自定义，编辑使用副本，确认后返回选择 | 独立选择草稿、固定已选汇总、确认后带回单杯表单；自定义词有稳定身份 | 没有移植 Angular/Ionic 代码、数据结构或界面 |
| [Beanconqueror 雷达图源码](https://github.com/graphefruit/Beanconqueror/blob/develop/src/components/cupping-radar/cupping-radar.component.ts) | 读取指标输入和图表更新逻辑，并确认它有额外指标及合计分数 | 输入与可视化联动的组织思路；本项目独立实现六项、0.5 步进、空值不补零 | 不采用其指标、默认零、总分、Chart.js 或延迟更新机制 |
| [Roastbook README](https://github.com/michidk/roastbook) | 读取豆子产地、产区、农场、品种、处理法，以及冲煮历史和模板说明 | 字段职责明确；同豆参数复用与历史对照，一袋仍独立库存 | 不采用服务端、AI、同步或库存合并 |

本次核对 [Beanconqueror 根 LICENSE（GPL-3.0）](https://github.com/graphefruit/Beanconqueror/blob/develop/LICENSE) 与 [Roastbook 根 LICENSE（MIT）](https://github.com/michidk/roastbook/blob/main/LICENSE)。仅借鉴组织思路，没有复用代码或素材；如果将来复用，须再次检查具体文件与当时许可。以上是网页与源码阅读，没有运行或验证第三方应用。

词库来自本轮用户提供的候选，自行组织为 15 类、103 个中文词；ID 固定后不随显示名称修改。仅明确列出的参考属性简译具有上述参考关系，其余是日常找词补充。浅度和极浅度推荐均超过 20 个词，顺序不同，并始终保留全部风味。六国入口是产品找词排序，不是产地鉴定；不从产地填入品种或实际风味。本轮没有把可选进口商批次资料用作国家风味定论，也未引用其中未读取的内容。

自定义词历史使用“ID + 当时文字”快照。改名和停用只改变词库，新记录不显示停用候选，已选和历史不消失。颜色按家族设定，深浅主题分别调整明度；勾号、边框及固定已选列表共同表示选择。口感不伪装成香气。六项图使用原生绘制；不生成总分，不从每杯平均推导豆子档案。

## 0.2.0 历史记录


0.2.0 按用户指定使用 emil-design-eng 技能，沿用 Flutter Android 和离线架构。原生实现即时按压反馈、简短转场和减少动画支持；不移植技能中的网页 CSS，也不把 iOS 外观当作性能已经达标。

| Before | After | Why |
| --- | --- | --- |
| 大块深色概览占首屏，第一袋余量被底部导航遮住 | 标题旁保留新增入口，概览一行；完整第一袋和下一袋开头可见 | 豆仓和余量是首页核心 |
| 未选中筛选控件继承浅紫背景 | 明确设置奶油/浓咖的芯片、容器、次要色和 Cupertino 强调色 | 保持控件层级与整体咖啡色系一致 |
| 小型统一豆子插画 | 76×94 照片缩略图，缺图延用原创插画 | 识别具体一袋豆子，避免下载网络素材 |
| 卡片优先显示产地 | 优先显示烘焙商、名称、烘焙程度与余量，名称自然换行 | 对应挑选与回看场景 |
| 每次从头填粉量、注水、秒数 | 同豆子可沿用上次参数，日期为今天，个人感受重新填写 | 减少重复输入，同时避免伪造已完成记录 |
| 返回表单即退出 | 未保存变更时可取消退出或明确放弃 | 保护长段个人感受 |
| 仅 JSON 备份、没有撤销入口 | 完整 ZIP，确认数量后恢复，可撤销并找回照片 | 数据和照片是一份完整豆仓 |

记录发生在喝完之后：选择豆子 → 粉量、注水、总秒数 → 足够空间的个人感受 → 保存。评分和风味不强制，新水温、器具、磨豆机和原文磨度默认折叠。没有冲煮中的计时或提醒。

频繁切换底部标签直接切换；标签底色 180 ms，按压缩放 0.975 / 120 ms easeOutCubic，页面进入 260 ms、退出 200 ms，手记面板 260/200 ms 且可拖动关闭。尊重系统减少动画。没有重复列表入场、夸张回弹、实时模糊、网络字体或阻塞装饰。列表位置由持久页面状态和 PageStorage 保留；切换标签或分类收起键盘。

照片选择、解码、EXIF、压缩与 ZIP 文件读写在 Android 后台线程。列表只解码 360 px 缩略图；大图最长边 1600 px。`tools/profile_main.dart` 是单独启用的 profile 入口，生产 APK 使用 `lib/main.dart`，不会携带性能计时日志。真实环境、测得帧耗时与局限见 [验证记录](validation.md)。

## 来源与许可

0.2.0 没有新增外部代码、图像、字体或服务。`CoffeeArt` 和 Android vector 图标延用本项目原创；`test/fixtures/synthetic-bag.jpg` 由基本图形和系统字体自行绘制，并明确标为 SYNTHETIC SAMPLE / QA TEST IMAGE，专用于测试与示例截图。

以下是 0.1.0 于 2026-10-21 留存的功能组织参考记录，本轮未重新查询许可证，也未新增任何素材或代码复用：

- [Kryvutsia-Roman/CoffeeDiary](https://github.com/Kryvutsia-Roman/CoffeeDiary)：参考豆仓与手记分离；当时根目录未见许可证，没有采用代码、图像或品牌。
- [whiteSHADOW1234/CafedentialApp](https://github.com/whiteSHADOW1234/CafedentialApp)：比较笔记、评分与空态；当时仅 README 声明 MIT，未取得独立 LICENSE，未当作已核实复制许可；没有采用代码、图像或品牌。主观星级不冒充专业杯测标准。

本轮仅修改独立 coffee 仓库；复用既有开发工具，以 `-read-only -no-snapshot` 运行既有 AVD。没有修改 CampusFlow 源码、D:/Codex/记账、其他应用签名、用户账本或原始模拟器镜像。项目没有擅自新增整体开源许可证，第三方 SDK 保留原许可。

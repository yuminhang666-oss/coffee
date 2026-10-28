# schema 3 与备份兼容

## 版本分别管理

应用 0.3.0 / build 3。数据 schema 从 2 升到 3；接受 schema 1、2、3，拒绝其他版本或非整数版本。ZIP 容器仍为 version 2：目录、照片编码和路径规则没有变化，所以无需升级容器；其中 data.json 可为 schema 2 或 3。仍可恢复不含照片的旧 JSON（schema 1／2）。将来更改容器布局或编码时升级容器版本，更改数据约定时升级 schema，二者不互相冒充。

## 字段与单位

| 字段 | schema 3 约定 |
| --- | --- |
| Cup.waterTenths | 整数十分之一克；替代旧整数 g 的 water。240 g → 2400，240.5 g → 2405 |
| Cup.gramsTenths / Bean.weightTenths / 校正 before、after | 继续整数十分之一克，库存运算只用整数 |
| Cup.seconds | 保持原始整数总秒数，范围 0–86400；分秒只是编辑和显示转换，不改为仅注水时间 |
| Cup.temperature | nullable，整数 0–100；模型保留历史空值，新表单要求实际填写 |
| Bean.roast | dark、mediumDark、medium、mediumLight、light、ultraLight；中文标签独立于 ID |
| Bean.origin | 原产地自由文本，完整追溯，不能可靠拆分就留在原文中；originReviewed 只控制默认折叠 |
| Bean.country / region / farm / station / varieties | 分别国家地区、具体产区、庄园农场合作社、处理站、品种列表；迁移时为空 |
| Bean.bagFlavors + bagFlavorIds | 包装标注的 ID 与当时文字，与 Cup.tastes + tasteIds 分开 |
| Bean.sensory | 固定顺序六项；null 或 0–10 整数，显示值为整数的一半，因此 0.5 不用浮点保存 |
| CoffeeData.customFlavors | ID、label、group、active；停用不删除，历史快照独立保存 |

旧三档只明确映射：浅烘 → light、中烘 → medium、深烘 → dark。旧八个风味词逐词对应稳定 ID，“柑橘”“花香”等保留大类原义，不替换为具体描述。WCR 参考属性与日常补充词的边界见来源记录；ID 不代表官方标准编号。

schema 1 先沿用既有重量迁移到 2，再执行 2 → 3；所有旧 ID、关联、金额、日期、感受、星级、收藏、照片、库存校正、主题、引导与示例标记保留。不推测水温、品种、庄园、感官值或实际风味。旧注水量只在旧 schema 路径乘 10，schema 3 不重复乘 10。

## 原始存档与提交

继续使用 files/coffee-v1.json 文件名。Android 首次迁移 schema 1 或 2 时，先解析、校验数据及照片，再用 AtomicFile 保留 coffee-schema1-original.json 或 coffee-schema2-original.json，随后才原子写入新数据。已有原始快照不覆盖。保留失败或解析失败锁定编辑，当前原始文件继续存在，不用空豆仓替代。

页面不写文件。所有保存、媒体、导入准备、恢复及撤销仍由 controller 串行处理：基于最新成功状态生成候选 → 完整数据与库存校验 → 照片校验 → 原子提交 → 更新界面。超出库存范围拒绝整体操作，不截断为零，不丢弃已有校正。

导入先暂存和校验，展示豆子／手记／照片／自定义风味／感官档案／校正数量，用户确认才替换。恢复前副本保留整份 JSON，因此词库和感官值与照片引用一起撤销；不可变照片不被提前删除。数量、重复 ID、词库引用、整数值、照片路径、同名异内容和未知未来版本均拒绝。

## 上限及回退

沿用 ZIP 64 MB、4002 条目、JSON 5 MB、2000 袋豆、10000 杯、10000 条校正。每条最多 40 风味、每词 40 字符，最多 500 个自定义词；品种最多 20 项，每项 80 字符；处理法最多 300 字符，产区／生产者／处理站最多 160 字符。表单明确拒绝多于一位小数的克数，不进行静默舍入或字符截断。

升级前宜导出完整 ZIP。schema 3 不支持直接被旧 0.2.0 读取；如需返回旧版，应在用户明确选择后安装旧包并恢复升级前完整备份。迁移原始快照用于排查与取回原始内容，不是跨版本无损降级功能。备份未加密、恢复仅一级撤销、历史照片暂不自动清理等既有限制继续适用。

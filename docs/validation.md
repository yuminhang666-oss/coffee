# 0.2.0 验证记录

日期：2026-10-22，Asia/Shanghai。全部应用数据与豆袋图片均为主动选择的示例或合成 QA，不是个人消费记录。

复用 Flutter 3.47.7 / Dart 3.13.5、JDK 17、Android SDK 36、Gradle 9.3.1 与现有缓存。没有安装新依赖、改全局设置或接入新服务。工作仓库为 `D:/Codex/CampusFlow/.local/coffee`，remote 为指定 coffee 仓库；开始时 `codex/coffee-v0.1.0` 工作区干净，更新分支 `codex/coffee-v0.2.0`。CampusFlow 主仓库保持干净。

## 自动化与原生检查

- `flutter analyze --no-pub`：No issues found。
- `flutter test --no-pub`：29 项全部通过，保留原 16 项并补充 13 项。覆盖显式 schema 1 迁移逐字段保留、旧 JSON、未知版本、原始备份失败锁定、参数复用清空/日期/保存前不扣库存、整数十分之一克、调整/编辑/删除/换豆联动、校正不改变杯数支出、冲突拒绝而不截断、照片重启/撤销引用、失败导入与失败写入不覆盖当前、长感受返回防丢失、校正后新增一杯仍一次保存。
- 320 px、1/2 倍字号覆盖豆仓/手记/回味/表单；新增浅/深色 320 px 两倍字号、长豆名、长烘焙商、长感受、0 g 已喝完、详情和展开更多参数。首次空白豆仓也有测试。这里只声明所测组件及滚动位置。
- Android debug 专用 Instrumentation：20 项通过。直接运行生产 `CoffeeFiles`，使用独立合成缓存目录；覆盖 EXIF 方向、1600/360 px、删除原选择文件后私有照片仍在、原始迁移存档逐字节保留、照片移除不误删恢复引用、独立存储目录完整备份往返、路径穿越/未知条目/重复文件/缺原图/缺缩略图/损坏 JPEG/非法引用/未知及小数版本/非整数照片数/文件数/大小限制、缺图禁止提交且当前文件不变。测试入口仅在 debug manifest，release 包已确认不含该入口。

证据：[analyze.log](../deliverables/v0.2.0/evidence/analyze.log)、[tests.log](../deliverables/v0.2.0/evidence/tests.log)、[native-tests.json](../deliverables/v0.2.0/evidence/native-tests.json)、[build-release.log](../deliverables/v0.2.0/evidence/build-release.log)。

## 既有模拟器中的实际流程

既有 AVD `PocketFlow_Hotfix_API36_20261017`，API 36 / x86_64，`-read-only -no-snapshot -no-window -gpu swiftshader`。主流程串口 emulator-5586；独立升级流程 emulator-5588。两个都是同一原始镜像的只读临时实例，没有写回原始磁盘镜像，没有操作其他应用。

| 实际操作 | 结果与证据层级 |
| --- | --- |
| 系统图片选择器新增一袋照片豆子 | 合成 QA_Photo_Bag，250 g；选图后私有原图/缩略图存在，重启后显示 |
| 首杯 15.5 g / 240 g / 145 秒与感受 | debug 实际界面保存，持久化断言余量 234.5 g |
| 沿用参数再记录 | 表单粉量复用、感受为空；保存前仍 4 篇手记，保存后 5 篇，余量 219 g |
| 编辑、删除第二杯 | 改为 16.5 g 后余量 218 g；删除后回到 234.5 g |
| 独立余量校正、重启 | 调整前 234.5 → 200.1 g，原因/时间独立保存；仍 4 篇手记，购豆支出仍 15600 分 |
| 照片更换与完整备份恢复、撤销 | 更换照片和烘焙商后，恢复 ZIP 找回旧照片；撤销找回新照片与新烘焙商，重启仍保留 |
| 旧 JSON 与未知版本通过系统选择器 | schema 1 JSON 恢复为 2 豆/3 手记；撤销找回原照片；schema 999 拒绝且原记录与照片保持 |
| 最终 x86_64 release 覆盖安装 | 保留照片、原记录和校正 200.1 g；无卸载 |
| 最终 release 更多参数 | 水温 93 °C、V60、C40、原文 22 clicks 经保存、重启和真实系统导出逐字段核对，见 release-optional-fields.json |
| 最终 release 创建、复用、编辑、删除、校正 | 真实 UI 再走一遍，编辑/删除会显示已有校正的计算影响；校正后重启显示 180.1 g |
| 最终 release 完整 ZIP、照片数量确认和撤销 | 系统选择器导出/恢复，确认 1 张照片，恢复旧烘焙商，撤销找回替换后的照片和烘焙商；未知版本未替换当前豆仓 |

最终 release 撤销后的系统导出还核对了替换照片 UUID，见 [release-undo-photo.json](../deliverables/v0.2.0/evidence/release-undo-photo.json)。

详细合成断言见 [emulator-v020.json](../deliverables/v0.2.0/evidence/emulator-v020.json)。直接读取私有 JSON 的断言来自 debuggable 测试包；最终 release 通过界面、系统导出 ZIP 与外部文件核对，未把 debug 读取权限当成 release 能力。

## 0.1.0 → 0.2.0 直接覆盖升级

第二个只读实例先安装原 0.1.0 ARM64 release，主动选择示例并经系统选择器导出 JSON，再直接 `install -r` 最终 0.2.0 ARM64 release；没有卸载。该 x86_64 镜像声明支持 `x86_64,arm64-v8a`，ARM64 通过兼容翻译执行，这不是 ARM 真机测试。

新版经系统选择器导出 ZIP，与旧版真实导出的 JSON 逐字段比较：2 豆/3 手记的全部旧字段、IDs、关联、价格、日期、感受、收藏、主题、示例标记均保持，重量转换为整数单位，新增字段为空。schema 从 1 变为 2。结果见 [direct-release-upgrade.json](../deliverables/v0.2.0/evidence/direct-release-upgrade.json) 及 `20-direct-upgrade-before` / `21-direct-upgrade-after` 截图。

## 性能实测

Flutter profile、API 36 x86_64、SwiftShader 软件渲染、1080×1920 / 420 dpi，明确排除启动前 3 秒。测量 5 组列表往返滚动、4 组打开详情/连续返回、打开照片大图、手记与回味切换。采集 391 帧，结果不是空闲等待期间的平均 FPS。

| 耗时 | 中位数 | P90 | 最大值 | 超过 16.67 ms |
| --- | ---: | ---: | ---: | ---: |
| Flutter build | 1.049 ms | 2.451 ms | 11.039 ms | 0 / 391 |
| Raster | 12.914 ms | 18.815 ms | 25.873 ms | 88 / 391 |

实际操作可以完成，软件渲染下存在超过 60 Hz 帧预算的帧。没有宣称始终 60 FPS、达到 iOS 流畅度或代表所有 Android 设备。详情见 [profile-timings.json](../deliverables/v0.2.0/evidence/profile-timings.json)，复现入口为 `tools/profile_main.dart`。release 用正常入口，不带计时输出。尚未在真机测 FPS、耗电、长列表极限、不同厂商后台或 Android 24–35 版本矩阵；Android 24–27 的 EXIF 兼容路径未实机验证。

## 安装包与限制

最终版本 0.2.0 / versionCode 2，applicationId 不变，minSdk 24、targetSdk 36。ARM64 / ARM32 / x86_64 release 均经签名校验、版本及权限检查；ARM32 未在对应设备运行。release 无 INTERNET、全相册、全盘读取权限，无 debug 测试入口。

0.1.0 和 0.2.0 的签名证书 SHA-256 均为 `e0abafcf0c3f78b58602d1e369e2f740d7dc5e516eb414cc70b218912e409ec4`。这是沿用的 Android Debug 体验签名，非新生产签名。没有读取或上传私钥。

[apk-verification.json](../deliverables/v0.2.0/evidence/apk-verification.json) 记录全部架构检查，手机包哈希见 [SHA256SUMS.txt](../deliverables/v0.2.0/SHA256SUMS.txt)。源码与合成截图进仓库，ARM64/ARM32 APK 及清单作为 v0.2.0 Release 附件；x86_64 仅供本机验证。

备份未加密；不做云同步。为保护存档/恢复引用，历史媒体暂不自动清理，反复更换或取消导入可能增加占用；导出仅包含当前引用照片。撤销只有上次替换前快照，不是多级历史。照片和 ZIP 的大小与数量限制见 README/架构文档。物理磁盘损坏、系统杀进程、耗尽空间等极端故障没有进行破坏性全矩阵试验。

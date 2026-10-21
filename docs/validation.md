# 0.1.0 验证记录

日期：2026-10-21（用户时区 Asia/Shanghai）。本地复用 Flutter 3.47.7 / Dart 3.13.5、JDK 17、Android SDK 36、Gradle 9.3.1；没有安装新的工具或第三方运行时依赖。

## 自动化检查

- `flutter analyze --no-pub`：No issues found。
- `flutter test --no-pub`：16 项全部通过，包含 12 个领域/存储测试与 4 个界面测试。
- 覆盖示例显式选择、JSON 往返、0.1 g 精度、库存随记录新增/编辑/删除、切换关联豆子、删除豆子后保留手记、超量阻止、写失败与重试、并发变更顺序、坏文件锁定、恢复前副本、未知版本/重复 ID/孤立引用/无效日期拒绝、整数金额、首次空白开始与表单填写。
- 界面覆盖 320 像素逻辑宽度、1 倍和 2 倍字号的豆仓/手记/回味/记录表单。修复了大字号分类标签的横向溢出。没有声称覆盖所有设备和所有滚动位置。

[分析日志](../deliverables/v0.1.0/evidence/analyze.log) · [测试日志](../deliverables/v0.1.0/evidence/tests.log) · [构建日志](../deliverables/v0.1.0/evidence/build-release.log)

## 安卓实际流程

使用既有 `PocketFlow_Hotfix_API36_20261017` AVD 的 `-read-only -no-snapshot` 实例，API 36 / x86_64，串口 emulator-5586。只安装和操作独立的 `cn.coffeejournal.coffee_journal` 应用，没有改动两个现有应用或其数据，没有写回模拟器原始镜像。

| 实际检查 | 结果 |
| --- | --- |
| 新增豆子 | 通过界面新增合成 QA_Ethiopia / QA_Roaster，购入 250 g |
| 冲煮后记录 | 界面填入 15.5 g 粉、240 g 水、145 秒和合成感受文字，成功保存 |
| 强制结束再启动 | 原文字与参数保留，余量为 234.5 g |
| 编辑粉量 | 经详情面板编辑到 16.5 g，余量变为 233.5 g |
| 删除手记 | 确认后删除，重启后余量恢复到 250 g |
| 主题保存 | 深色选择跨进程重启保留 |
| 系统备份导出 | 真实系统文件选择器在 Downloads 保存 JSON |
| 系统备份恢复 | 选择导出的文件、核对摘要并确认后恢复，数据与导出一致 |
| 替换前副本 | 私有副本保留恢复前的深色设置，当前恢复到备份中的 system |
| 错误备份 | 选择 schema 999 文件，显示拒绝提示；持久化内容逐字段未变 |
| release 升级 | 最终 x86_64 release 包覆盖安装成功，合成豆子和记录保留 |
| release 保存与重启 | 示例豆子原剩 235 g；再录 15.5 g 后重启，界面显示 219.5 g |
| release 文件恢复 | 最终 release 经系统选择器恢复明确的示例豆仓，2 袋豆子、3 篇手记 |

领域数值和文件一致性的直接断言是在 debuggable 测试包通过 `run-as` 检查，见 [emulator-smoke.json](../deliverables/v0.1.0/evidence/emulator-smoke.json)。非 debuggable release 的检查通过实际 UI 完成，没有将 debug 读取权限当成 release 能力。

## 安装包

ARM64 与 ARM32 均为 release 优化构建，版本 0.1.0 / versionCode 1，最低 API 24、目标 API 36。ARM64 APK 经 apksigner 验证，使用 APK v2 签名，证书为 Android Debug。实际签名检查没有接触私钥内容。release 清单只包含应用自身的动态接收器保护权限，没有 INTERNET 或外部存储读取权限。

SHA-256 见 [SHA256SUMS.txt](../deliverables/v0.1.0/SHA256SUMS.txt)，发布时再核对 GitHub 附件的大小与 SHA-256。x86_64 包用于本机模拟器验证；手机包作为 GitHub Release 附件，不加入源码 Git 历史。

## 视觉与验证边界

最终截图命名为 `10-release-pantry`、`11-release-record`、`12-release-dark`、`13-release-journal`、`14-release-insights`；其余截图是早期 debug 验证过程。内容全部为明确示例和合成 QA，不是个人消费记录。模拟器时钟与用户时区不同，不当作用户真实饮用时间。

没有在实体 Android 手机上测试，也没有真机 FPS/耗电或不同厂商后台测试；不能据模拟器检查断言已经达到所有 iPhone 的性能。没有进行 Android 7–15 全版本矩阵测试。

卸载会丢失本机数据；没有云同步。默认 debug 证书不是生产签名。内部恢复副本尚无界面撤销入口，应自行保留导出的备份。首版没有照片、批次补货、磨度、水温、通知或冲煮中的计时器。所有这些均为明确的首版边界。

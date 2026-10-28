# Coffee Journal 0.3.0+3

已实现主参数分秒输入、一位小数注水、水温必填／历史空值、结构化豆子信息、六档烘焙、103 词分组风味库、推荐切换、个人六项感官图、同豆收藏参数复用与历史对照、搜索筛选以及 schema 1／2 → 3 迁移。

- 手机通常选择 [ARM64 安装包](https://github.com/yuminhang666-oss/coffee/releases/download/v0.3.0/CoffeeJournal-0.3.0-arm64.apk)；旧 ARM32 手机选择 [ARM32 包](https://github.com/yuminhang666-oss/coffee/releases/download/v0.3.0/CoffeeJournal-0.3.0-arm32.apk)。[x86_64 包](https://github.com/yuminhang666-oss/coffee/releases/download/v0.3.0/CoffeeJournal-0.3.0-x86_64.apk) 用于模拟器。
- [完整源码 ZIP](https://github.com/yuminhang666-oss/coffee/releases/download/v0.3.0/CoffeeJournal-0.3.0-source.zip) · [源码差异补丁](https://github.com/yuminhang666-oss/coffee/releases/download/v0.3.0/CoffeeJournal-0.3.0-changes.patch) · [SHA-256](SHA256SUMS.txt)。源码仍位于本 coffee 仓库，已按用户授权提交并推送至 [GitHub](https://github.com/yuminhang666-oss/coffee/releases/tag/v0.3.0)。
- [更新说明](../../docs/v0.3.0.md) · [迁移说明](../../docs/migration-v0.3.0.md) · [参考来源](../../docs/design-and-references.md) · [完整验证与限制](../../docs/validation-v0.3.0.md)。

静态检查无问题，44 项 Flutter 测试和 22 项 Android 原生测试通过；三个 release 包构建及签名核验通过。实际隔离模拟器验证覆盖升级、分秒／小数注水、水温、库存编辑／换豆／删除、风味与感官保存、收藏复用、新旧备份恢复与撤销和未知版本拒绝。

关键截图：[主参数](evidence/04-main-parameters-and-feelings.png)、[极浅推荐](evidence/16-final-ultralight-recommendations.png)、[感官档案](evidence/20-final-sensory-profile.png)、[历史对照](evidence/08-history-compare.png)、[320 宽／两倍字号豆仓](evidence/17-final-320px-2x-pantry.png)。历史对照的选择项在最终版增加了序号和时间，具体以源码和实际界面为准。

所有照片、记录和截图均为明确标识的合成示例。应用 ID 和既有体验签名保持，仍为 Android Debug 体验签名。真机、ARM64／ARM32 硬件及 Android 全版本矩阵未测；未进行真实磁盘耗尽或断电的全矩阵试验。备份未加密，历史照片暂不自动清理，恢复为一级撤销。

为减少本机占用，远端附件核对成功后清理本轮生成的临时构建、QA 模拟器和重复安装包。完整源码仍在仓库，安装包可从上述固定地址重新下载。

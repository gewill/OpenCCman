# #260 移动端容量证据准备

这不是验收通过报告。生产开关仍为 false，尚未取得签名真机矩阵的证据。当前只交付可复现输入集；不把 Mac、Simulator 或生成成功当作 iOS 100 MiB 容量承诺。

## 固定输入

```sh
python3 scripts/test-mobile-capacity-fixtures.py
python3 scripts/generate-mobile-capacity-fixtures.py --output /tmp/openccman-mobile-fixtures
```

默认生成 20、50、100 MiB × 四类语料共 12 文件，占用 680 MiB 磁盘。生成器每次只构造约 64 KiB 数据，UTF-8 种子重复到目标边界，剩余字节用 ASCII `x` 填充；不会切断编码。目录必须不存在，工具不覆盖旧数据。失败时保留部分生成文件供诊断；再次运行应换一个空路径。

| 语料 | 用途 |
|---|---|
| no-newline | 全文无换行的中文与词组，防止依赖行分割隐藏缓冲增长 |
| ascii | ASCII 和 CRLF，覆盖字节数与字符数相等的输入 |
| unicode | 中文、Emoji/ZWJ/肤色、分解重音、NUL、CRLF/空行/CR/LF/U+2028/U+2029；首个 U+FEFF 是 BOM，后续 U+FEFF 是正文，必须保留 |
| phrases | 地域词组密集语料，供七配置比较输出尺寸；不假定每个配置都会扩张 |

manifest 记录精确字节数、输入 SHA-256、种子字节、生成器 SHA-256、应用 HEAD 和锁定 wrapper SHA。它只记录输入，**不提供预期输出**。每个文件需另用同一锁定 wrapper 的独立整篇转换建立七配置 oracle，并记录完整输出哈希；不能用相同 streaming 实现当唯一参考。含 NUL 输入不使用此前已观察到截断的 CLI 路径。

2026-10-01 本机已实际生成全套 12 文件，并通过独立的 65,537 字节分块严格 UTF-8 解码、长度及哈希读回。见 fixture-manifest.json；单元检查覆盖编码/块边界、拒绝覆盖和必需字符。没有测量设备内存，没有运行真机转换。

## 真机采样仍待完成

每条结果绑定 device model / OS / build / app SHA / wrapper SHA / corpus SHA / config / cache state / retained draft / repetition。不要把不同设备、输入、配置、冷热状态或稿件状态的样本相减。

- 设备：低内存支持机型 iPhone 与 iPad，签名 Release 候选。
- 配置：应用全部七组；冷、热、已用七配置缓存；空稿与接近 10 MiB 原文/结果两种状态。
- 每条件三次，记录整 App 的 peak physical footprint、阶段时间、热状态、内存警告与系统退出证据。100 MiB 相对 20 MiB 同条件峰值增量目标 ≤16 MiB；各轮数据和最坏值均保留，不能只挑最快一轮。
- 十轮完成/取消恢复循环；输入与输出完整哈希；私有目录清理；锁屏、后台、强退；Files/iCloud/第三方提供方与低空间/权限变化；系统保存取消/重试/同名。
- #16 承接最低 iOS 15，#14/#71 承接真实 Pro；#260 仍负责真机容量与启用，不提前关闭。

本机 Xcode 27.0（27A266a）`xctrace list templates` 已列出 Activity Monitor、Allocations 等模板，仅证明工具可用，尚未证明这些模板在目标真机上导出 physical footprint 的字段、采样频率和开销。先保存原始 trace 并核实字段，再实现自动比较；不得将 allocations live bytes、RSS 或 Mac `ru_maxrss` 冒充整 App physical footprint。设备确认前不安装到用户预留给其他项目的 iPhone。

帮助、容量提示和 CHANGELOG 的正式承诺只在 #260 门槛通过后更新；本 PR 不启用生产入口、不触发 Xcode Cloud、不修改购买和依赖。

## 独立整篇参考

```sh
python3 scripts/generate-mobile-capacity-oracle.py \
  --fixtures /tmp/openccman-mobile-fixtures \
  --opencc-path /absolute/clean/locked/SwiftyOpenCC \
  --output /tmp/openccman-mobile-oracle
python3 scripts/test-mobile-capacity-oracle.py \
  --binary /tmp/openccman-mobile-oracle/package/.build/release/Oracle
```

先校验每个输入的长度和 SHA、干净 wrapper 与应用/fixture 的锁定 revision，再在隔离 SwiftPM 包编译 Mac Release 参考程序。参考程序只链接 wrapper，一次调用 `ChineseConverter.convert` 处理整篇，不链接应用流式 service/pump；每个文件/配置独立进程，超时保留日志。参考程序刻意在 Mac 使用全文内存，绝不能把它的内存开销当作 iOS 实现指标。

七模式依次对应：简体、OpenCC 繁体、OpenCC 繁体＋台湾词组、台湾字形、台湾字形＋词组、香港字形、香港字形＋台湾词组；报告保留 options raw 值，便于与应用 `ConversionConfiguration` 核对。文件语义先去掉一个初始 BOM，正文 U+FEFF、NUL 和换行保持原样。小样本检查覆盖所有七模式的这些字节语义及非法 UTF-8 拒绝。

输出 `oracle.json` 包含输入/输出完整 SHA、字节数、模式、wrapper SHA、参考源码/二进制哈希。只有全部输入与七模式都成功才生成聚合报告；失败时保留 results/ 中已完成的单项，不能当成全矩阵通过。目录不得已存在，避免覆盖旧证据。当前不自动从设备读取任何用户文件；设备导出后的读回比较尚待签名真机流程补齐。

2026-10-01：上述整篇参考已实际运行全套 **84 项**，集合校验确认 12 输入 × 7 模式无重复/遗漏，每项输入长度/哈希与 fixture manifest 一致。完整输出参考见 oracle.json。七模式小样本字节语义、非法编码和 manifest 路径越界拒绝检查通过。这是输出参考生成证据，不是移动端容量或流式正确性验收。

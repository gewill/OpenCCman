# OpenCC 支持完善路线图（草案）

本文对照 OpenCC 官方 Web 转换器，盘点 OpenCCman 现在开放了哪些 OpenCC 能力，并给出分阶段计划。文中所有条目都是待审阅的规划：不代表已经排期，也不自动建 Issue。第 6 节的问题确认后，再按条目建 Issue 或补充到现有 Issue。

- 调研日期：2026-10-31
- 代码基准：`develop` @ [`81b1baf`](https://github.com/gewill/OpenCCman/tree/81b1baf8cf21b8e339a90a2b625a60bd32cc4b74)，引擎 [`gewill/SwiftyOpenCC` @ `564b094`](https://github.com/gewill/SwiftyOpenCC/tree/564b094b2b69f2c1e907fa3d89fe6845469a4e4e)（OpenCC 1.4.2）。下文代码链接里的行号都以这两个提交为准。
- 对照对象：[官方 Web 转换器](https://opencc.js.org/converter?config=s2t)（opencc-wasm v0.13.1，页面更新日期 2026-08-23），以及同站的[配置对比](https://opencc.js.org/compare)和[字形对照](https://opencc.js.org/glyphs)页面。
- 不在本文范围：OpenCC 上游版本同步。上游 1.4.3 尚未正式发布；发布后由现有周检工作流自动提同步 PR，见 [upstream-sync.md](upstream-sync.md)。

## 1. 官方 Web 版提供的能力（2026-10-31 实测）

| 能力 | 实测情况 |
| --- | --- |
| 配置 | 「選擇配置檔」中共列出 25 个配置：<br>• OpenCC 1.4.2 官方配置 16 个：`s2t` `t2s` `s2tw` `tw2s` `s2twp` `tw2sp` `s2hk` `hk2s` `s2hkp` `hk2sp` `t2tw` `tw2t` `t2hk` `hk2t` `t2jp` `jp2t`，与上游 [`data/config@ver.1.4.2`](https://github.com/BYVoid/OpenCC/tree/ver.1.4.2/data/config) 一致；<br>• jieba 插件配置：上游放在 `plugins/jieba`，单独分发；<br>• CNGov 社区配置 4 个：`t2cngov` 系列，词典来自 TerryTian-tech，不属于官方 OpenCC。 |
| 选择方式 | 先选来源（s/tw/hk/t/jp），再选目标（s/tw/hk/t/jp），另有「轉換地域用詞 (p)」和「結巴分詞」两个开关，以及「⇄ 對換來源與目標」按钮。页面根据选择自动确定配置文件，并显示文件名。 |
| 说明提示 | 「OpenCC 標準繁體」旁边有提示，说明它是用于中间转换的标准，不是现实中通行的完整书写规范。两个 CNGov 选项也各有说明。 |
| 候选字 | 开启后，有多个可选转换结果的字词会加下划线。点开后列出原字、默认项（标「預設」）和其他候选，可以手动改选。实测 `s2t` 把「一台几」转成「一臺幾」，「幾」被标出，可改选为「几」。 |
| 显示差异 | 在原文和结果两侧，成对高亮被替换的字词。 |
| 查看分词结果 | 页面有这个开关，对应 opencc-wasm 的 `inspect()`，返回分词结果和每个阶段的输出。本次实测没有看到分词边界的显示，**未核实**。 |
| 其他 | 清空、复制、转换状态提示。URL 只记录 `?config=`，不包含文本。没有文件上传、批量转换或自定义词典的界面。 |
| 配置对比页 | 对同一段文本一次运行全部 29 种配置，用表格列出结果。 |
| 字形对照页 | 输入单字，根据 OpenCC 字表找出相关字，用 Noto 字体的简体、香港、繁体、日文字形并排显示。 |
| 隐私 | 全部转换在浏览器本地完成。 |

## 2. OpenCCman 现状

### 2.1 转换配置

- 设置只有三个维度：目标语言（简体/繁体）、异体字标准（OpenCC/台湾/香港）、地域用词（不转换/台湾）。见 [ConversionConfiguration.swift:28-48](../OpenCCman/Model/ConversionConfiguration.swift#L28-L48)。
- **目标选简体时一律返回 `.simplify`，也就是固定用 `t2s`**，此时异体字和地域用词两个控件被禁用。见 [ConversionConfiguration.swift:10](../OpenCCman/Model/ConversionConfiguration.swift#L10) 和 [WorkspaceComponents.swift:60-65](../OpenCCman/View/WorkspaceComponents.swift#L60-L65)。
- 实际能用到 7 个配置：
  - 官方配置：`t2s`、`s2t`、`s2tw`、`s2twp`、`s2hk`；
  - 兼容配置：`legacy-s2t-tw-idiom`（OpenCC 繁体 + 台湾词组）和 `legacy-s2hk-tw-idiom`（**香港字形 + 台湾词组**）。
  
  代码注释见 [ChineseConversionService.swift:30-31](../OpenCCman/Services/ChineseConversionService.swift#L30-L31)，选项到配置的对应关系见引擎的 [ConfigurationName.swift](https://github.com/gewill/SwiftyOpenCC/blob/564b094b2b69f2c1e907fa3d89fe6845469a4e4e/Sources/OpenCC/ConfigurationName.swift)。
- 4 个预设：简体 / 繁体·OpenCC / 台湾正体＋台湾词组 / 香港繁体。见 [ConversionConfiguration.swift:50-66](../OpenCCman/Model/ConversionConfiguration.swift#L50-L66)，三语文案见 [zh-Hans Localizable.strings:62-72,155-159](../OpenCCman/zh-Hans.lproj/Localizable.strings#L62-L72)。
- 其他入口使用同一套配置：
  - macOS 服务读取当前保存的三个维度设置，见 [AppDelegate.swift:339-343](../OpenCCman/AppDelegate.swift#L339-L343)；
  - Shortcuts 只开放 4 个预设，见 [ConvertTextIntent.swift:5-28](../OpenCCman/Services/ConvertTextIntent.swift#L5-L28)（#26）。
- 商店描述写明「简体输出不等于完整的台湾词汇反向转换」，见 [2.1 商店描述回读](release/metadata-2026-09-30/readback/ios/version/2.1/zh-Hans.json)。这条说明正是因为简体方向固定用 `t2s`。

### 2.2 引擎（SwiftyOpenCC @ 564b094）

- **公开 API 只有 `Options` 的 5 个选项位**：`traditionalize`、`simplify`、`twStandard`、`hkStandard`、`twIdiom`。按配置名构造转换器的初始化方法是 `internal`，外部不能调用。见 [ChineseConverter.swift:36-57,71](https://github.com/gewill/SwiftyOpenCC/blob/564b094b2b69f2c1e907fa3d89fe6845469a4e4e/Sources/OpenCC/ChineseConverter.swift#L36-L71)。
- **`Options` 可表达的 14 种模式**：都已支持流式转换（[README](https://github.com/gewill/SwiftyOpenCC/blob/564b094b2b69f2c1e907fa3d89fe6845469a4e4e/README.md) 写明「All 14 existing option modes are supported」）。其中 `tw2s`、`tw2sp`、`hk2s`、`t2tw`、`t2hk` 引擎和流式转换都能用，只是 App 没有开放。
- **另外 6 个官方配置**：`s2hkp`、`hk2sp`、`tw2t`、`hk2t`、`t2jp`、`jp2t`。它们的配置文件和词典已经打进资源包（`Resources/Official/*`，全部资源约 1.21 MB），但 `Options` 表达不了这几种配置。
- **C 桥接口**：`CCConverterCreateWithConfig(configPath, dictionaryDirectory, …)` 可以接受任意配置文件路径，见 [header.h:23](https://github.com/gewill/SwiftyOpenCC/blob/564b094b2b69f2c1e907fa3d89fe6845469a4e4e/Sources/copencc/include/header.h#L23)。
- **候选与歧义标注**：`ConversionCandidates.cpp` 和 `ConversionAmbiguities.cpp` 已经参与编译（[Package.swift:27-28](https://github.com/gewill/SwiftyOpenCC/blob/564b094b2b69f2c1e907fa3d89fe6845469a4e4e/Package.swift#L27-L28)），但没有通过 C 桥导出。上游 NEWS 写明，这两个 API 在 1.4.2 中位于不对外安装的私有头文件，1.4.3 才转为正式公开 API。
- **分词插件**：`PluginSegmentation.cpp` 也参与编译，但没有打包 jieba 插件和它的词典。

### 2.3 付费、大文件与系统下限

- 免费用户每天可在主页转换 12 次，见 [IAPManager.swift:9](../OpenCCman/IAPManager.swift#L9)。Pro 权益包括去广告、不限次数和 Mac 大文件转换，见 [IAPManager.swift:23-36](../OpenCCman/IAPManager.swift#L23-L36)。切换预设、导入导出不计次；Shortcuts 免费且不计次（#26）。
- Mac 大文件转换已开放（[MacLargeFileCoordinator.swift:33](../OpenCCman/Services/MacLargeFileCoordinator.swift#L33)），单个文件上限 1 GiB（[FileConversionPolicy.swift:10](../OpenCCman/Services/FileConversionPolicy.swift#L10)）。iOS 大文件转换仍关闭（[MobileFileRuntime.swift:10](../OpenCCman/Services/MobileFileRuntime.swift#L10)，见 #260）。
- 最低支持 iOS 15 / macOS 12。

## 3. 差距对照

| # | 官方 Web 能力 | OpenCCman 现状 | 价值 | 成本 | 主要风险 |
| --- | --- | --- | --- | --- | --- |
| G1 | 繁→简区分来源地区：`tw2s`、`tw2sp`、`hk2s` | **无**，简体固定用 `t2s` | 高：可以去掉商店描述里的限制说明；`tw2sp` 能把「軟體」转成「软件」 | 低：引擎和流式转换已支持，只改 App | 老用户保存的「简体」设置必须仍用 `t2s`；界面要从「禁用」改为可选来源；三语文案 |
| G2 | 香港地域用词：`s2hkp`、`hk2sp` | **无**。现在的「香港 + 地域用词」实际是香港字形加**台湾**词组（兼容配置） | 中高 | 中：fork 需要新增按配置名构造的 API | 改变现有组合的含义会改变老用户的输出；fork 的 CI 和测试数据要同步更新 |
| G3 | 繁↔繁地区标准互转：`t2tw`、`t2hk`、`tw2t`、`hk2t` | **无** | 中：适合港台稿件互改、统一字形 | `t2tw`、`t2hk` 成本低；`tw2t`、`hk2t` 成本中，需要 G2 的 API | 需要「来源 × 目标」的选择方式，界面改动大 |
| G4 | 日文新旧字体：`t2jp`、`jp2t` | **无** | 低到中，受众窄 | 中：需要 G2 的 API，词典已在包内 | 涉及产品定位，需说明这不是翻译 |
| G5 | 来源 × 目标选择、对换按钮、显示配置名 | **部分**：只有目标和两个附加选项 | 中 | 中 | 与 #45、#50、#279 等布局 Issue 交叉；VoiceOver 和大字号要重新验收 |
| G6 | 显示差异 | **无**，由 **#27** 承接 | 高 | 已规划 | 不重复建 Issue |
| G7 | 候选字：标出可选结果并手动挑选 | **无** | 中高：可以修正「一台几」被转成「一臺幾」这类误转 | 中高 | 相关 API 要到 1.4.3 才正式公开；需要和转换结果的快照绑定；iOS 15 上弹出层的表现；不能只用颜色表示状态 |
| G8 | 多配置对比 | **无** | 中 | 低到中 | 每个转换器冷启动约 31 ms（[迁移记录](https://github.com/gewill/SwiftyOpenCC/blob/564b094b2b69f2c1e907fa3d89fe6845469a4e4e/docs/opencc-1.4.2-migration.md)），需要限制文本长度 |
| G9 | 查看分词和各阶段输出 | **无** | 低，主要用于诊断 | 中 | 官方页面效果未核实 |
| G10 | jieba 分词 | **无** | 低到中 | 高 | 插件通过 dlopen 动态加载，iOS 签名受限；词典 5–11 MB；流式转换不支持 |
| G11 | CNGov 通用规范汉字表繁体 | **无** | 低 | 中 | 不是官方词典，许可证和维护情况未核实 |
| G12 | 区域字形对照 | **无** | 低 | 中 | 与转换主线无关 |
| G13 | 自定义转换表 | **无**，由 **#31** 承接 | — | — | `CCConverterCreateWithConfig` 可接收生成的配置文件，可作为 #31 的技术输入 |
| G14 | 复制、清空、本地处理 | **有**（复制结果见 [WorkspaceComponents.swift:247](../OpenCCman/View/WorkspaceComponents.swift#L247)） | — | — | — |
| G15 | URL `?config=` | 无 | 低 | — | 不建议做；自动化场景已由 Shortcuts 覆盖 |
| — | 文件、大文件、系统服务、全局快捷键、Shortcuts | **官方 Web 没有，App 领先** | — | — | 开放新配置时，这些入口要同步覆盖 |

## 4. 分阶段计划

以下约定适用于每一条：

- 从 `develop` 新建 `codex/` 分支，PR 合回 `develop`，PR 中不用 `Closes`。
- 保持 iOS 15 / macOS 12 的最低支持版本。
- 英文、简体、繁体三种语言同步更新；繁体用词遵循 dev-standards 的 `zh_hant_terminology_guide.md`。
- UI 改动附前后截图，交互附录像。
- 涉及引擎的改动先在 fork 通过 CI，再更新 App 引用的引擎 revision。

### 近期：引擎已具备或只需小改

**N1　繁→简按来源地区转换（`tw2s` / `tw2sp` / `hk2s`）**

- 目标：选简体输出时，可以指定原文是台湾还是香港繁体，以及是否转换台湾地域用词。
- 范围：
  - 修改 `ConversionConfiguration` 的映射，目标为简体时启用并改写这两个控件的含义；
  - 服务、全局快捷键、Mac 大文件转换随之生效；
  - 更新商店描述中的限制说明和 What's New。
- 非目标：扩展 Shortcuts 预设（见 M4）。
- 依赖：无。
- 验收：
  - 新配置的输出与 SwiftyOpenCC 同版本官方测试用例一致；
  - 已保存的「简体」设置升级后仍用 `t2s`，输出逐字节不变；
  - 编辑器、服务、全局快捷键、大文件四个入口在相同设置下输出一致；
  - 三语文案齐全；默认字号、XXXL 和 VoiceOver 下可以操作。

**N2　SwiftyOpenCC 开放全部 16 个官方配置（在 fork 仓库实施）**

- 目标：新增按官方配置名构造转换器的公开 API，覆盖 `s2hkp`、`hk2sp`、`tw2t`、`hk2t`、`t2jp`、`jp2t`。
- 范围：
  - 新增公开的配置枚举和对应的构造方法；
  - 新增配置要么支持流式转换，要么在流式调用时明确报错；
  - 补充测试数据和 CI。
- 非目标：jieba、CNGov、小篆等非官方或未发布的配置；本条不升级 OpenCC。
- 依赖：无。词典已在包内，包体不增加。
- 验收：
  - 16 个配置的输出都与上游 1.4.2 命令行工具一致；
  - 原有 `Options` API 的行为和源码兼容性不变；
  - 流式转换与整段转换的结果逐字节一致；
  - App 更新引擎 revision 后，macOS 和 iOS 两端都能构建通过。

**N3　香港地域用词，并决定兼容组合的处理方式**

- 目标：提供 `s2hkp` / `hk2sp`。
- 范围：先确定第 6 节问题 3（兼容组合怎么处理），再调整「地域用词」选项、受影响的预设和文案。
- 非目标：「台湾正体＋台湾词组」预设的输出保持不变。
- 依赖：N2。
- 验收：
  - 输出与官方配置一致；
  - 已保存的兼容组合按确定的方案迁移，或保持原样；
  - 四个入口输出一致，三语文案齐全。

### 中期：需要调整界面模型，或依赖上游正式 API

**M1　「来源 × 目标」选择方式和对换按钮**

- 目标：补齐 `t2tw`、`t2hk`、`tw2t`、`hk2t`，交互与官方 Web 一致，可以选择是否显示配置名。
- 范围：设置面板与侧栏、预设映射、已保存设置的迁移；对换按钮的行为（是否同时交换原文和结果）待定。
- 非目标：布局框架本身。
- 依赖：N1–N3。
- 验收：
  - 每一种合法组合都对应唯一的官方配置；
  - 来源和目标相同等不合法组合不能选，或给出说明；
  - 老用户的设置迁移后输出不变；
  - iPhone、iPad、Mac 都有截图和录像，并覆盖 VoiceOver 和键盘操作。

**M2　日文新旧字体（`t2jp` / `jp2t`）**

- 是否做：取决于第 6 节问题 4。
- 范围：作为 M1 中的来源和目标，不新增预设。
- 验收：输出与官方配置一致；文案说明这是汉字字形转换，不是翻译。

**M3　候选字**

- 目标：在结果中标出有多个可选转换的字词，用户可以改选；复制和导出使用改选后的文本。
- 范围：
  - fork 导出 `ConvertWithAmbiguities` 和 `GetAllConversions`；
  - 编辑器显示标注和候选列表，支持键盘和 VoiceOver；
  - 改选结果与本次转换的快照绑定。
- 非目标：把改选结果写进词典（属于 #31）、跨文档记住改选、大文件。
- 依赖：
  - 建议等上游 1.4.3 正式发布，由周检自动同步后再做；
  - 与 #27 共用转换快照模型，建议先完成 #27。
- 验收：
  - 上游 NEWS 中的多结果示例（如「升平」）能被标出，候选顺序与上游一致；
  - 编辑原文或切换配置后，旧的标注失效；
  - 复制和导出的文本不含任何标记；
  - 记录主线程耗时。

**M4　系统入口支持新配置**

- 范围：Shortcuts 的参数从 4 个预设扩展到新的配置选择；同时更新服务菜单的说明。
- 依赖：在 #26 关闭后进行，不扩大 #26 首版的范围。
- 验收：
  - 输出与编辑器在相同设置下逐字节一致；
  - 用户已保存的、使用旧预设的快捷指令继续可用。

**M5　多配置对比预览**

- 目标：对当前原文或选中的片段，一次列出所有适用配置的结果，可以一键把某个配置设为当前配置。
- 范围：限制输入长度，在后台计算，可以取消。
- 依赖：M1。
- 验收：
  - 每个结果与单独使用该配置转换的结果一致；
  - 超出长度时有明确提示；
  - 三语文案齐全。

### 远期：仅评估，默认不做

| 编号 | 条目 | 建议 |
| --- | --- | --- |
| F1 | jieba 分词 | 只做评估：静态链接 cppjieba 的可行性、包体增量、冷启动和内存、流式转换支持。没有明确的用户需求前不实现。 |
| F2 | CNGov 通用规范汉字表繁体 | 先核实许可证和维护情况；默认不纳入。 |
| F3 | 查看分词和各阶段输出 | 只考虑作为诊断功能。 |
| F4 | 区域字形对照 | 与转换主线无关，默认不做。 |
| F5 | 小篆等 seal 配置 | 上游的实验性配置且尚未发布，等正式版再评估。 |

### 对现有 Issue 的补充（建议发评论，不新建 Issue）

- **#27**：差异显示可以参考官方 Web 的成对高亮；M3 的候选字会复用 #27 的转换快照。
- **#31**：C 桥的 `CCConverterCreateWithConfig` 可以接收运行时生成的配置文件，配合 OpenCC 的文本词典格式使用；接口可参考 opencc-wasm 的 `CustomConverter`。
- **#26**：说明 M4 是后续工作，不扩大 #26 首版的范围。

## 5. 查重结果

2026-10-31 用 `gh issue list --state all --search` 查过以下关键词：OpenCC、配置、config、词典、dictionary、jieba、分词、diff、差异、候选、日文、香港、台湾、tw2s、反向、自定义、preset、Shortcuts，以及 Issue 正文中的 `opencc-plan-follow-up` 标记。

- 已有 Issue，直接引用：#27、#31、#26、#25、#29、#30、#28、#256、#260、#268、#269、#11。
- 没有找到重复的条目：N1–N3、M1–M5、F1–F5。

## 6. 未核实事项与待决策问题

### 未核实

1. 官方 Web 的「查看分词结果」是否真的显示分词，实测未见效果。
2. N2 新增的 6 个配置能否直接在 fork 的流式转换中使用。
3. 1.4.2 源码中的 `ConversionInspection` 能否在 fork 中直接调用。
4. jieba 在 iOS 上的打包方式和实际体积；CNGov 词典的许可证。
5. 用户对香港词组和日文字形的实际需求，目前没有数据。

### 待决策

1. **产品模型**：继续以预设为主、只补 N1–N3，还是推进到 M1 的「来源 × 目标」选择方式？
2. **付费**：新配置、候选字、对比预览是否免费，是否计入主页每日 12 次？建议配置本身免费，与现有预设一致。
3. **兼容组合**：「香港字形 + 台湾词组」和「OpenCC 繁体 + 台湾词组」是否保留？如果改用 `s2hkp`，老用户的输出会变化。
4. **日文新旧字体**是否纳入产品范围？
5. **候选字**是等上游 1.4.3 正式发布，还是先基于 1.4.2 的私有 API 做原型？
6. **Issue 归属与版本**：N2 的 Issue 建在本仓库还是 gewill/SwiftyOpenCC？其余条目分别排进哪个版本？

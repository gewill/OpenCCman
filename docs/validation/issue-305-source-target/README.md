# #305：「来源 × 目标」选择与繁↔繁地区互转

2026-11-16 实现与验证，2026-11-17 补 Mac 前台核对，见 PR [#345](https://github.com/gewill/OpenCCman/pull/345)。跟踪 #301（路线图 M1）。

开发前决定记录在 [#305 评论](https://github.com/gewill/OpenCCman/issues/305#issuecomment-6906814762)。按决定，PR 等 2.3 切出发布分支或上架后再合入 `develop`，该 PR 随后已合入 develop。各项关闭标准的证据见下文，未验证项见文末；是否关闭由维护者决定。

## 2026-11-28 从 2.3 升级的 Mac 实测

在 macOS 27.2.1（arm64）用 Xcode 27.2（27B52）分别构建 v2.3 标签 `0fca3a2` 和 develop `13a9d67` 的 Debug App。两个产物使用项目沙盒权限和同一隔离 Bundle ID，按顺序运行，共用同一偏好容器。新版构建覆盖 `MARKETING_VERSION=2.4` 以验收对应版本的更新说明。工程当时的默认版本仍为 2.3，正式候选包须复核实际版本。

1. 在 2.3 的转换设置中选择 Traditional Chinese、OpenCC Standard、Taiwan Idiom，预设显示 Custom。输入「鼠标里面的软件和打印机，用的是信息技术。」并转换，结果编辑器显示「滑鼠裏面的軟體和印表機，用的是資訊科技。」。关闭旧进程前核对隔离偏好文件，只有旧的相关键 `regionOptions=Taiwan Idiom`，其余选项用默认值。
2. 启动同标识的 2.4 QA 包，首页自动出现 What’s New。本次英文页面明确指出 OpenCC Traditional with Taiwan Idiom 改用 Taiwan Traditional with Taiwan phrases（s2twp），并告知部分异体字有变化。
3. 关闭说明，直接输入同一原文并转换，结果为「滑鼠裡面的軟體和印表機，用的是資訊科技。」。样本只有「裏」变为「裡」。偏好文件读回 `conversionSource=s`、`conversionTarget=tw`、`conversionPhrases=Taiwan Idiom`、`lastPresentedWhatsNewVersion=2.4`，旧键仍在。
4. 再次启动新版，直接进入工作区。打开转换设置，台湾预设、简体来源、台湾目标和台湾词组均已选中。
5. `bash scripts/check-whats-new.sh` 的展示协调器与三语资源检查通过。本次运行的是本地重建包；商店分发包覆盖安装、真机升级与 VoiceOver 朗读未验证。

### 四个内置预设的跨进程对照

从各自版本编译工作区模型、实际偏好键和转换服务，依赖使用相同的锁定版本；每组使用独立 UserDefaults suite。2.3 进程调用 `applyPreset`、`translate`，同步偏好后退出。两个先后启动的新版进程分别读取偏好，不重选预设，断言预设名称、官方配置和结果。三次输出均按 UTF-8 字节比较。这组运行覆盖模型及偏好持久化；上面的兼容配置另有 App 界面实测。

| 2.3 预设 | 迁移后配置 | 三次一致的输出 |
| --- | --- | --- |
| 简体 | `t2s` | 滑鼠里面的软体，著衣与衞生纸。 |
| OpenCC 繁体 | `s2t` | 鼠標裏面的軟件和打印機，用的是信息技術。爲着衛生紙與麪包。 |
| 台湾正体加词组 | `s2twp` | 滑鼠裡面的軟體和印表機，用的是資訊科技。為著衛生紙與麵包。 |
| 香港繁体 | `s2hk` | 鼠標裏面的軟件和打印機，用的是信息技術。為着衞生紙與麪包。 |

简体预设的输入为「滑鼠裡面的軟體，著衣與衞生紙。」；其余三组输入为「鼠标里面的软件和打印机，用的是信息技术。为着卫生纸与面包。」。同机 `check-core.py` 初次使用 Xcode 27.2 的 SwiftPM 默认后端，在链接 OpenCC C++ 符号时失败；切换为 `swift run --build-system native` 后整组通过，包括 72 种旧设置映射。两个版本的完整 macOS App 均通过 Xcode 构建。

### iPhone 覆盖安装

iPhone 17 模拟器，iOS 27.0，同一隔离 Bundle ID，两个 Debug 构建均含分享扩展。旧版在设置中开启台湾词组，首页显示 Custom。使用 App 自带示例，2.3 结果为「滑鼠裏面的矽二極體壞了，導致游標解析度降低。」。

终止 2.3，直接用 `simctl install` 覆盖安装新版。系统分配了新的数据目录路径。首次启动前读回偏好文件，`regionOptions=Taiwan Idiom` 与当日一次转换计数均保留，新来源与目标键仍不存在。首次启动自动显示 2.4 的台湾词组迁移说明，首页变为台湾正体加词组预设。关闭说明后再次填入同一示例，结果为「滑鼠裡面的矽二極體壞了，導致游標解析度降低。」。进程退出后核对新设置 `s / tw / Taiwan Idiom`、旧地域键和已展示版本 `2.4`。本次只启动该模拟器，结束后已恢复 Shutdown。

### iPad 覆盖安装与保留预设

在 iPad Pro 11 英寸（M4）模拟器、iPadOS 27.0，以繁体中文运行上述两个 Debug 包。在 2.3 弹层选「香港繁體」，填入内置示例并转换。覆盖安装后、首次启动前，旧键仍是 `Traditional Chinese / HongKong Standard / Not convert`。新版首次启动正常展示繁体中文的台湾词组迁移说明，并保留首页的「香港繁體」预设。关闭说明后再填入同一示例并转换。

两版结果均为「鼠標裏面的硅二極管壞了，導致光標分辨率降低。」。从两个版本的原文与结果编辑框读回 UTF-8，原文一致、结果逐字节一致，并与独立运行 `opencc -c s2hk.json` 的输出一致。退出后新键为 `s / hk / Not convert`，已展示版本为 `2.4`。模拟器已恢复 Shutdown。

### Release 基准工具复验

在 Apple M4 Pro、macOS 27.2.1、Xcode 27.2 上，原基准 App 的 Release 构建报 `cannot find type 'ChineseConverter' in scope`。基准已改用官方配置，但缺少模块导入；比较器仍校验两个退役配置，无法读取按新配置生成的报告。修复见 `087eb47`，改动限于基准与报告工具。

- `python3 scripts/benchmark-app.py --output <新目录> --packages <已锁定的 SourcePackages> --samples 3 --timeout 300` 成功。三个独立 Release 进程分别通过六个配置的已知答案断言（t2s、s2t、s2tw、s2hk、s2twp、s2hkp），含混合文字、组合字符、CRLF 和 NUL；三份原始报告均通过比较器的同组校验。本次只验工具和输出正确性，未作跨版本耗时比较。
- `python3 Tests/Benchmarks/test_app_performance_report.py` 通过 19 项。当前配置缺失或记录码错误会被拒绝；历史七配置的完整报告仍可读取。
- 私有窗口诊断分别用 `--cycles` 和 `--documents` 准备，两个 arm64 macOS Release 构建通过。本次未执行这两个独立的窗口生命周期场景。

## 关闭标准核对（2026-11-17 更新）

| 关闭标准 | 状态 | 证据 |
| --- | --- | --- |
| 每一种合法组合对应唯一的官方配置；不合法组合不可选或有说明 | 已满足 | 见下文「规则」。`check-core` 逐格核对 4 × 4 组合：10 个合法组合加上地域用词，得到 14 个官方配置；不合法组合会改为默认目标。界面上不合法的目标置灰（见「截图与录像」） |
| 老用户设置迁移后输出不变 | 已满足（含决定的例外） | `check-core` 覆盖旧设置全部 72 种组合；Mac 与 iPhone 各有一份迁移样本。唯一的变化是「OpenCC 繁体＋台湾模式」改为 `s2twp`，按决定在 What's New 2.4 说明 |
| iPhone、iPad、Mac 截图与录像，覆盖键盘操作；VoiceOver 复核或注明未验证 | 部分满足 | 三端截图与录像见下文。Mac 的键盘操作已录像（见「Mac 前台核对」）；**iPad 硬件键盘未测**。**VoiceOver 体验未验证**，只核对了无障碍树里的标签、选中与不可用状态 |
| 四个入口输出一致；三语文案齐全；两端构建通过 | 基本满足 | Mac 上的编辑器、服务、全局快捷键、大文件与批量都用新配置实测通过（见「Mac 前台核对」）；iPhone、iPad 的编辑器已实测。三语文案与两端构建均通过。**iOS 大文件未做实机运行**，服务层由 `check-mobile-file-jobs.py` 覆盖 |

## 规则

| 原文 ＼ 转换为 | 简体中文 | OpenCC 繁体 | 台湾正体 | 香港繁体 |
| --- | --- | --- | --- | --- |
| 简体中文 | — | `s2t` | `s2tw`／`s2twp` | `s2hk`／`s2hkp` |
| OpenCC 繁体 | `t2s` | — | `t2tw` | `t2hk` |
| 台湾正体 | `tw2s`／`tw2sp` | `tw2t` | — | — |
| 香港繁体 | `hk2s`／`hk2sp` | `hk2t` | — | — |

斜线后为开启「地域用词转换」时的配置。「—」是不合法组合，目标置灰不可选。与[官方 Web 版](https://opencc.js.org/converter?config=s2t)一致，日文配置不在本 Issue 范围内（#306）。

- **换原文**：当前目标不合法时改为默认目标。原文为简体时改为 OpenCC 繁体，其他改为简体。
- **地域用词**：只在简体↔台湾、简体↔香港可用，其余组合整行置灰。选择会保留，回到可用组合时恢复。标签随地区显示为「台湾模式」或「香港模式」。
- **对换**：只交换原文和转换为，原文与结果都不动。结果上方提示「设置已更改。此结果使用上次转换时的设置。」，重新转换后消失。地域用词的选择保留。官方 Web 版实测也只交换设置。
- **配置名**：默认隐藏。在设置中打开「显示 OpenCC 配置名」后，显示在选项下方，例如 `OpenCC 配置：s2twp`。
- **预设**：4 个预设保留，分别对应 t→s、s→t、s→tw＋台湾词组、s→hk。其他组合在预设处显示「自定义」。iPhone 与窄布局 iPad 的首页卡片对这些组合直接显示「原文 → 转换为 · 用语」。
- **付费**：新配置免费；主页仍按原规则计次。

### 已保存设置的迁移

新设置存为 `conversionSource`、`conversionTarget`（取值 `s`／`t`／`tw`／`hk`）与 `conversionPhrases`。这两个来源和目标键不存在时，从改版前的 5 个键迁移一次。旧键保留，降级后旧版本仍按自己的设置工作。

| 改版前保存的设置 | 迁移后 |
| --- | --- |
| 繁体，异体字 OpenCC 标准，不转换 | 简体 → OpenCC 繁体（`s2t`） |
| 繁体，异体字 OpenCC 标准，台湾模式（兼容配置） | **简体 → 台湾正体＋台湾模式（`s2twp`）** |
| 繁体，异体字台湾／香港标准，地域用词 Y | 简体 → 台湾正体／香港繁体，地域用词 Y |
| 简体，原文 OpenCC 标准 | OpenCC 繁体 → 简体（`t2s`） |
| 简体，原文台湾／香港标准，地域用词 Y | 台湾正体／香港繁体 → 简体，地域用词 Y |

旧版本分开保存繁体输出与简体输出两边的选项，迁移时只取当时所选目标语言那一边。

### iOS 大文件任务记录

任务记录的 `optionsRawValue` 改存 `recordCode`：

- 改版前已有的配置沿用原来的选项位，例如 `s2t` 为 1、`t2s` 为 2、`s2tw` 为 33，旧版本仍能恢复这些结果。
- 新配置从 4096 起编号，旧版本会拒绝这些记录。
- 退役的两种兼容配置（1025、1089）读为 `s2twp`、`s2hkp`，文件本身不变。

## 实现要点

| 部分 | 做法 |
| --- | --- |
| 模型 | `ConversionConfiguration`（原文、转换为、地域用词）通过 `official` 得到唯一的 `ChineseConverter.Configuration`。各入口只传这一个值 |
| 入口 | 编辑器、服务、全局快捷键（读 `ConversionConfiguration.saved.official`）、Shortcuts、分享扩展、文本操作、Mac 大文件与批量、iOS 大文件都改为传官方配置 |
| 界面 | `ConversionInspector` 依次显示原文、对换、转换为、地域用词与可选的配置名。`SegmentView` 增加 `isEnabled`，用于置灰不可用的选项 |
| iPad 设置弹窗 | 多了对换一行后，竖屏的表单弹窗放不下「地域用词转换」。iPadOS 18 起改为 page 尺寸，iPadOS 15–17 仍可滚动查看。试过让高度贴合内容，但导航栈加滚动视图算不出内容高度，弹窗会缩成一条，所以没有采用 |
| 文案 | 三语新增原文、转换为、对换、配置名，以及 What's New 2.4 的两张卡片。繁体按 dev-standards 的用词表把 configuration 译为「設定」 |

## 自动检查

| 检查 | 结果 |
| --- | --- |
| `python3 scripts/check-core.py --opencc-path <SwiftyOpenCC f5ba852> --defaults-path <SwiftyUserDefaults>`（`8562d4e`） | 21 项 PASS，包括 `PASS: source × target: 10 pairs give the 14 official configurations, invalid targets fall back, swap and new sources; 72 pre-#305 settings migrate once (OpenCC + Taiwan phrases → s2twp); t2tw/t2hk/tw2t/hk2t match OpenCC 1.4.2; iOS job record codes; …` |
| `python3 scripts/check-mobile-file-jobs.py --output … --opencc-path <SwiftyOpenCC f5ba852>`（`a7172f6`） | `PASS: mobile job regression and five fresh-process SIGKILL recoveries`。补跑时发现 `MobileFileJobProbe` 还在调用旧接口，已改为 `s2twp`。可选的 iOS XCTest（`--destination`）未跑 |
| `check-project.sh`、`check-app-language.py`、`check-control-labels.sh`、`check-whats-new.sh` | PASS |
| macOS 与 iOS Simulator 构建 | 按 [CI 参数](../../CI.md) 构建，均 `BUILD SUCCEEDED`。构建在变基前的同内容提交上进行；变基只带进 #344 的 CHANGELOG 与版本号 |

## 实测

环境：

- macOS 27.2.1 (26B131)，Xcode 27.2 (27B52)。
- 模拟器 iOS 27.0：iPhone 17、iPad Pro 11-inch (M4)，竖屏；本次测试前后均为关机状态。
- 参照 OpenCC 1.4.2 命令行（Homebrew）。
- QA 副本由本分支的干净源码构建：Debug，arm64，`CODE_SIGNING_ALLOWED=NO`。使用独立的 Bundle ID，并把版本号设为 2.4，让 What's New 2.4 生效。
  - Mac 副本按项目的沙盒权限 ad-hoc 签名，在后台通过无障碍 API 操作。截图只截 QA 窗口；录像用 ScreenCaptureKit 单窗口录制（沿用 #20 的 [RecordWindow.swift](../issue-20-keyboard-runtime/RecordWindow.swift)），不录光标和声音。
  - 模拟器用 AXe 1.8.0（`--tap-style physical`）点按，从 `workspace-result-editor` 的无障碍值读取结果，录像用 `simctl io recordVideo`。

### Mac

| 配置 | 界面语言 | 原文 | App 结果（与命令行一致） |
| --- | --- | --- | --- |
| `t2tw` | 简体 | 鼠標裏面的衞生紙和著衣，爲了綫上的麪包。 | 鼠標裡面的衞生紙和著衣，為了綫上的麵包。 |
| `t2hk` | 简体 | 鼠標裏面的衞生紙和著衣，爲了綫上的麪包。 | 鼠標裏面的衞生紙和著衣，為了綫上的麪包。 |
| `tw2t` | 简体 | 鼠標裡面的衛生紙和著衣，為了線上的麵包。 | 鼠標裏面的衛生紙和着衣，爲了線上的麪包。 |
| `hk2t` | 简体 | 鼠標裏面的衞生紙和着衣，為了綫上的麵包。 | 鼠標裏面的衛生紙和着衣，爲了線上的麵包。 |
| `s2twp` | 英文 | 鼠标里面的硅二极管坏了，导致光标分辨率降低。（填入示例） | 滑鼠裡面的矽二極體壞了，導致游標解析度降低。 |
| `hk2sp` | 繁体 | 滑鼠的游標不見了，我要搜尋硬碟裏的程式語言資料。 | 鼠标的光标不见了，我要搜索硬盘里的编程语言资料。 |

前四行的样句与 `check-core` 的预期相同。`hk2t` 第一次比对显示不一致，原因是比对脚本取错了预期行（拿了 `tw2t` 的预期）；App 输出与命令行、`check-core` 的预期逐字相同。

**迁移样本**：

1. 另建一个全新容器的副本，用启动参数预置旧设置「繁体，OpenCC 标准＋台湾模式」，即 `targetOptions`、`variantOptions`、`regionOptions`。
2. 启动后为「简体 → 台湾正体＋台湾模式」，预设显示「台湾正体＋台湾词组」，容器里写入了 `conversionSource = s`、`conversionTarget = tw`、`conversionPhrases = Taiwan Idiom`。
3. 改用另一组旧设置（简体输出、原文香港＋台湾模式）重启，仍为 `s2twp`，说明只迁移一次。

### iPhone 与 iPad

1. **iPhone，迁移**：首次启动前在容器里写入同样的旧设置，带 What's New 启动。
   - What's New 2.4 显示两张卡片。
   - 设置迁为 s→tw＋台湾模式，新键已写入。
2. **iPhone，对换与往返转换**：
   - 对换后为 tw→s＋台湾模式（`tw2sp`），预设显示「自定义」。
   - 「填入示例」后用 `s2twp` 转换，得到「滑鼠裡面的矽二極體壞了，導致游標解析度降低。」。
   - 复制结果并粘回原文，再对换（原文与结果不动，出现「设置已更改」），用 `tw2sp` 转换，得回原句「鼠标里面的硅二极管坏了，导致光标分辨率降低。」。各步结果均与命令行一致。
3. **iPhone，XXXL**：原文、转换为改为竖排，可读可点；首页卡片一行放得下。测完恢复默认字号。
4. **iPhone，其他语言**：英文设置页为竖排；繁体显示「OpenCC 設定：tw2sp」。
5. **iPad，繁体**：
   - `s2t` 转换后把结果粘回原文，选 OpenCC 繁體 → 香港繁體（`t2hk`）后转换，结果与命令行一致。这句话经 `t2hk` 不变；能区分 `t2hk` 的样句已在 Mac 上验证。
   - 首页卡片显示「OpenCC 繁體 → 香港繁體」。
   - page 尺寸的设置弹窗完整显示到「OpenCC 設定：t2hk」。

### Mac 前台核对（2026-11-17）

补上前一天因需要 App 在前台而没做的几项。

- **构建**：本分支 `eb522bb` 的应用代码，构建方式同上；QA 副本另以 `-isPro YES` 启动，用于大文件和批量。
- **操作**：在前台通过无障碍接口与合成按键操作。键盘导航和全局快捷键需要的两项系统设置，由维护者临时打开，测完关闭。
- **全局快捷键**：设为 ⌃⌥⇧⌘T，避免与正式版冲突；按键在 session tap 发送，修饰键的按下和松开都用 flags-changed 事件，不留残留。

| 入口 | 配置 | 结果 |
| --- | --- | --- |
| What's New 2.4（前台启动） | — | 弹窗显示两张卡片；点「完成」后 `lastPresentedWhatsNewVersion` 记为 2.4 |
| 服务菜单（TextEdit › Services） | `t2tw`、`hk2t` | 原位替换，结果与命令行一致；撤销可恢复原文 |
| 大文件直接转换（11.5 MB TXT） | `tw2t` | 输出与一次性 `opencc_convert_utf8` 整文件转换的参照逐字节一致（11,534,364 字节）；任务面板显示「台湾正体 → OpenCC 繁体」 |
| 批量转换（2 个 TXT） | `t2hk` | 两份输出都与参照一致；面板显示「OpenCC 繁体 → 香港繁体」，成功 2 个 |
| 全局快捷键（⌃⌥⇧⌘T） | `t2tw`、`tw2t` | 在 TextEdit 里原位替换，结果与命令行一致，剪贴板已恢复；设置页显示「已授予『设备控制和数据访问』权限」 |
| 键盘导航（系统「键盘导航」打开） | s2t → s2twp → s2tw → s2twp → tw2sp → hk2sp | Tab 与 ⇧Tab 依次经过转换预设、原文四个选项、对换、转换为的可用选项和地域用词；置灰的目标被跳过，整行置灰的地域用词也被跳过；空格能选中目标、地域用词、对换和原文 |

**观察**（属于 #341 的范围，只记录）：

- 快捷键事务在 HID tap 发送带 ⌘ 标志的合成按键来模拟 ⌘C／⌘V。完成后，系统的 HID 修饰键状态里会留下 ⌘，直到下一次真实输入。用同样方式单独发一个 F13 也能复现。
- 残留期间，新建的合成事件会继承 ⌘。
- 真实按键不受影响：保持残留时实按一次 Z，该按键事件不带 ⌘，TextEdit 里正常打出 z。
- 目前没有发现用户能感知的影响，只会干扰依赖全局修饰键状态的自动化工具。

## 截图与录像

前后对比中，左边为改动前，取自 develop `e33640e` 的截图；从那时到本分支起点 `15d82aa`，转换设置的界面代码与文案都没有变化。右边为本 PR。

![Mac 转换设置：改动前（左）与改动后（右）](https://github.com/user-attachments/assets/1b5c72b0-93f0-422e-bd19-1f1b255e6677)

![iPhone 转换设置：改动前（左）与改动后（右）](https://github.com/user-attachments/assets/6fba2562-b08b-4223-9533-75470a122bfc)

![iPad 转换设置：改动前（左）与改动后（右，page 尺寸）](https://github.com/user-attachments/assets/c7952745-8f4b-44e4-be83-0305e958d1be)

| 内容 | 截图 |
| --- | --- |
| Mac 英文，s2twp，显示配置名 | ![Mac 英文，s2twp，显示配置名](https://github.com/user-attachments/assets/f2669da4-05e9-479f-a29c-cd9dcbf6e95f) |
| Mac 繁体，hk2sp | ![Mac 繁体，香港繁體到簡體加香港模式（hk2sp）](https://github.com/user-attachments/assets/10f221ed-8cae-4f29-bc11-b42201100caf) |
| Mac 迁移样本 | ![Mac 迁移：旧设置 OpenCC 繁体加台湾模式迁为 s2twp](https://github.com/user-attachments/assets/c234c76a-4d54-466e-9828-32920fb6db4c) |
| Mac 设置开关 | ![Mac 设置：显示 OpenCC 配置名](https://github.com/user-attachments/assets/77b75956-88c3-4e60-b2bc-db65652ddd2a) |
| iPhone What's New 2.4 | ![iPhone What's New 2.4](https://github.com/user-attachments/assets/e3c04c6c-1437-4897-bd35-d22cbd9faadf) |
| iPhone 对换后 | ![iPhone 对换后原文与结果不动，提示设置已更改](https://github.com/user-attachments/assets/15f66337-eae6-4c0d-8e5b-5b7e1fa0fa0f) |
| iPhone XXXL（两屏） | ![iPhone XXXL 转换设置（两屏）](https://github.com/user-attachments/assets/29ca7b0d-d46c-4013-8033-0b3f2aeb6008) |
| iPhone 繁体 | ![iPhone 繁体转换设置，显示配置名](https://github.com/user-attachments/assets/19569e78-fb57-4743-8de7-315f0c74861b) |
| iPad 繁体，t2hk | ![iPad 繁体，OpenCC 繁體到香港繁體（t2hk）](https://github.com/user-attachments/assets/b0396a43-6c77-4193-a57b-64228eb2e680) |

录像：

- [Mac](https://github.com/user-attachments/assets/2004e7c6-0ab4-4005-8892-06b703f3d3f7)（25 秒，只录 QA 窗口）：s2t → s2twp → 填入示例 → 转换 → 对换（tw2sp，文本不动）→ 转换 → hk2sp → hk2t → s2t。
- [iPhone](https://github.com/user-attachments/assets/f5205a81-846b-4fe6-b399-5b3683c69f86)（36 秒）与 [iPad](https://github.com/user-attachments/assets/11fe05c5-7b0f-49d5-a46a-de20e545e73a)（33 秒）：填入示例 → 设置里选简体 → 台湾正体 → 转换 → 对换 → 回到首页。
- [Mac 键盘导航](https://github.com/user-attachments/assets/8f0cba2f-64d1-4cab-8e8f-50a0fdf4bdb1)（22 秒，只录 QA 窗口）：只用 Tab、⇧Tab 和空格，依次选目标、关闭再打开地域用词、对换、换原文，焦点环清晰可见。

Mac 的 What's New 2.4：

![Mac What's New 2.4](https://github.com/user-attachments/assets/64184d09-8f6f-4502-ad25-88104743b193)

截图为 WebP（质量 82），录像为 H.264（CRF 26，15 fps），原件保存在本机。

## 未验证

- **iPad 键盘操作**：硬件键盘没测；Mac 的键盘操作已核对。
- **VoiceOver**：体验未验证。
- **iOS 大文件**：没有实机运行，服务层由 `check-mobile-file-jobs.py` 覆盖。
- **旧系统**：iPadOS 15–17 的设置弹窗没测；最低系统 iOS 15／macOS 12 的验收留在 #16。
- **窗口驱动**：两个 Release 诊断产物已完成编译，运行边界见上方 2026-11-28 记录。

## 观察

「填入示例」总是填简体文本，这是原有行为。原文选为繁体标准时，示例转换后与原文相同。以后可以按原文标准选择示例，不在本 PR 处理。

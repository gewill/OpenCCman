# #305：「来源 × 目标」选择与繁↔繁地区互转

2026-11-16 实现与验证，见 PR [#345](https://github.com/gewill/OpenCCman/pull/345)。跟踪 #301（路线图 M1）。

开发前决定记录在 [#305 评论](https://github.com/gewill/OpenCCman/issues/305#issuecomment-6906814762)。按决定，PR 等 2.3 切出发布分支或上架后再合入 `develop`，目前尚未合入、尚未发布。各项关闭标准的证据见下文，未验证项见文末；是否关闭由维护者决定。

## 关闭标准核对（2026-11-16）

| 关闭标准 | 状态 | 证据 |
| --- | --- | --- |
| 每一种合法组合对应唯一的官方配置；不合法组合不可选或有说明 | 已满足 | 见下文「规则」。`check-core` 逐格核对 4 × 4 组合：10 个合法组合加上地域用词，得到 14 个官方配置；不合法组合会改为默认目标。界面上不合法的目标置灰（见「截图与录像」） |
| 老用户设置迁移后输出不变 | 已满足（含决定的例外） | `check-core` 覆盖旧设置全部 72 种组合；Mac 与 iPhone 各有一份迁移样本。唯一的变化是「OpenCC 繁体＋台湾模式」改为 `s2twp`，按决定在 What's New 2.4 说明 |
| iPhone、iPad、Mac 截图与录像，覆盖键盘操作；VoiceOver 复核或注明未验证 | 部分满足 | 三端截图与录像见下文。**键盘操作未验证**。**VoiceOver 体验未验证**，只核对了无障碍树里的标签、选中与不可用状态 |
| 四个入口输出一致；三语文案齐全；两端构建通过 | 部分满足 | 编辑器已在 Mac、iPhone、iPad 实测，三语文案与两端构建均通过。服务、全局快捷键、Mac 大文件与批量、iOS 大文件与编辑器读取同一个配置，由 `check-core` 覆盖，**未做实机运行** |

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

截图为 WebP（质量 82），录像为 H.264（CRF 26，15 fps），原件保存在本机。

## 未验证

- **键盘操作**：Mac 需要打开系统的「键盘导航」并在前台操作；iPad 的硬件键盘也没测。
- **VoiceOver**：体验未验证。
- **Mac 的 What's New 弹窗**：只在主窗口处于前台时出现；同样的内容已在 iPhone 上核对。
- **其他入口**：服务、全局快捷键、Mac 大文件与批量、iOS 大文件需要前台或文件面板，没有实机运行。
- **旧系统**：iPadOS 15–17 的设置弹窗没测；最低系统 iOS 15／macOS 12 的验收留在 #16。
- **基准工具**：`AppPerformanceAudit` 与窗口驱动已改为新接口，但没有编译运行。

## 观察

「填入示例」总是填简体文本，这是原有行为。原文选为繁体标准时，示例转换后与原文相同。以后可以按原文标准选择示例，不在本 PR 处理。

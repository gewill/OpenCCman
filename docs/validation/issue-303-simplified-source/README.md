# #303：转为简体时按原文来源地区转换

2026-11-03 首轮实现与验证；2026-11-05 补充 [Mac 入口实测](mac-entry-acceptance-20261105.md)，2026-11-07 补充[全局快捷键排查](hotkey-diagnosis-20261107.md)、[独立 QA 快捷键复验](hotkey-isolation-20261107.md)及[服务入口替代方式](services-alternative-20261107.md)。四入口的配置输出均有全文比较证据；独立组合、仅本 QA 运行的本轮四配置复验全部输出正确，原位替换仍均未成功，并再次取得沙箱阻止 AX 焦点窗口读取的日志。现有服务经 TextEdit「服务」菜单和系统服务快捷键调用时，`hk2s` 原位替换成功且可撤销；这是服务功能的调用方式，不计为全局快捷键原位替换通过。进程采样范围和未验证项保留在复验记录中。**不代表 #303 已验收**。下文首轮记录保留其当时范围，最新结论与剩余项见补验记录。

## 规则

- 目标为简体时，可以选择原文标准（OpenCC／台湾／香港）；台湾来源还可以选择是否转换台湾地域用词。对应关系：

  | 原文标准 | 地域用词 | 配置 |
  | --- | --- | --- |
  | OpenCC | （不可选） | `t2s` |
  | 台湾 | 不转换 | `tw2s` |
  | 台湾 | 台湾用词 | `tw2sp` |
  | 香港 | （不可选） | `hk2s` |

- 付费沿用现有预设规则：不新增 Pro 门槛，计次不变（#303 正文、#301 待决策 2 的建议）。
- 不改 SwiftyOpenCC：这四个配置都能用现有 `Options` 表达，流式转换同样支持。

## 实现要点

| 部分 | 做法 |
| --- | --- |
| 设置 | 新增 `simplifiedSourceOptions`、`simplifiedRegionOptions` 两个独立设置，默认 OpenCC／不转换。目标为繁体时用的 `variantOptions`、`regionOptions` 保持原样，**对简体输出仍不生效**，所以老用户无论以前保存了什么，升级后转简体仍是 `t2s`。 |
| 映射 | `ConversionConfiguration.options`：只有台湾来源才使用地域用词；香港来源即使保存了“台湾用词”也按 `hk2s`。 |
| 预设 | 简体预设只在来源为 OpenCC 时显示为“简体中文”，其他来源显示“自定义”。点“简体中文”预设会把来源恢复为 OpenCC；点繁体预设不改动简体来源。繁体预设的判断不受简体来源影响。 |
| 界面 | 目标为简体时显示“原文标准”和“地域用词转换”，后者只在台湾来源时可选；目标为繁体时与以前相同。iPhone、iPad、Mac 共用同一组控件。 |
| 其他入口 | macOS 服务和全局快捷键改为读取 `ConversionConfiguration.saved`，包含简体来源。Mac 批量与大文件沿用工作区的 `configuration`，任务摘要改用 `summaryKeys`，会显示“原文为台湾标准”等。 |
| 文案 | 新增 `source_variant`、`source_from_taiwan`、`source_from_hong_kong`，三语齐全。 |

## 自动检查（本机 Xcode 27.1，macOS 27.2）

| 命令 | 结论 |
| --- | --- |
| `python3 scripts/check-core.py` | PASS（21 项）。新增：<br>• 任意已保存的字形／地域用词组合，目标为简体时都是 `t2s`、显示“简体中文”<br>• 六种来源×用词组合的选项映射，以及“只有台湾来源提供用词转换”<br>• 样例 `滑鼠裡面的軟體，著衣與衞生紙。` 在 `t2s`／`tw2s`／`tw2sp`／`hk2s` 下的输出与 OpenCC 1.4.2 命令行一致，且四者互不相同<br>• 繁体预设不受简体来源影响；简体预设恢复 OpenCC 来源 |
| `check-app-language.py`、`check-control-labels.sh`、`check-project.sh` 及 `scripts/` 下其余检查（`check-whats-new-ui.sh` 需要模拟器参数，未单独运行） | 全部 PASS |
| macOS Debug 构建（CI 参数，arm64 + x86_64，未签名） | BUILD SUCCEEDED |
| iOS Simulator Debug 构建（CI 参数，arm64，未签名） | BUILD SUCCEEDED |

## iOS 模拟器实测

**环境：** 本任务新建的 iPhone 17 和 iPad Pro 11 英寸（M4）模拟器，iOS 27.0，测完已关机。“改前”用当时 `develop` 的界面构建，“改后”覆盖安装到同一台模拟器，以模拟升级。测试包 `org.gewill.OpenCCman.UIValidation`，未签名。截图保存在仓库外，已上传到 PR。

| 路径 | 结果 |
| --- | --- |
| 改前：目标选简体 | “异体字转换”“地域用词转换”整体变灰，无法按来源转简体 |
| 升级后（改前已保存“简体”） | 仍显示“简体中文”预设；样例输出 `滑鼠里面的软体，著衣与衞生纸。`，与 `t2s` 相同 |
| 改后：打开设置 | 显示“原文标准”（默认 OpenCC）；“地域用词转换”变灰 |
| 台湾标准 + 台湾用词 | 预设显示“自定义”；输出 `鼠标里面的软件，着衣与衞生纸。`，复制后从剪贴板读回与 `opencc -c tw2sp` 逐字节相同 |
| 台湾标准 + 不转换 | 输出 `滑鼠里面的软体，着衣与衞生纸。`，与 `tw2s` 逐字节相同 |
| 香港标准 | “地域用词转换”变灰（保留上次的选择但不生效）；输出 `滑鼠里面的软体，著衣与卫生纸。`，与 `hk2s` 逐字节相同 |
| XXXL 字号 | 设置面板完整可读、可点；“原文标准”自动改为竖排 |
| 繁体中文界面 | “原文標準”“地域用詞轉換”等文案正确。默认字号下“原文標準”是竖排，现有的“異體字轉換”在同样条件下也是竖排，是 `SegmentView` 原有的宽度判断，不是本次改动引入的 |
| iPad | 改前两项变灰；改后显示“原文标准”并可选台湾标准 |

## 商店描述与 What's New 草稿（下一版，提交时另走发布流程）

把 2.2 描述中的限制句替换为：

- 简体：简体输出可按原文选择 OpenCC、台湾或香港繁体；台湾繁体还可以把台湾词组转回大陆常用词，例如「軟體」转为「软件」。
- 繁体：簡體輸出可依原文選擇 OpenCC、臺灣或香港繁體；臺灣繁體還能把臺灣詞組轉回中國大陸常用詞，例如「軟體」轉為「软件」。
- 英文：When converting to Simplified Chinese, choose whether the source is OpenCC, Taiwan or Hong Kong Traditional; Taiwan text can also have Taiwan phrases converted back to Mainland wording, such as 軟體 to 软件.

What's New 卡片草稿：

- 标题：按原文地区转为简体／按原文地區轉為簡體／Simplified output by source region
- 正文：转为简体时可以选择原文来自台湾或香港，台湾原文还能转换地域用词。／轉為簡體時可以選擇原文來自臺灣或香港，臺灣原文還能轉換地域用詞。／When converting to Simplified Chinese, choose whether the text is from Taiwan or Hong Kong, and convert Taiwan phrases too.

## 未验证（不计为通过）

- **Mac：** 设置侧栏的前后截图与切换录像；macOS 服务、全局快捷键、Mac 批量与大文件在简体来源设置下的实际运行。代码路径已改为读取同一份设置，`check-core` 覆盖了映射，但没有在 Mac 上实际运行这几个入口。
- **录像：** iPhone／iPad 只有截图，没有切换过程的录像。
- **其他：** VoiceOver 体验未验证；最终签名包与 iOS 15 实机未运行。
- **商店与 What's New：** 只是草稿，没有写入 `WhatsNew.swift`，也没有提交 App Store。

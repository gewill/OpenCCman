# #29：系统分享菜单中的文字转换扩展

2026-11-02。本页记录首版的规则、实现、自动检查和 iOS 模拟器实测。**不代表 #29 已验收**：真机、最终签名包、iPad 窄窗口和 VoiceOver 都还没有验证，见文末。

## 已确认的规则

维护者于 2026-11-02 确认，原文见 [#29 评论](https://github.com/gewill/OpenCCman/issues/29#issuecomment-6567851472)：

- **扩展类型：** iOS／iPadOS 的 Action 扩展。Mac 继续用已有的服务菜单。
- **资格：** 免费不限次，不占每日免费次数，与 #26 的 Shortcuts 动作一致。不新增 App Group。
- **输入上限：** 10 MiB（UTF-8 字节），与编辑器、Shortcuts 一致；超出时提示，不截断。
- **配置：** 简体、繁体、台湾、香港四个预设，扩展记住自己上次的选择。
- **结果交付：** 复制或再分享；宿主支持时，由用户点“完成”把结果交回宿主，从不自动覆盖。取消后原内容不变。
- **系统：** 部署下限保持 iOS 15。

## 为什么用 Action 扩展，以及与 Shortcuts 的区别

| 需求 | Action 扩展（本 PR） | Shortcuts 动作（#26） | Share 扩展 |
| --- | --- | --- | --- |
| 出现在分享菜单 | 安装后自动出现，入口名“简繁转换” | 用户要先自建捷径，并开启“在共享表单中显示” | 自动出现 |
| 选择配置 | 面板里点选，记住上次的选择 | 每个捷径固定一个预设，或运行时询问 | 可以 |
| 把结果交回宿主 | 可以（`completeRequest(returningItems:)`，宿主决定是否使用） | 捷径能接后续动作，但不能写回宿主原文 | 不能 |
| 系统要求 | iOS 15 | iOS 16（App Intents） | iOS 15 |

Shortcuts 不能满足的三条路径：
- **iOS 15 用户：** 用不了 App Intents。
- **不想自建捷径的用户：** 分享菜单里没有现成的入口。
- **宿主支持回传的场景：** 捷径无法把结果交回宿主。

上表中 Shortcuts 一列来自 #26 的实现（`ConvertTextIntent.swift`）和系统行为，这次没有在模拟器上实际建捷径对比。

## 实现要点

| 部分 | 做法 |
| --- | --- |
| Target | 新增 `OpenCCmanTextAction`（`com.apple.product-type.app-extension`，`com.apple.ui-services`），只在 iOS SDK 下嵌入 App（`platformFilter = ios`），macOS 构建不含扩展。激活规则只接受文字（`NSExtensionActivationSupportsText`）。 |
| 复用 | 直接编译主 App 的 `ChineseConversionService`、`ConversionConfiguration`、`TextFileService`、`FileConversionPolicy` 和 `Localizable.strings`，OpenCC 词库随扩展打包（约 1.3 MB）。 |
| 读取输入 | `TextActionInput`：<br>• Safari 选中的文字不能转成 `NSString`，改用 `loadItem` 读取<br>• 文件 App 传来的是没有文件名的 `public.file-url`，在 `loadFileRepresentation` 回调里先查大小、再按 UTF-8 解码<br>• 字符串、富文本、UTF-8 数据各有对应处理<br>• 都沿用编辑器的 10 MiB 上限和 UTF-8 规则（去掉 BOM，非法字节报错） |
| 转换 | `TextActionModel.convertInChunks`：按 256 KiB 分块送入 OpenCC 流式接口，结果与整段转换逐字节相同。切换预设会重新转换，只有最新一次的结果会显示。 |
| 界面 | 系统 `Form`：预设单选、结果预览（只显示前 3,000 个字符，放在限高的滚动区里）、字符数、复制结果、分享结果，“取消／完成”按钮在导航栏。跟随系统深浅色和字号。 |
| 资格 | 扩展不读购买状态和额度，由 `check-text-action.sh` 检查。 |
| Bundle ID | App 和扩展都由项目级 `OPENCCMAN_BUNDLE_ID` 派生，扩展为 `.TextAction`。QA 和 CI 脚本统一改为覆盖 `OPENCCMAN_BUNDLE_ID`，原因见 [CI 说明](../../CI.md#qa-构建的-bundle-id)。 |
| 隐私 | 扩展带自己的 `PrivacyInfo.xcprivacy`（与 App 相同的 API 理由），不收集数据，不联网。 |

## 自动检查（本机 Xcode 27.1，macOS 27.2）

| 命令 | 结论 |
| --- | --- |
| `bash scripts/check-text-action.sh`（新增，已接入 App Regression） | PASS：<br>• 不引用购买和额度<br>• 只嵌入 iOS、只接受文字<br>• 用到的文案三语齐全，扩展显示名三语齐全<br>• 版本号、构建号、最低系统与 App 一致<br>• Bundle ID 由 `OPENCCMAN_BUNDLE_ID` 派生，脚本里没有 `PRODUCT_BUNDLE_IDENTIFIER=` 覆盖 |
| `python3 scripts/check-core.py`（新增 `TextActionChecks`） | PASS：<br>• 在免费次数已用完的状态下运行，次数不变<br>• 四个预设的结果与 App 预设相同，覆盖 CRLF、CR、NUL、U+2028/2029、Emoji、组合字符<br>• 记住预设，未知值回到默认<br>• 连续切换预设时只保留最新结果<br>• 分块大小为 1、2、7、4,099 字节和 256 KiB 时，结果都与整段转换相同<br>• 预览不切断字形<br>• 正好 10 MiB 接受，多 1 字节拒绝；空输入和非法 UTF-8 给出提示 |
| `check-project.sh`、`check-control-labels.sh`、`check-app-language.py`、`check-pro-access.sh`、`check-quota.sh`、`check-whats-new.sh`、`check-batch-conversion.sh`、`check-workspace.sh`、`check-control-sizing.sh`、`CheckScriptChecks.py`、`DuoBuildChecks.py` | 全部 PASS |
| macOS Debug 构建（CI 参数，arm64 + x86_64，未签名，`OPENCCMAN_BUNDLE_ID=…PRValidation`） | BUILD SUCCEEDED，App 内没有 PlugIns |
| iOS Simulator Debug 构建（CI 参数，arm64，未签名） | BUILD SUCCEEDED；App 为 `org.gewill.OpenCCman`，扩展为 `org.gewill.OpenCCman.TextAction`；扩展源码没有警告 |

## iOS 模拟器实测

**环境：** 本任务新建的 iPhone 17 模拟器，iOS 27.0（UDID `C5DDDE0A-…`），测完已关机。QA 构建使用 `OPENCCMAN_BUNDLE_ID=org.gewill.OpenCCman.UIValidation`，未签名。测试页由本机 `127.0.0.1` 提供，测试文件放在模拟器的“我的 iPhone”里。截图保存在仓库外，已上传到 PR。

| 路径 | 结果 |
| --- | --- |
| Safari 选中文字 › 共享 | 分享菜单出现“Convert Chinese Text／简繁转换”，图标为单色字典。默认按“繁体”转换。<br>**修复前**：显示系统错误 “Could not coerce an item to class NSString”（Safari 的项目不能转成 `NSString`），且图标是黑色方块 |
| 切到“台湾”并复制 | 读回剪贴板：`滑鼠裡面的矽二極體壞了，導致游標解析度降低。…` |
| 文件 App 分享 `sample.txt` | 结果为 `滑鼠\r\n頭髮\r臺灣 軟體\n👨‍👩‍👧‍👦 é\n`。从剪贴板逐字节读回：CRLF、单独 CR、U+2028、零宽连接符、组合重音都保留。<br>**修复前**：提示“没有可转换的文字”（文件 App 只给出没有文件名的文件 URL） |
| 文件 App 分享正好 10 MiB 的文件 | 转换成功，显示 3,599,628 个字符和“仅显示前 3,000 个字符”。复制后读回，字符数和行数（156,503）与原文一致。<br>**修复前**：预览不限高，复制、分享按钮被挤到很长的列表底部 |
| 10 MiB 内存（`footprint` 每 0.3 秒采样） | 整段转换：峰值 157 MB。改为分块转换后：峰值 96 MB，转换完成后稳定在 95 MB，复制后不变。Action 扩展的内存上限没有公开数值，模拟器也不会强制执行，所以这个结果只说明内存用量下降，不能证明真机上不会被系统终止 |
| 多 1 字节的文件 | 提示“文本超过 10 MiB 导入上限”，“完成”不可点 |
| 非法 UTF-8／空文件 | 分别提示“文件不是有效的 UTF-8 编码…”和“没有可转换的文字”，“完成”不可点 |
| 取消 | 回到文件 App 的分享菜单，源文件哈希不变 |
| 完成 | 面板关闭。文件 App 不接收回传结果，源文件哈希不变，没有被覆盖 |
| 记住预设 | 重新打开扩展时仍是上次选的“台湾” |
| 深色模式 + XXXL 字号 | 内容完整可读；标题按系统导航栏的规则截断为 “Convert Chines…” |
| 简体中文系统 | 入口显示“简繁转换”；界面文案、预设名、提示都是中文 |
| 分享结果 | 在扩展里打开系统分享菜单，可以继续交给“拷贝”“保存到文件”等 |

各宿主的回传能力：Safari 和文件 App 都不使用 Action 扩展回传的文字，“完成”后原内容不变。本次没有找到会把结果写回原文的宿主，所以“回传替换”这一项还没有实际看到效果。

## 未验证（不计为通过）

- **真机与签名包：** 没有在真机上运行，也没有验证最终签名包。真机上的内存上限和终止行为要在真机上用接近 10 MiB 的文本复测。
- **Xcode Cloud：** 新 target 需要新的 App ID `org.gewill.OpenCCman.TextAction` 和描述文件。Xcode Cloud 使用自动签名，是否能自动注册还没有验证，第一次打包前需要确认。
- **回传替换：** 没有找到会接收 Action 扩展回传结果的宿主。
- **其他：** iPad 窄窗口、VoiceOver、繁体中文界面截图、iOS 15 实机运行都没有做。
- **Shortcuts 对比：** 上表是依据实现和系统行为整理的，没有在同一台设备上实际建捷径对比。

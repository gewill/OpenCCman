# #27 转换前后差异：实现与本机验收

日期：2026-11-01。状态：本地实现、双端构建及下述交互通过；**不是 Issue 关闭或发布验收**。

后续 [iPad 窄窗口底缘点按复核](ipad-edge-taps.md) 已补齐默认字号／XXXL 的可见底缘导航与裁切负面对照。未发现需修复的 App 命中缺陷；历史偶发失败的唯一原因仍未证实，以下原始记录不回写为通过。

后续 [导出、分享与最小 Mac 窗口补验](local-export-acceptance.md) 补齐 Mac/iPhone 实际保存文件、原生复制及选中词分享，以及当前构建 Mac 最小窗口 100%／150% 导航；并修复 Debug 代码载荷的构建证据缺口。下文未验清单保留原轮次边界，最新范围见补验记录。

后续 [iOS 原生拼音组合与 iPad 文件导出补验](ime-ipad-acceptance.md) 已补真实 marked text 的失效／选词／重转，以及 iPad 本地文件保存读回；整篇分享尝试仍未通过。

## 源码与环境

- 分支 `codex/27-conversion-diff`，起点为当时最新 develop `4da54d40f525182e2847f4c4106edef96cfc50a7`。实现提交为 `842c6074cf96616563643b2008372ea1edadfc60`；其后的本文来源补记不改变实现。
- 构建和测量发生在未提交工作区；基线 SHA 不能单独代表产物。外部 `20261101-app-build-04/report.json` 保存完整 diff SHA-256、新文件哈希、依赖锁、命令、构建设置及二进制哈希。整理本文前已逐项比较当前源码与该报告，全部一致；此后仅整理证据文档。
- 最终构建的受控文件 diff SHA-256：`378abcceddf271412a80e6d81580dbfdce2e0f1427f0e3b90d73f8e81740d409`；算法 SHA-256：`3af2626703801c822e36b26d7d27be5d091c2ee9317fe7a269d533b57b91b8da`。
- Mac16,7 / Apple M4 Pro / 48 GiB；macOS 27.2（26B123）；Xcode 27.1（27A9275），进程级工具链 `/Applications/Xcode.app/Contents/Developer`。
- SwiftyOpenCC 锁定 `564b094b2b69f2c1e907fa3d89fe6845469a4e4e`；OpenCC 子模块 `025f371dc76b598d77384fbdab90c937471844d8`。基准使用独立 checkout，不使用本机另一 revision 的工作区或 Homebrew OpenCC 替代 oracle。
- QA Bundle ID `org.gewill.OpenCCman.WhatsNewUITests`；截图、录像及文稿均在仓库外。没有替换正式 App，没有更改部署下限、依赖或额度规则。

## 设计与范围

- `ConversionDiffSnapshot` 是不可变的 UUID / 原文 / 结果 / 配置快照，泛型配置为后续标注复用留出接口；未实现 #307。成功转换才生成快照。编辑原文、改变配置、清空、导入开始／替换、转换取消及窗口生命周期取消都会失效。外部 Services 不提供配置来源，不伪造其快照。
- 显示默认关闭。开启才以 `Task.detached` 计算；UTF-16 映射也在后台准备。取消 worker 和发布任务，并同时检查 generation 与 snapshot ID；过期任务不能覆盖新稿。默认关闭时仍保存转换快照，但不运行算法。
- 算法以 Swift `Character` 为最小单位；字节精确比较避免把规范等价的不同表示吞掉。hunk 使用原文／结果成对半开范围，区分替换、插入、删除；不拆 Emoji 或组合字符。
- 相邻改动合并；两处之间只有一个相同汉字时也合并，使“硅二极管 → 矽二極體”中的“二”留在同一处。这是显示分组启发式，不是 OpenCC 字典命中边界或分词。不会跨空白、标点或 Emoji 做这种桥接。
- 完整分隔符序列相同时，以空白、换行、NUL、BOM 对应位置为硬锚点；否则一般对齐。不归一化、删除或补写分隔符。CRLF 在 Swift 中为一个 Character，仍保留两个原始字节。
- 用户已确认容量：**两侧各 50,000 字形簇、5,000 处、累计 4,000,000 个 LCS 表单元**。任一超限整次返回 `notComputed`，UI 显示文稿过大提示；不返回截断结果。即使字符数未超限，复杂无分隔文稿也可能先用完对齐预算。限额来自下述真实语料测量；真机验证仍待进行。
- Mac 在 NSTextView 背景绘制；iOS 在原 UITextView 上加入不拦截触摸的几何装饰层，不替换原编辑器／delegate／TextKit。使用背景及下划线，当前处加边框，空范围画定位标记。正文及 attributed storage 不加入差异标签。
- 显示／隐藏不主动修改选择；只有导航 token 变化时同步两侧选区并滚到可见位置。marked text 存在时跳过导航／绘制。窄窗口上下布局可通过外层滚动分别查看两侧。
- 菜单与快捷键：⌘⇧D 显示／隐藏，⌘⌥⇧[／] 上一处／下一处。限定到拥有当前窗口的模型。未改变 ⌘T、⌘,、⌘P、⌘⌥1/2、⌘⌥I。
- 三语文案、VoiceOver 标签及计数已提供；VoiceOver 实际朗读未验。复制／分享／导出继续读取纯文本，exportSnapshot 语义不变。大文件直接转换没有全文预览或差异入口。

## 可重复检查与构建

以下命令均实际运行、退出 0；表中为真实输出或其范围。完整日志保存在本机证据索引。

| 命令 | 实际 PASS 结论 |
| --- | --- |
| `bash scripts/check-conversion-diff.sh` | `PASS: Character boundaries, literal restoration, phrase grouping, separators, generation rejection, cancellation and complete-or-not-computed limits` |
| `bash scripts/check-project.sh` | `PASS: parsed 80 Swift sources and 6 localization files` |
| `python3 scripts/check-app-language.py` | `PASS: BCP-47 tags, AppleLanguages writes and removal, legacy selection fallback and tag matching`；启动参数语言优先级也 PASS |
| `bash scripts/check-control-labels.sh` | `PASS: released control labels resolve English, Simplified/Traditional Chinese, underscore locales, live locale changes and missing-key fallback` |
| `bash scripts/check-workspace.sh` | `PASS: workspace hysteresis, mobile width transitions, user intent, inspector budget, accessibility, window isolation, ratio recovery and pane minima` |
| `bash scripts/check-workspace-editor.sh` | `PASS: complete text, typing/binding, undo/redo, marked text echo, selection, independent undo, disabled/read-only and external replacement`；有界布局 PASS，2,720,000 字符远端内容不预排版 |
| `bash scripts/check-control-sizing.sh` | `PASS: upstream 30→44 reproduction; Mac icon 28, text 28, primary 32, segment 28, switch 28 and multiline growth`；原生窄／宽分段控件、语言切换和选择稳定性 PASS |
| `python3 scripts/check-core.py`（额外） | 全部 PASS；包含真实锁定 OpenCC oracle、换行／NUL／BOM 保留、还原、真实模型异步失效、默认关闭、额度／导出不变、过期 worker 丢弃与超限 UI 状态 |
| `python3 scripts/check-introspection.py`（额外） | 原生 source/result、只读结果、TextKit、内容样式和旧版本 predicate 控制 PASS |
| `git diff --check` | 退出 0 |

新纯逻辑检查覆盖相同文本、单字、长度变化词组、插入／删除、Emoji、组合字符、规范等价但字节不同、特殊分隔符、441 组短序列、逐字节还原、取消（含运行中取消）、过期令牌、两侧字符／表单元／hunk 超限。已加入 `.github/workflows/app-regression.yml`。原生编辑器回归另断言装饰不改正文、attributed storage、已有选区或 undo；同一导航 token 不重复抢选区，marked text 不被导航覆盖。

按 `docs/CI.md` 使用现有双端入口：

```bash
python3 scripts/build-duo-validation.py \
  --developer-dir /Applications/Xcode.app/Contents/Developer \
  --output "$HOME/Library/Application Support/Codex/ui-evidence/OpenCCman/27-conversion-diff/4da54d4/20261101-app-build-04" \
  --derived-data "$HOME/Library/Caches/Codex/OpenCCman-27-diff"
```

输出目录必须是新目录，重跑时换目录名。最终 `report.json` 为 `passed`：macOS Debug arm64+x86_64、iOS Simulator Debug arm64 **均构建成功**；产物下限 macOS 12 / iOS 15，iPhone+iPad 设备族不变。命令包含锁定依赖、QA Bundle ID、非分发签名参数及该工具链所需 flags，原始完整命令在报告中。首次重复 deinit 编译错误已修复；第二次构建期间测试源码变化被来源校验拒绝，未算最终通过；03/04 冻结源码构建通过，以 04 为准。没有将本机构建写成远端 CI 或签名包通过。

## 性能方法与结果

```bash
python3 scripts/benchmark-conversion-diff.py \
  --output "$HOME/Library/Application Support/Codex/ui-evidence/OpenCCman/27-conversion-diff/<source-sha>/<new-run>" \
  --opencc-path "$HOME/git/MyApps/SwiftyOpenCC" \
  --character-cap 50000 --cell-cap 4000000 --hunk-cap 5000
```

可省略本地依赖路径，由脚本从工程锁定 URL 读取 revision。语料为仓库 README 和 docs 顶层 Markdown 按文件名排序的真实文稿，不循环填充；包含中英文、代码和换行，配置为台湾正体＋台湾词组。脚本保存语料、源码／依赖哈希、构建日志、逐次输出、context/results JSON。Release 独立程序每个规模 3 个新进程；单次上限 30 秒，构建上限 600 秒；还原失败立即失败。小规模是语料前缀，不能代表所有文本分布。

最终独立测量 `20261101-repeatable-final`：

| 原文／结果字形簇 | 结果 | 三次耗时 | 进程峰值内存 |
| --- | --- | --- | --- |
| 10,000／10,003 | 381 处，逐字节还原通过 | 1.140–1.361 ms | 51.55–52.94 MiB |
| 49,000／49,129 | 3,256 处，逐字节还原通过 | 7.835–8.234 ms | 54.38–55.70 MiB |
| 50,001／50,133 | `notComputed`，无部分结果 | 1.028–1.157 ms | 52.23–54.22 MiB |

耗时覆盖后台任务调度与差异计算，不含 OpenCC 转换和之后还原断言。getrusage 内存是包含转换器／运行时的进程峰值，不是差异独占内存，也不是 App 内存。

App Debug 04 使用同语料实际转换和显示。仅隔离 QA Bundle ID 加 `-qa-diff-metrics` 时启用 MainActor 8ms 请求间隔、2 秒采样探针；不记录稿件内容，正式 App／Release 不启用。

| App 场景 | 主线程最大调度间隔／样本数 | App RSS 样本 | 交互结果 |
| --- | --- | --- | --- |
| Mac 150%，10,000 字 | 37.384 ms / 217 | 200.58 MiB | 381 处显示，操作完成 |
| Mac 150%，49,000 字 | 60.818 ms / 216 | 212.19 MiB | 3,256 处；最后一处同步选中，两侧滚到末端 |
| iPad A16 / iOS 27.0 模拟器，375×532，默认字号，49,000 字 | 56.494 ms / 202 | 显示后 596.64 MiB；末处导航后 631.34 MiB | 3,256 处；最后一处两侧原生选区为 48945/49074、长度各 1，contentOffset.y 为 39488/39744 |

RSS 是 ps 的主机进程瞬时值，不是峰值、增量或真机内存。Mac 10k 的 2 秒采样期间曾查询 AX，49k 和 iPad 49k 等探针结束后才查询 AX／调试器，条件差异保留。探针不测绘制帧时；这些非零间隔不能写成“完全无卡顿”。本次操作可完成，没有发现持续失去响应；未设定或宣称真机帧率／内存 SLA。约 597–631 MiB 的模拟器进程 RSS 需要真机后续评估，不能据此直接降低或提高已确认容量。

真实转换样本：

```text
原文：鼠标里面的硅二极管坏了，导致光标分辨率降低。
结果：滑鼠裡面的矽二極體壞了，導致游標解析度降低。
```

## 实际界面路径与证据边界

| 环境 | 已实际完成 |
| --- | --- |
| Mac（最终 Debug 04） | 示例转换→默认关闭→⌘⇧D→下一处 1/3→上一处回绕 3/3→Copy Result→粘贴回原文，逐字相同纯文本，结果清空并提示重新转换；设置改变后差异立即失效且旧结果／导出语义保留；100% 常用宽窗、上下／左右布局；49k 末处双侧定位 |
| Mac（较早 Debug 02） | 最小 300×412 窗口 100%／150%、宽窗 150%、双侧高亮、导航和复制失效；02 与最终之间增加原生装饰字节一致性保护和 DEBUG 探针，不把这些旧截图冒充最终构建 |
| iPhone SE3 / iOS 18.6，375×667（最终 Debug 04，早期另有 02 记录） | 默认及 XXXL 竖屏；实际外层滚动使导航可见；下一处 1/3、上一处 3/3；Copy Result 读取剪贴板逐字节匹配；Paste Text 后原文等于输出、结果清空、差异提示重新转换 |
| iPad A16 / iOS 27.0（最终 Debug 04） | 全屏 820×1180 双侧高亮；原生 Windowed Apps 缩至 375×532；默认字号导航 1/3、3/3，复制纯文本再粘贴失效；XXXL 控件完整、滚动后导航 1/3、3/3；49k 末处两侧同步定位 |

iPad 自动化曾失败：27.0 不支持 devicectl appResize，安装的 27.1/27.2 runtime 不支持 A16；改用系统原生窗口 resize。AX 返回窗口内坐标，而触摸使用屏幕坐标；经调试器只读查到窗口原点 (222.5,266.5) 后校正。XXXL 靠近底缘的若干点按未改变计数，进一步滚动使控件完整进入中部后点击通过；没有把失败动作当通过，也尚不能证明底缘失效源于 App。窄窗截图是 LLDB 调用 UIWindow `drawViewHierarchy` 的实际窗口渲染快照，只含 QA App，不含 OS 窗口边框或其他 App；不是设备全屏截图或连续视频。

本机证据根目录：
`~/Library/Application Support/Codex/ui-evidence/OpenCCman/27-conversion-diff/4da54d4/`。
这是开发机索引，不是远程附件，不应直接复制到 Issue/PR 当图片 URL。

- `20261101-checks-final/`、`20261101-editor-final.log`、`20261101-core-integrated-02.log`、`20261101-introspection-final.log`：原始检查结论。
- `20261101-app-build-04/report.json`、`built-source.patch`：最终构建及源码绑定。
- `20261101-repeatable-final/`：可重跑性能基准的全部来源／数据。
- `20261101-ui/mac/final-flow.mp4`：最终构建单 QA 窗口实际录制，包含转换、显示、导航、复制和原文失效；无音频。`final-100-wide-before/after.png`、`final-100-stacked.png`、`final-49000-tail.png`、`final-settings-invalidated.png` 为截图。
- `20261101-ui/iphone/final-flow.mov`：最终构建的真实操作录像；`final-before.png`、`final-after.png`、`final-xxxl-next.png`、`final-copied.txt`、`final-paste-invalidated.json` 为最终证据。早期 `flow.mov` 包含提示／无效滚动，`show-diff.png` 含评分弹窗，不能作为最终功能截图。
- `20261101-ui/ipad/paired-wide.png`、`narrow-next-window-render.png`、`xxxl-previous-confirmed-window-render.png`、`49000-last-window-render.png` 及相应 JSON；`49000-native-state-corrected.txt` 是最后一处真实 UITextView 选区／滚动偏移。
- `evidence-index.json` 保存媒体哈希、构建来源和边界；`simulators-final.json` 记录本任务模拟器收尾。媒体的远程附件链接见 [PR #312](https://github.com/gewill/OpenCCman/pull/312)；六个已上传附件的公开下载字节与本地 SHA-256 相同，正文已回读确认不含本地路径。Mac／iPhone 录像均完整解码并在 QuickTime 从头播放至结尾。本记录不把本地检查写成远端 CI 结果。

## 未验证及不关闭的项目

- 真机 VoiceOver 朗读与完整辅助体验、真机性能、签名／分发包；iOS 15 和 macOS 12 实际运行（最低系统不变与构建通过不等于运行通过）。
- 分享面板和文件提供方实际导出流程本轮未重复验；模型回归证明 exportSnapshot 不变，Mac/iPhone/iPad 实际复制／粘贴证明相应路径纯文本，不能外推分享／所有提供方。
- iOS 原生输入法实际 marked text 操作未人工复验；macOS 原生自动检查覆盖其保护，不能外推三端全部输入法。iPhone 最终 Debug 04 已补跑默认／XXXL、导航、复制及粘贴失效。
- App 帧时间／长期内存及真机近上限尚未达成性能验收；iPad 窄窗底缘点按失效原因仍有工具／系统坐标边界，滚动后路径已通过。
- 本次 PR 即使合并也不自动关闭 #27；后续以真实设备／签名包的独立证据补齐关闭标准。

## PR #312 检查补记

2026-11-01 读回 HEAD `63cba61` 的 [App Regression](https://github.com/gewill/OpenCCman/actions/runs/41245607052) 失败，原因是既有性能工具测试把原生编辑器构造类名写死为 `NSTextView`。本功能使用其子类 `WorkspaceDiffTextView`，而基准变体仅移除滚动观察器的行为没有改变。更新构造断言并明确验证 `NSTextView` 继承，保留“恢复观察器后源码逐字相同”断言；未改 App 实现或削减验证条件。

实际执行 `python3 -m unittest discover -s Tests/Benchmarks -p 'test_*.py'`：111 项，全部 OK；`git diff --check` 通过。此修复是测试适配，不能用本地结果代替后续当前 HEAD 的 CI 与审核门槛。

双路审查随后发现 `prepare_textkit2_no_anchor` 也以旧类名作为注入锚点，影响三个既有 `--textkit2-*` 私有诊断入口。已同时更新匹配与输出，保留 `WorkspaceDiffTextView` 子类，仅切换其 TextKit 构造；新增三个变体的准备阶段检查，核对无旧布局构造、正确 keeper 以及归档 single-target 内容。完整 Python 工具检查增至 112 项，全部 OK。原生 `check-workspace-editor.sh` 也通过，新增实际断言 `WorkspaceDiffTextView(usingTextLayoutManager: true)` 在差异关闭时保留 TextKit 2 与正文。未重跑整套私有性能矩阵，不据准备检查宣称其性能已复验。

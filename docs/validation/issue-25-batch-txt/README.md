# #25：Mac 批量 TXT 转换

2026-11-01。本页记录首版实现的规则、自动检查、性能测量和本机 Mac App 界面运行。**不代表 #25 已验收**：最终签名包、最低系统和 VoiceOver 都还没有验证，见文末。

## 已确认的规则

维护者于 2026-11-01 确认，原文见 [#25 评论](https://github.com/gewill/OpenCCman/issues/25#issuecomment-6557078369)：

- **平台：** 首版只做 Mac。
- **资格：** 仅限 Pro，不消耗每日免费次数。
- **容量：** 一批最多 100 个文件，单个文件不超过 1 GiB。
- **失败：** 单个文件失败后继续处理下一个。
- **命名：** 重名时按 Finder 方式自动编号，从不覆盖已有文件。

## 实现要点

| 部分 | 做法 |
| --- | --- |
| 入口 | 「文件 › 批量转换 TXT 文件…」（⌘⇧O）。往窗口拖入 2 个及以上文件时，Pro 用户进入批量列表，免费用户看到 Pro 提示；拖入单个文件的行为不变。<br>Finder 拖入的项目在 SwiftUI 里只带 `public.plain-text`，没有文件地址和文件名，所以改用 `loadInPlaceFileRepresentation` 取得原始文件。只要有一项拿不到原始文件，整次拖放就被拒绝并给出提示，不会悄悄少处理文件。 |
| 队列 | `BatchConversionQueue` 是纯逻辑，按选择顺序逐个处理。超过 100 个时整批拒绝，不截断。非 TXT、超过 1 GiB 或重复选择的文件标为略过并写明原因。 |
| 任务槽 | `MacBatchConversionCoordinator` 在整个 App 中只有一个实例。它与 `MacLargeFileCoordinator` 共用同一个文件任务槽，多开窗口也不能并行。 |
| 转换 | 每个文件都调用 `StreamingTextFileService.convert`，并传入新增的 `replacingExisting: false`。选好文件名后，如果别的程序抢先占用了同名，服务返回 `destinationChanged`，协调器换下一个编号重试，最多 3 次，原有文件不会被替换。 |
| 命名 | 文件名格式为 `<原名>-converted.txt`，与单文件导出一致。按大小写和 Unicode 正规化不敏感的方式比较是否重名。已存在的项目按 lstat 判断，符号链接也算已占用。 |
| 资源 | 队列只保存 URL。一次只打开一个源文件；输出文件夹的安全作用域在整批期间保持，结束后释放。 |
| 资格 | 选择文件夹前和选好之后各校验一次 Pro；一批开始后不再中断。协调器不引用 `TestNumbersPerDayManager`，由 `check-batch-conversion.sh` 检查。 |
| 文件夹问题 | 开始前检查文件夹是否可写，只读文件夹直接拒绝。转换中文件夹丢失或变成不可写时，当前文件和剩余文件都标为失败，并写明原因。 |
| 取消、关窗、退出 | 取消会停止当前文件，并把未开始的文件标为已取消，已保存的文件保留。关闭发起窗口或退出 App 时，沿用单文件任务的语义：先完成清理，再释放任务槽。 |

## 自动检查（源码 `99e8c83`，本机 Xcode 27.1 / Swift 6.4，macOS 27.2）

| 命令 | 结论 |
| --- | --- |
| `bash scripts/check-batch-conversion.sh` | PASS：准入规则（100 个上限且不截断、略过、去重）、命名（Finder 编号、大小写与 NFC/NFD、竞态、编号耗尽、目录错误）、队列状态机；协调器不使用每日次数 |
| `python3 scripts/check-core.py` | PASS，包括新增的 `BatchCoordinatorChecks`。用真实文件验证：<br>• 输出与单文件流式转换逐字节相同；不超过 10 MiB 的样本与编辑器路径（解码后整段转换）也逐字节相同<br>• 样本覆盖 BOM、CRLF、单独 CR、U+2028/2029、Emoji、组合字符、NUL、空文件；非法 UTF-8 文件失败，其余继续<br>• 已有目标和指向源文件的符号链接都不被修改；源文件不变；没有残留的临时文件<br>• 同名竞态改用下一个编号；磁盘不足时该文件失败，后续文件继续<br>• 取消与关窗会释放任务槽；只读文件夹被拒绝；文件夹丢失时剩余文件都失败<br>• 免费用户被拒绝；选完文件夹后复查资格；与单文件任务、第二个窗口互斥 |
| `check-project.sh`、`check-control-labels.sh`、`check-app-language.py`、`check-workspace.sh`、`check-control-sizing.sh`、`check-workspace-editor.sh`、`check-quota.sh`、`check-pro-access.sh`、`CheckScriptChecks.py` | 全部 PASS |
| macOS Debug 构建（CI 参数，arm64 + x86_64，未签名） | BUILD SUCCEEDED，新增文件没有警告 |
| iOS Simulator Debug 构建（CI 参数，arm64，未签名） | BUILD SUCCEEDED；批量代码用 `#if os(macOS)` 隔离 |

## 性能（无界面测量）

命令：

```bash
python3 scripts/benchmark-batch-conversion.py --work <新目录> --report <报告路径>
```

脚本会生成 100 个 UTF-8 文件：4 个 1023 MiB 的文件，加上 96 个 4 KiB 到 8 MiB 的文件，总计 4.19 GiB。转换配置为“台湾正体＋台湾词组”。脚本直接运行真实的批量协调器和流式转换服务（SwiftPM release 构建），测完后删除所有样本和输出，只保留报告。完整数据见 [benchmark-report.json](benchmark-report.json)。

| 指标 | 结果 |
| --- | --- |
| 环境 | Mac16,7（Apple M4 Pro，48 GB），macOS 27.2，源码 `99e8c83`，工作区干净 |
| 结果 | 100／100 个成功；输入 4,501,291,008 字节，输出 4,677,811,830 字节；输出文件名与输入一一对应 |
| 总耗时 | 108.7 秒（约 39.5 MiB/s） |
| 内存 | physical footprint 从 3.3 MiB 升到峰值 55.6 MiB；`ru_maxrss` 为 91.1 MiB。峰值不随文件总量增长，主要是单个文件的流式缓冲 |
| 主 actor | 每 10 毫秒检查一次，共采样 8,145 次，最长额外延迟 6.6 毫秒，没有出现可感知的卡顿 |

注意：这项测量是命令行进程，不是 App。它能说明协调器和文件服务的耗时与内存，但不能代替在 App 里实测界面、沙盒和签名包。

## Mac App 界面运行（本机 QA 版）

**环境**
- QA 版：Bundle ID `org.gewill.OpenCCman.WhatsNewUITests`，Debug，ad-hoc 签名，开启 App Sandbox 和 `user-selected.read-write`。
- 系统与语言：macOS 27.2，简体中文。
- 资格：Pro 资格用 QA 启动参数 `-qa-large-file-pro` 提供；免费用户的测试不带这个参数。
- 测试文件：放在不同步 iCloud 的 `~/Downloads` 下，测完后移到废纸篓。
- 截图：保存在仓库外，已上传到 PR 评论。

| 路径 | 结果 |
| --- | --- |
| 免费用户：菜单 › 批量转换 | 弹出“仅限会员的功能”，提示“Pro 可在 Mac 上一次批量转换最多 100 个 TXT 文件”，不打开文件面板 |
| 菜单多选 5 个文件（含 1 个 `.md`） | 列表显示“可转换 4 个，跳过 1 个”，`notes.md` 标为略过 |
| 选择输出文件夹后转换（文件夹里已有 `crlf-converted.txt`） | 成功 3 个，失败 1 个，略过 1 个。`invalid.txt` 显示 UTF-8 错误；`crlf` 存为 `crlf-converted 2.txt`。磁盘读回：<br>• 原有文件和全部源文件的 SHA-256 不变<br>• CR、CRLF、U+2028/2029、Emoji、组合字符、NUL 都保留，BOM 被去掉，与单文件导出一致 |
| 在 Finder 中显示 | Finder 选中 3 个新输出，原有文件不在选中范围 |
| 3 个 600 MiB 文件转换中取消 | 显示“第 1／共 3 个”和进度，取消后 3 个都标为已取消，输出文件夹为空 |
| ⌘⇧O 快捷键 | 能打开批量文件选择 |
| 窄窗口 + 应用内 150% 字号 | **修复前**：批量面板仍是 100%（sheet 不继承窗口内容上设置的字号）。**修复后**：面板文字放大，内容完整。再次转换到同一文件夹时继续编号（`mixed-converted 2.txt`、`crlf-converted 3.txt`），输出与第一轮逐字节相同 |
| 从 Finder 拖入 5 个文件 | **修复前**：提示“请至少选择一个 TXT 文件”，原因是拖放内容不带文件地址。**修复后**：进入批量列表；在沙盒中延后打开这些拖入的文件也成功，3 个输出与菜单路径的结果逐字节相同 |

另有两个界面修正：全部取消时，标题图标改为 ✕，不再显示成功的 ✓。批量面板的按钮仍使用系统控件字号，与单文件任务面板一致。

**发现但不在本 PR 范围**
- 单文件任务面板等其他 sheet 同样不继承应用内字号。
- 从 Finder 拖入单个文件时，走的是“读取文字内容”分支，不带文件名。
- 流式输出的文件权限为 0600，与单文件大文件导出相同。

## 未验证（不计为通过）

- **VoiceOver 与键盘：** 没有实际朗读，也没有只用键盘走完整个流程。
- **其他语言：** 英文和繁体中文界面没有截图。
- **测试方式：** 文件面板和拖放是在全屏控制下用合成的鼠标、键盘事件完成的，不是人工操作。
- **其他：** 最终签名包、macOS 12 实际运行、外接卷被拔出的情况都没有验证。
- `check-core.py` 里的协调器检查在命令行中运行，不经过 SwiftUI 界面。

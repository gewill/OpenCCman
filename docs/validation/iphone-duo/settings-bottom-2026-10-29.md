# 英语 XXXL 窄屏底部设置：人工辅助验收（2026-10-29）

关联 #280 / #282；承接[设置缩放记录](settings-resize-2026-10-29.md)中底部选项待验证项。
本次指定范围通过，未复现需要修改 App 的缺陷。自动滚动用例仍失败，不能改称自动化通过。

## 候选与环境

- PR #286 经本次源码审查无阻塞，HEAD `e459fb7720de784b08309a847f63814dce36bb38`
  的 App Regression / App icon 成功（run `40804367021`），reviews / threads / 讨论为空；
  实时 develop 保护要求 App Regression（app ID 15368），额外审批数为 0，管理员同受约束。
  [合并前审查](https://github.com/gewill/OpenCCman/pull/286#issuecomment-6488381291)明确没有外部正式 APPROVED。
- 已按 expected HEAD Squash 合入 develop `9d6a414b5e746f8bc176646ae42e17b112543715`，
  单一父提交为 `a872469`，tree 与 PR HEAD 相同；合并后 push run `40820846158` 成功。
- 仍使用同一 Debug QA App，执行文件 SHA-256
  `31b4512f5d393e9e1348f996ab56dd3710fbeea21984e0cf75696fcf5be5b30e`。
  `bccc0df` 至本候选的 App／工程构建输入无差异，本轮不改产品、依赖、最低系统或开关。
- 专用 Duo `4CAD3041-0744-41A6-8B4E-F934CA9F0778`，iOS 27.1 (24A94425)，英语，
  系统 `extra-extra-extra-large`；实际 GUI Resizable 400×750、corner radius 18。
- Xcode 27.1 (27A9275)、devicectl 651.13.5。中断前路径为
  `/Applications/Xcode-27.1.0.app/Contents/Developer`，恢复后核对同一构建在
  `/Applications/Xcode.app/Contents/Developer`；未切全局 xcode-select。
- 试验期间有未提交测试／宿主改动；未进入 App 包。最新试验源码、补丁和哈希保存于仓库外，
  之后只回退本任务创建的两份试验改动，最终 PR 仅保留记录。

## 操作与独立校验

| 场景 | 实际结果 | 依据 |
| --- | --- | --- |
| 滚动到底部 | 用户在指定窄窗手动向上滚动，回复“已滚动，底部完整可见”；两项完整露出 | 实际截图；同一 UIScrollView 的前后只读检查 |
| 点击 Not convert | 蓝色选中态变化，预设回到 Traditional · OpenCC | 截图；独立读取 QA Preferences：`regionOptions = Not convert` |
| 点击 Taiwan Idiom | 蓝色选中态变化，预设为 Custom | 截图；独立读取：`regionOptions = Taiwan Idiom` |
| 关闭并重开 | 实际返回工作区，再开仍显示 Custom；保存值仍为 Taiwan Idiom | 录像、截图和重开后的 Preferences 读取 |
| 恢复与返回 | 通过预设恢复 Not convert，再关闭设置 | 保存值回读；最终 AX 树无 Done 且有 workspace-source-editor；返回截图 |

只读 LLDB 遍历公开 UIKit 属性，未调用滚动／状态 setter：同一
`SwiftUI.HostingScrollView 0x10e7af000` 的 frame 为 384×730、contentSize 为
384×728.67，adjustedContentInset 为 [70,0,20,0]，scroll 和 pan 均 enabled。
用户手势前 contentOffset.y = −70，之后为 18.67，实际移动约 88.67pt，达到内容末端。
这与截图相互支持，不能仅从“工具返回成功”得出滚动通过。

`ConversionSettingsSheet` 本身使用 ScrollView（[固定候选源码](https://github.com/gewill/OpenCCman/blob/9d6a414b5e746f8bc176646ae42e17b112543715/OpenCCman/View/WorkspaceSurface.swift#L406)）；
region 变化写入偏好（[HomeViewModel.swift](https://github.com/gewill/OpenCCman/blob/9d6a414b5e746f8bc176646ae42e17b112543715/OpenCCman/Scene/HomeViewModel.swift#L114-L117)），
与实际选中态／保存值一致，无需添加布局或坐标补丁。

## 自动化结果与证据边界

自动输入的滚轮、拖动和 simulator swipe 没有形成可验收的滚动；部分动作报焦点／窗口错误，
或返回成功但位置不变，另有并发 Xcode guard 与主动中断。实验没有通过的滚动用例，
原报告、日志、xcresult、录像和最新试验补丁保留，未纳入常规测试。具体内部输入原因未定。
人工手势是之后独立完成的一轮，不覆盖或改写这些失败。

精选截图展示同一窗口两项真实选中态与最终返回。后续交互原件 283.7 秒墙钟录制，
视频轨约 278.33 秒；副本剪去等待、15fps，无音频，不改变动作速度，不作流畅度结论。
**用户手动滚动发生在该录像开始前**，滚动依据为用户确认、截图与前后原生偏移；
录像仅覆盖随后的点击、关闭、重开与恢复，不能当作原始手势录像。
[两图一录像](https://github.com/gewill/OpenCCman/issues/280#issuecomment-6490710550)已上传并回读，
图片／视频播放器存在，正文无本机路径；三份附件的匿名 Range GET 均返回 206、类型正确。
链接与上传副本 SHA-256 由[机器可读摘要](settings-bottom-2026-10-29.json)追溯。

本独立人工轮使用空原文／结果，未重新验证非空稿件、转换正确性或系统重启后的恢复；
非空稿件六项证据保留在 #286，不能由本轮扩大。重开后核对了 Custom 和保存值，
没有再次滚到底部检查蓝色选中态。未逐项操作其他设置，未完成完整 #280/#282、
其他姿态／分屏／IME／任务／系统文件面板／启动、普通设备、Duo 真机及最终签名包验收。
最低系统 #16、交易 #14/#71、容量 #260/#268 与条件 #283 保留；VoiceOver 体验未验证。
两个 Issue 继续开放；未分发、部署或提交商店。

## 资源收尾

恢复阶段初始设备为 Shutdown，只启动并复用上述一个专用设备。
保存证据后结束录制、detach 调试器、停止 QA App 和测试，恢复 Not convert 与系统 large，
退出 GUI resize 并指定 UDID shutdown；重新读取列表确认 Shutdown。
未使用 shutdown all，未关闭其他设备或退出共享 Device Hub。

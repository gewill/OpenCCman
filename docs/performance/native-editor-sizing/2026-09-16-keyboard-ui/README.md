# 键盘验收记录（2026-09-16）

来源为 `d8bcb5c7c08e86347f739aa9f8a4791caf965164`，文档 HEAD `eb2dd51ce840ef3f70be8e16d8bafbeb00c0348d` 的 App Regression 35027501496 通过，应用源文件与该测试包一致。macOS 27.0、English、Light、默认字号，独立 ad-hoc 诊断包，不代表发布签名或最低系统验收。

## 通过的范围

- 开启系统 Keyboard Navigation 后，Tab/Space 选择 Stacked，Cmd-Option-1 恢复左右布局；焦点环实际可见。
- Space 激活转换；Cmd-T 可从原文转换。Ctrl-Tab 从原文到结果，Shift-Tab 从只读结果回到原文；编辑器内反向离开使用 Ctrl-Shift-Tab，不能把 multiline 编辑行为当作普通按钮。
- 只读结果输入 x 后仍为 nihao；系统 Export 保存出准确的 5 字节 nihao，无 BOM。
- 用键盘打开 Import、定位非法 UTF-8 文件；错误确认按钮获得焦点，Return 关闭后回到 Import，原文与结果均保留 nihao。
- Cmd-Option-I、Tab/Space 选择台湾预设，Escape 关闭面板；旧结果保留并显示配置已变更提示。
- 诊断额度成功扣 2 次，对应两次成功转换；导出、失败导入、预设和布局操作未额外计次。

`focus-observations.json` 只摘录原始观察中的键和焦点行，省略原生文件面板的无关磁盘/侧栏记录。没有焦点行的步骤保持 null，不补造。原始完整 AX 日志和偏好备份仅留在本机。

## 未通过或未覆盖

- Tab 顺序实际为 Pane sizes → Paste → Copy → Export → Import → Source。保留进一步定位，未宣称与视觉分组一致或完整键盘验收通过。
- 工具按键只得到 ASCII nihao；无中文候选或 marked text，不能算中文输入法验收，也不足以定为应用缺陷。
- 短暂启用 VoiceOver 后，尝试 VO-Right 及进入交互，没有取得可靠的 VO 焦点移动或朗读证据，不算通过。
- 本轮 ScreenCaptureKit -3822 中断，录制进程退出 133；未发布残片，不能声称本轮有完整交互视频。PR 既有修改前后视频保留其原来范围。
- 当前截图为候选验收状态，不替代前后对照。原始截图尺寸分别为 900×450 和 260×138px；没有后处理，也不将截图像素冒充布局 pt。
- 取消、任务中布局切换、最大字号、真实 IME、完整 VO、三端以及 iOS 14/macOS 11 仍按 #20/#16 保留。

## 恢复

VoiceOver GUI 已关闭且无 VoiceOver 进程；Keyboard Navigation GUI 恢复关闭、AppleKeyboardUIMode=0；原输入法恢复。诊断 PID 96774 已退出，标准偏好逐字典恢复、沙盒偏好恢复为原来的不存在，包改名 inactive。System Settings 回到原 App Management 页面，未修改该页权限。详见 cleanup.json。

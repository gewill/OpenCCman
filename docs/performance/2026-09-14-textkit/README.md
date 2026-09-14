# #65：Mac 大文稿重排修复

> 测量版本说明：本页原始数据来自旧诊断入口。PR #66 review 后的协议 2 已同步进工具，计时内的编辑器全文比较已移除，构建复用和来源验证已加固。此页 `action_ms` 在独立区间计时，全文哈希校验在停表后；但进程 CPU/峰值内存仍包含旧入口工作，不能将这些历史数字与协议 2 样本混合比较。重测必须新建目录并在构建时指定 `--reflow`，不手改旧 metadata。

原性能测量实现来自 `5e1de0b`，基于 #66 / `fc94ec0`。只修改 `WorkspaceScrollKeeper`，保留现有系统编辑器、转换模型、iOS 14/macOS 11、精确依赖和 10 MiB 限额。

## 问题与实现

既有滚动桥接使用 NSLayoutManager 的字形接口，会启用 TextKit 1 兼容模式。默认连续布局需要处理前面的段落，闲时布局还会主动扫描全文。大文稿到远端位置或改变宽度时，主线程因此长时间处理字形和排版。

本次为现有桥接开启 `allowsNonContiguousLayout`、关闭 `backgroundLayoutEnabled`，只按需处理目标区域。非连续布局会先估计屏幕外的几何位置，因此不能立即把估计坐标当成最终阅读位置：保留同一逻辑字符锚点，合并连续尺寸通知，先由系统滚到目标范围，再于下一次主队列调整后恢复局部行偏移。换稿通过 revision 使旧回调失效。全程不设置新的 selection、不替换 delegate 或原生编辑器。

另行测试了保留 TextKit 2 的实现；虽改善延迟，但本机极多短段落语料的三次流程峰值 RSS 达 2568–2733 MiB，未采用。保留 [试验补丁](textkit2-trial.patch) 和 [原始样本](textkit2-trial/)，避免以后只因 API 较新而直接恢复这条路径。

## 同机对照

Apple M4 Pro / 48 GiB，macOS 26.6.2（25G83），Xcode 26.6（17F113），Release、英文浅色、默认字号、1200×800pt。独立诊断包沿用 [#18 测量边界](../README.md)，不代表最终签名包。固定 OpenCC 1.4.2 / wrapper `6eded293f5c84c064f332cbc2832391165c82dda`。

对照双方使用相同测试入口 SHA-256 `498b84a5d7d712c20f511ff3cb1153c1f1aea0a1a321768bcdba18f158f7db4a`，相同环境、其他源码与依赖。私有基线快照用 `fc94ec0` 的 keeper，修复快照 keeper 的 SHA-256 与最终提交一致。构建/回归/录屏/AX 检查均与正式计时分开。

协议依次转换 1/5/10 MiB，在开头、中部和末尾滚动后各切上下/左右。原始 [基线](baseline/) 只有一个部分完成进程；1 MiB 开头切回左右耗时 **13,855 ms**，5 MiB 中部滚动期间到达**整个进程 90 秒期限**。最后开始事件在约42.8秒，缺少完成事件；不能称为单次滚动耗时90秒。

修复版三个进程全部完成，以下为10 MiB动作的中位数和完整范围：

| 位置/动作 | 中位数 | 范围 |
|---|---:|---:|
| 开头切上下 | 16.0 ms | 15.6–17.5 ms |
| 开头切左右 | 22.6 ms | 19.2–23.3 ms |
| 中部切上下 | 22.3 ms | 22.0–22.7 ms |
| 中部切左右 | 29.2 ms | 29.0–29.6 ms |
| 文末切上下 | 16.1 ms | 16.0–16.9 ms |
| 文末切左右 | 20.0 ms | 19.6–20.2 ms |

整个协议峰值 RSS 为 **382.9 / 375.7 / 387.0 MiB**。旧版没有完成相同流程，因此不计算整套流程的前后内存降幅或速度倍数。此前默认转换协议约458 MiB也不是这套交互协议的等价基线。真实10 MiB交互、拖动与AX检查后另一次RSS快照约486 MiB、CPU0%；这是驻留快照，不是峰值。[原始结果](fixed/)、[汇总](summary.json)、[交互内存](interactive-memory.txt)。

动作计时包括两个主队列 layout/display flush，不是屏幕呈现时间。原生阅读位置回归另有等待系统调整后的断言。计时样本断言原生编辑器身份、选区、输入/输出哈希不变。没有推算 FPS、电量或其他机器速度。

## 实际界面证据

同为 Mac 1200×800pt、英文、浅色、默认字号、10 MiB 固定语料。修复前复用已通过gh上传的同条件基线记录（应用源码c3009c7，与fc94ec0应用源码一致）；修复后源码5e1de0b。截图/视频现通过 gh pr edit --attach 上传为附件，当前树移除媒体二进制，既有历史未重写；文件校验见 [media-provenance.json](media-provenance.json)。录像含实际布局切换和文末跳转，不用于性能计时。

| 修复前 | 修复后 |
|---|---|
| ![修复前](https://github.com/gewill/OpenCCman/blob/fc94ec0ded996e76a67feea38f4efb59b8d50711/docs/performance/2026-09-14/media/baseline.png?raw=true) | ![修复后](https://github.com/user-attachments/assets/81b91a0a-0906-4a3c-bc77-33a34f044233) |
| [交互视频](https://github.com/gewill/OpenCCman/blob/fc94ec0ded996e76a67feea38f4efb59b8d50711/docs/performance/2026-09-14/media/baseline.mp4) | [交互视频](https://github.com/user-attachments/assets/36f7ca52-e4ca-4ebb-b169-83e639d4ea85) |

## 验证与边界

- [日志](validation/)：原生阅读位置/快速重排/首次远端滚动/选区/组合文字/换稿，以及1/5/10 MiB长段落；核心转换、七配置、取消/替换、文件/配额/provider回归；工程检查与比较器6项测试通过。
- 真实UI：导入10 MiB、转换、上下布局、Cmd-Down文末、键盘切左右、拖动分隔条50%→58%、向上滚动，原文焦点保留、结果仍可见。
- 未改变系统测试设置，VoiceOver未开启；真实VoiceOver仍由#20验收。macOS11/iOS14实机仍是#16发布前验收项，当前机器没有这些环境。iPhone/iPad运行时未重测；本改动完全位于macOS条件编译路径。
- 语料覆盖多短段落与约10 KiB长段落，不声称一个无换行10 MiB段落同样具有这些延迟。超过10 MiB的有限预览仍由#52处理。
- 未推送build分支、未触发Xcode Cloud，未合并未完成检查的PR。

参考：[Apple TextKit最佳实践](https://developer.apple.com/videos/play/wwdc2018/221/)、[backgroundLayoutEnabled](https://developer.apple.com/documentation/appkit/nslayoutmanager/backgroundlayoutenabled)、[TextKit兼容模式](https://developer.apple.com/videos/play/wwdc2022/10090/)。

## 后续回归：导航与待执行恢复回调交错

同步 #66 工具修复后，macOS 15 CI 的首次文末可见性检查失败，选区位于 645888，但可见区域仍在文中。相同代码也曾通过 CI。局部复现进一步确认：在窗口改宽后、两次异步恢复尚未完成时立即改变选区并跳转文末，旧恢复会把视口拉回原锚点；等待更久不能修正已经覆盖的导航。

修复在排队时保存选区值，两次恢复都要求当前选区仍相同；新的光标/选区导航优先，旧回调仍按原流程清理 pending 状态。不是在捕获阅读锚点时保存选区（那会错误忽略发生在改宽之前的选区改变）。不修改选区、不重新发出滚动命令，也不通过增加测试等待掩盖失败。

新增回归故意把“改宽→跳文末”放在同一个主线程执行段，等待回调后同时验证选区与可见文本。原实现 exit 133，修复后 exit 0，既有阅读位置、组合文字和 1/5/10 MiB 长段落回归通过。[独立复现源码与日志](validation/navigation-race/)。此修复发生在原性能采样之后，本页旧性能数字继续只对应标注的历史源码，不作为新增选区保护的重测结果。

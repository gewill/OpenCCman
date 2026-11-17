# iPad 窄窗口底缘点按复核

日期：2026-11-01。关联 [Issue #27 的运行证据](https://github.com/gewill/OpenCCman/issues/27#issuecomment-6551024728)。**#27 保持打开。**

本次可见底缘的上一处／下一处导航通过，未发现需要修改 App 的命中缺陷。确认了一种可重复的自动化误点：AX 仍报告被滚动视口裁切的完整按钮范围，其中心可能已不在可交互区域。此前同一底缘位置的偶发失败没有同时刻触摸／视口日志，本次未复现，具体历史原因仍未证实；不将新通过结果追认成旧失败已通过。

## 来源与环境

- PR #312 最终头 `cb5f6777c691b054401a5515d6ac4a6e5489f107`；[头提交 CI](https://github.com/gewill/OpenCCman/actions/runs/41254626612) 成功，需求／规范复审无剩余阻塞；Squash 合并提交 `8ec39b3e971c3efed9976525f52a9e330c683902`。
- iPad A16 / iOS 27.0 模拟器，UDID `737A20AC-4B6E-4B43-9C2D-0306F6266B6C`；英语，375×532 原生窄窗口；默认字号与 XXXL。Xcode 27.1（27A9275），`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`。
- 隔离 QA Bundle ID `org.gewill.OpenCCman.WhatsNewUITests`，Debug 04。实际安装的可执行文件 SHA-256 `d0a86a9f8d9f2ce251c0e5f2cbdbd20f70dbd0e2e646dc8265728c7df8b4c5c3` 与原双端构建报告一致。该值只识别启动文件，不能单独唯一绑定 Debug 代码；后续发现相同启动壳可以加载不同 `.debug.dylib`，见[载荷证据补正](local-export-acceptance.md#构建报告缺口与修复)。原来源与构建记录保留，不追认旧报告已验证完整载荷。
- App 实现源为 `842c6074cf96616563643b2008372ea1edadfc60`，至 PR 最终头未再改变 App 源码。合并时 develop 另有 v2.2 版本号及 `MobileFileRuntime.productionEnabled` 改动；工作区／差异 UI 源码相同，但本次未重新构建合并产物，不能把旧二进制标为合并提交的新构建。
- 本轮只更新验收记录；未改 App、部署下限、容量或依赖。没有重跑无关功能矩阵、双端完整构建或性能基准。

## 运行与对照

使用内置示例、台湾标准＋台湾词组完成真实转换，开启差异：

```text
鼠标里面的硅二极管坏了，导致光标分辨率降低。
滑鼠裡面的矽二極體壞了，導致游標解析度降低。
```

窗口屏幕原点为 `(223,267)`。XXXL 外层 `SwiftUI.HostingScrollView` 在窗口中的可见范围为 `x=12…363, y=163…510`。AX frame 为窗口坐标；AXe 物理触摸采用屏幕坐标。以下点按均读取后续 AX 的真实计数，不以命令返回成功判定通过。

| 条件 | 动作与结果 |
| --- | --- |
| XXXL，下一处 frame `(80,451.5,44,44)`，中心 `(102,473.5)` 完全可见 | 屏幕 `(325,740.5)` 点击，3→1；连续下一处／上一处／下一处为 1→2→1→2 |
| 默认字号，同一底缘位置 | 下一处／上一处重复两轮，1→2→1→2→1 |
| XXXL，frame y=478.5，中心 y=500.5 仍在视口内 | 虽然按钮部分裁切，中心点击仍使计数 2→3 |
| XXXL，frame y=500.5，AX 中心 y=522.5 在视口外 | 中心点击不改变第 3 处；只读 `hitTest` 命中导航根视图，未进入工作区滚动视图 |
| 同一个裁切按钮，点击仍可见的 y=505 | 计数 3→1；随后外层滚动可使整行完整可见 |

单独附加调试器观察 `-[UIWindow sendEvent:]`：屏幕 `(325,730)` 实际送达窗口 `(102,463)`；Began／Ended 的 responder 均为按钮手势，实际计数 2→3。该日志仅用于确认坐标；表中底缘验收在调试器已 detach 后进行。

没有修改滚动偏移或调用按钮 action 来替代用户动作。窗口缩放、滚动、切换字号及导航通过原生窗口手柄、AXe 物理手势和 `simctl ui content_size` 完成。一次拖到面板分隔条改变了面板比例，已用原生 editor frame／contentSize 识别；后续滚动选在结果标题右侧空白，避免把调整面板误当滚动。

## 重跑方法

1. 使用任务归属明确的 iPad 模拟器及隔离 QA App。记录初始状态、UDID、工具链、实际二进制哈希；运行上述示例，开启差异，将窗口缩到 375×532。
2. `xcrun simctl ui "$udid" content_size extra-extra-extra-large`，滚动到导航行靠近底缘。先用 `axe describe-ui --udid "$udid"` 读取最新按钮范围与计数。
3. 对 QA 进程作只读调试，确认窗口到屏幕坐标转换和祖先滚动视口。不要把 AX 完整范围当成裁切后的可见范围。

```text
xcrun lldb -p <QA_PID>
expr -l objc++ -- @import UIKit
expr -l objc++ -- UIWindow *$qaWindow=(UIWindow *)[[UIApplication sharedApplication].windows firstObject]
expr -l objc++ -O -- NSStringFromCGRect([$qaWindow convertRect:$qaWindow.bounds toCoordinateSpace:[UIScreen mainScreen].fixedCoordinateSpace])
expr -l objc++ -O -- [$qaWindow recursiveDescription]
```

需要精确检查某个点时，显式赋值 CGPoint 的 x/y，再调用 `hitTest:withEvent:` 并查看父视图链。本轮首次调试表达式用 `CGPointMake` 得到错误的 y=0；已改为成员赋值并核对返回点坐标，错误探针不作为证据。

4. `detach` / `quit` 后，将**当前可见点击点**转换为屏幕坐标，再点按、重读计数。例如本轮完整可见位置：

```bash
axe tap -x 325 -y 740.5 --tap-style physical --udid "$udid"
axe describe-ui --udid "$udid"
axe tap -x 273 -y 740.5 --tap-style physical --udid "$udid"
axe describe-ui --udid "$udid"
```

这些数值只对应本轮原点与布局；其他窗口必须重新测量。验证不应主动点击已被裁切的中心，除非正在做本记录的负面对照。

5. 默认字号重复导航；恢复默认字号，保存证据，结束调试与采样，关闭仅由本任务启动且无人接用的设备。本轮已确认该 UDID 为 Shutdown。

## 证据与边界

| 完整可见的底缘按钮 | AX 中心已被裁切的对照 |
| --- | --- |
| ![底缘按钮完整可见](https://github.com/user-attachments/assets/830829b2-4846-4408-8b6b-95f6e44d65a8) | ![按钮中心位于视口外](https://github.com/user-attachments/assets/507c0f3b-0772-4a6c-8d5e-07b123b7609c) |

[连续窗口渲染采样录像](https://github.com/user-attachments/assets/da4c2156-6274-49d1-9501-6bee72dc798b)：23.9 秒，10Hz、239 帧，真实下一处／上一处／下一处计数为 1→2→1→2。已完整播放核对。通过临时调试注入的有界 NSTimer 在 QA UIWindow 内采样 `drawViewHierarchy`，不采集系统桌面、其他 App 或音频；原始时间间隔最大 104.1ms。这是窗口渲染采样录像，不是设备屏幕录像，不能用于帧率、卡顿或系统手势验收。

原始 PNG、AX JSON、触摸日志、视口／hitTest JSON、采样帧与时间戳保存在仓库外的 `ui-evidence/OpenCCman/27-ipad-edge/cb5f677` 索引中。远端只上传精选无损 WebP 与 H.264 MP4；本页复用 Issue 附件，没有重复上传。

| 上传副本 | SHA-256 |
| --- | --- |
| 完整可见 WebP | `2bc51d54fc2d31f28ed831ead547883829b198448c457414318de36616f494b5` |
| 裁切对照 WebP | `c06354f8e627a32a6ec2d5fa04d41ea76109609a7913de35f23efe76e2ce15b3` |
| 操作录像 | `b801d5ae66c5f1654995abe1e8a01032b4ed8054de722b18bfed6b94648e23ce` |

三个远端附件均已回读，SHA-256 与上传副本一致；评论正文已核对没有本机路径死链。

当前证据支持上述模拟器、窗口和布局下的可见底缘导航，不证明此前失败的唯一原因。真机、VoiceOver 体验、iOS 15／macOS 12、签名包、近上限真机性能仍沿用主记录的未验收边界，Issue 不关闭。

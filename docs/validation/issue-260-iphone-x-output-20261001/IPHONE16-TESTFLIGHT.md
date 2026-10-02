# #260：iPhone 16 Pro / TestFlight 2.2 (61) 补测

2026-10-01。完整数据见 [iphone16-testflight-results.json](iphone16-testflight-results.json)。本轮验证若干正式候选路径，**不代表 #260 全部通过**。

## 环境与取证

- iPhone 16 Pro，iOS 27.0.1（24A446），USB 已配对。`devicectl` 实际读回安装 `org.gewill.OpenCCman` **2.2 (61)**；维护者从 TestFlight 打开该 App。
- 云端候选 source：`aad2b09931e34dbfab3e8218be22e94cd604fbb6`；wrapper：`564b094b2b69f2c1e907fa3d89fe6845469a4e4e`。
- 浅色／英语，原文和结果均空白，沿用原设置 **Traditional Chinese / Taiwan Standard / Taiwan Idiom**（`taiwan-idiom`，rawValue 1057）。未修改字号、VoiceOver 或其他系统设置，未确认购买。
- Device Hub 原生 UI 自动化超时；改用真实 iPhone Mirroring 的鼠标／键盘完成 Files 与 App 交互。没有使用 QA 注入或本地重新签名 App。
- `devicectl` 能生成 1206×2622 截图，但 Mirroring 连接期间实际捕获的是锁屏，**不作为 App 状态证据上传**；其 screen-record 返回设备不支持该 capability。改用 macOS `screencapture` 只录 Mirroring 窗口，成片为 692×1420 或 824×1552、H.264、24 fps；公开静态图由这些真实录像的对应时刻提帧，未使用模拟器或设计稿。
- [视频清单与哈希](media-manifest.json)记录原片／成片、提帧时刻及遮挡区间。保留时间线，主屏幕的日历／天气画面及相邻转场使用黑屏遮挡；保留取消前、进入后台前的转换进度和返回状态。原始私密片段不上传。

## 公开图像与录像

[Issue #260 取证评论](https://github.com/gewill/OpenCCman/issues/260#issuecomment-5926475419)包含 7 张真实录像提帧和 4 段交互录像。媒体已通过 `gh --attach` 上传，并读回确认所有引用均为 GitHub assets，无本地路径。具体 URL、来源、时刻和哈希见 [media-manifest.json](media-manifest.json)。

## 已实际通过

| 项目 | 实际操作与结果 |
| --- | --- |
| 未下载 iCloud 输入 | 在独立 `OpenCCman-QA-100MiB-20261001` 目录中选取带下载云标记的 100 MiB 合成语料；系统下载完成后进入正确的文件名／容量／配置确认页 |
| 100 MiB 转换 | 经真实 Pro 门控进入 Preparing → Converting → Ready to save；没有将全文装入编辑器 |
| 取消系统保存 | 打开系统保存面板，通过 Escape 取消；回到 Ready，保存入口仍可用 |
| Ready 进程重启恢复 | `devicectl process launch --terminate-existing` 两次返回不同 PID **2119 → 2125**；新进程自动恢复同名、同配置、同容量的待保存任务 |
| 重试系统保存／完整读回 | 重启后保存至 QA 目录，文件同步到 Mac，完整 104,857,600 字节／SHA-256 与独立整篇参考一致 |
| 上限 + 1 字节 | 104,857,601 字节合法 UTF-8 文件被拒绝，提示最大 100 MiB；空白工作区保持原状 |
| 转换中取消 | 画面明确显示 Converting File（录像可见 10%）；点击 Cancel 后显示 Task stopped，没有保存半成品的入口 |
| 后台中止 | 约 5% 时返回手机主屏幕；用普通 launch 返回前台（同 PID 2125），显示 Task stopped，没有后台继续得到 Ready |
| 文件与编辑器保留 | 最后再次核对 iCloud 原输入与首次已导出结果的完整 SHA-256 未变；App 返回原有空白工作区、原配置 |

系统保存读回报告：[iphone16-export-verification.json](iphone16-export-verification.json)。独立参考：[iphone16-taiwan-idiom-oracle.json](iphone16-taiwan-idiom-oracle.json)。输出 SHA-256：

```text
77e868fb00118d8926030c22934049fef81bae07a325e036d1082e7415764f29
```

这是使用台湾标准＋台湾词组的结果，与 iPhone X 的 OpenCC 繁体哈希不同是预期配置差异。

## 未通过或不能据此推定

- 第一次试图取消时，转换先于点击完成，点击实际打开了保存面板；该轮记为完成，**不计作转换中取消通过**。取消其保存面板后删除本轮可重建的本地测试任务，云端原文与先前导出文件均保留。随后另一次在转换进行中成功取消。
- 当前实测计数：两次完成、一次系统保存后完整读回、一次转换中取消、一次后台中止；没有声称十轮循环或每性能样本三轮已完成。
- 临时目录清理没有读取 distribution App 私有容器验证；不能只凭 Task stopped 证明所有磁盘文件已经清理。
- 原有 Pro 权益允许大文件操作，但没有重做购买、恢复、过期等权益矩阵；仍由 #14 / #71 跟踪。
- 没有测量设备 physical footprint／内存峰值、热状态，也未读取完整 jetsam/watchdog 诊断。交互成功不能替代这些指标。
- `xctrace Activity Monitor` 按 PID 2125 报 `Cannot find process for provided pid`，按 OpenCCman 名称同样无法选择；同时 `devicectl` 仍读到该运行进程。因此本轮没有生成有效内存 trace。日志：[按 PID](testflight-activity-capability.log)、[按名称](testflight-activity-name.log)。不将工具选择失败诊断为 App 崩溃，不改变正式包的签名或调试权限。
- 所有配置／语料／20/50/100 MiB、近 10 MiB 编辑器共存、冷/热/缓存、锁屏、处理中强退、第三方提供方／空间不足等余项仍按 #260 原标准补齐。Mac 签名候选回归与最低系统不由这次 iPhone 运行替代。
- 维护者确认**目前没有可用真实 iPad**：保留环境阻塞，未豁免 iPad 标准；iPhone X 实际 build 仍待确认。

## 状态

本次没有改 App 源码、容量限制、依赖、系统偏好或购买状态。#260 继续开放；后续扩容分别由 [#268](https://github.com/gewill/OpenCCman/issues/268)、[#269](https://github.com/gewill/OpenCCman/issues/269) 跟踪，均在当前验收完成后独立推进。

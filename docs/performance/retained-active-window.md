# 保留窗口活动转换时关闭其他窗口

关联 #18、#93，依赖 #104。#103 验证关闭转换中的窗口会取消自身任务，本协议补充相反方向：首窗正在真实转换时，关闭另一个空闲窗口，首窗必须继续成功。

## 协议

沿用 `--documents` 的全部五轮文稿和固定 oracle，随后新增第七个实际 WindowGroup 窗口（首窗编号 1）。新窗保留短文 `Idle other window`，不启动转换；首窗通过真实 `importFile` 导入固定 10 MiB，启动真实 `translate`。不得用延迟或阻塞原生转换来人为延长重叠。

检测真实 wrapper 调用 begin 后，主线程检查首窗仍在转换、另一窗空闲，记录两模型身份并调用另一窗 `performClose`。同步 `willClose` 时间必须严格位于同一次 begin/end 之间。此区间只记录标量状态，不在关闭前复制、序列化或散列 10 MiB 正文；不把 loading 标签当作实际执行证据。

首窗完成后逐字节检查原稿、结果、导出快照和原有编码生成的实际文件；旧取消窗口不得回写，全部成功计数应为 6，预约为零。成功后再观察至少 5/20 秒，核对正文/结果/配置/任务指纹；最后关闭首窗并观察零窗口 5/20 秒。该段避免每 20ms 全文散列，只在明确检查点校验。保留模型数量作为观察结果，不自动判作生产泄漏。

## 运行与隔离

```bash
python3 scripts/prepare-window-lifecycle.py --documents --active-anchor --output /new/output
# 构建 preparation.json 对应的私有 source；不改产品或依赖。
# 本地通过正常 UI 启动专用 bundle，应用自驱动并退出。
python3 scripts/check-native-window-lifecycle.py --documents --active-anchor \
  --raw /path/to/raw.jsonl --document-files /path/to/generated/documents \
  --output /new/report
python3 -m unittest discover -s Tests/Benchmarks -p 'test_*.py'
```

专用 bundle 为 `org.gewill.OpenCCman.NativeWindowLifecycleAuditAutoDocumentsActiveAnchor`，保留 macOS 11 产品下限，私有变体跳过购买、Services、全局快捷键和自动 What's New。不与已有等待用户验收的应用共享 bundle。自驱动最长 600 秒；CI 进程上限 660 秒，失败保留日志与已生成文件。原 `--documents` 仍为原协议/原时限，历史记录不改写。

App Regression 手动输入 `active_anchor_window_lifecycle=true` 选择此协议，优先于其他生命周期输入；普通 PR 检查继续运行。无写权限的 macOS 15 / Xcode 26.3 job 构建并实际执行，保留既有固定 SHA Actions。

## 当前证据

本地 82 项 Python 检查通过，包含原 65 项、11 项新协议正负测试、3 项导出文件检查、四份真实日志/ZIP 复核及录屏失败状态检查；合成记录不是应用运行结果。准备器已生成隔离源码，Swift parse、Python 编译、YAML 语法和 diff 检查通过。[云端完整运行 35009472511](https://github.com/gewill/OpenCCman/actions/runs/35009472511)已通过，源码 `cc38088875fa6ee89da122f7011de35f4e69fbb2`。普通 App Regression 的最终提交 `4aab1d8` 也已通过。同包本机不录屏、录制尝试与新增场景补录均已完成，结果与录屏边界见下表；不替代原 issue 的全部验收。

### macOS 15 CI 实际结果

第七窗的同步关闭发生在保留首窗原生调用开始后 10.036792 ms，调用结束在 191.545084 ms；日志确认操作前首窗转换中、关闭对象为模型 7 的空闲窗口。首窗随后完成 10 MiB 转换、导出，五份实际输出在 CI 退出后及下载后均独立逐字节验证。成功次数最终为 6、预约 0，没有旧取消任务回写。

首窗成功后 +5/+20 秒只剩模型 1，最终零窗 +5/+20 秒无存活模型。该 CI 没有 CUA 或录屏，不等于本机观察条件下也必然零模型。原文、结果、编码和状态正确性不作为性能提速证据。

[完整原始记录、固定文件和校验和](retained-active-window/2026-09-16/ci-macos15/)；诊断时间包含实际 UI、轮询与校验开销，未重新归因 UI 或引擎耗时。

不覆盖分发签名、最低系统、Pro/跨日/临界额度、系统入口或性能收益；这些继续留在原 issue。


### 同包本机复验与观察条件

| 条件 | 新增场景调用开始→关另一窗 / 调用结束 | 新增场景成功后 +5/+20 | 最终零窗 +5/+20 |
|---|---|---|---|
| macOS 15.7.9 CI，无 CUA/录屏 | 10.037 / 191.545 ms | 模型 1 | 无模型 |
| macOS 27，仅启动查询首窗，无录屏 | 17.045 / 118.528 ms | 模型 1 | 模型 1 |
| macOS 27，前 96.833 秒录屏后工具失败 | 12.090 / 117.021 ms | 模型 1–5 | 模型 1–5 |
| macOS 27，只录制最后新增场景 | 34.612 / 128.949 ms | 模型 1、7 | 模型 1、7 |

四份完整功能日志共 1,048 行，全部 memory API 状态有效；每轮五份完整导出独立 byte-equal，共 20 份。每轮最终额度为 6、预约 0，保留首窗继续成功，旧取消任务没有回写。CI、本机日期键不同来自各自时区；该协议只验证每轮同日，不验证跨日。

主测量中新增模型 2–7 均释放；初次查询过的本机首窗仍存活。前段录制失败轮的窗口 6/7 在录制已停止后出现；最后场景补录轮则此前不录屏，录制后模型 7 存活。必须保留这些时段差异，不能把它们合称同一个全程录屏条件，也不能单凭存活数判作生产泄漏。

- [不录屏原始数据与完整文件](retained-active-window/2026-09-16/no-extra-observation/)
- [首次录屏失败日志、状态及完整功能数据](retained-active-window/2026-09-16/partial-recording/)
- [新增场景录像轮数据与完整文件](retained-active-window/2026-09-16/recorded-final-case/)
- [媒体参数与 SHA-256](retained-active-window/2026-09-16/media.json)

首次录屏工具返回 ScreenCaptureKit -3822，随后重复停止返回 -3808，退出码 133；MP4 仅 96.833 秒，未覆盖新增场景，不作为成功演示。应用协议本身继续并成功完成。补录由日志检查点启动/停止，只覆盖最后场景，正常退出，长度 19.472 秒；前五轮和最终零窗 +20 秒仍依据完整 JSONL，不能称为全部协议录像。

三个本机应用 PID 40103、45768、50895 均已退出；每轮私有偏好恢复一致，VoiceOver 前后均关闭。应用已注销并移为 `.app.inactive`，未操作其他等待用户验收的应用。见[恢复记录](retained-active-window/2026-09-16/cleanup.json)。


### 真实截图与交互录像

[通过 gh 上传的媒体说明](https://github.com/gewill/OpenCCman/pull/105#issuecomment-5686604812)。English / Light / 默认字号，主窗约 900×450px，录制画布 1496×968px；仅目标应用，无音频/麦克风/指针。同一源码的操作前后状态，不是产品 UI 改版。

| 关闭另一窗口前（13.5s） | 保留窗成功显示结果（18s） |
|---|---|
| ![关闭前](https://github.com/user-attachments/assets/c1a5a8c6-a566-4a1f-8cdd-97ecfa7eab26) | ![保留窗结果](https://github.com/user-attachments/assets/14624646-fd74-48d3-823d-409feaf27060) |

[新增场景视频，19.472s](https://github.com/user-attachments/assets/b24154e6-372b-4712-8879-399268d69f39)。截图来自视频原帧，时间为媒体时间；同步关窗与原生调用的重叠以单调时钟日志为准，不用视频偏移估算调用耗时。

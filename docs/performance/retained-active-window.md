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

本地 76 项 Python 检查通过，包含原 65 项及 11 项新的协议正负测试；合成记录不是应用运行结果。准备器已生成隔离源码，Swift parse、Python 编译和 diff 检查通过。最终 Release 链接、实际协议、同包本机运行及真实截图/录像仍待执行，未宣称验收完成。

不覆盖分发签名、最低系统、Pro/跨日/临界额度、系统入口或性能收益；这些继续留在原 issue。

# 三轮原生窗口生命周期验收

跟踪 #93/#18，依赖 #90、#101。上一轮发现 CUA 查询与录屏会影响存活模型，因此主要测量不再查询新增窗口，也不录屏；交互演示独立进行，记录结果但不替代基线。

## 可复现入口

```sh
# 只生成新目录内的隔离源代码，不启动应用。
python3 scripts/prepare-window-lifecycle.py --cycles --output .build/native-cycles

# 本地只读核验指定进程的现有 JSONL。
python3 scripts/check-native-window-lifecycle.py --cycles --raw /absolute/path/lifecycle-PID-UUID.jsonl --output .build/cycle-report
```

CI 手动选择 `cycle_window_lifecycle=true`，构建 Release 并运行三轮协议。若同时指定双窗选项，三轮选项优先。该模式使用 `org.gewill.OpenCCman.NativeWindowLifecycleAuditAutoCycles`，产品和原双窗模式保持不变；三轮驱动不使用 macOS 13 的 OpenWindowAction，因此仍按 macOS 11 部署下限构建。

## 实际协议

1. 保留首窗口的默认短样文，等待至少 10 秒并记录其内容、结果、配置、任务状态及额度的值哈希。
2. 在应用自身菜单中查找唯一、已启用的 Cmd-N 动作，调用 `NSMenu.update()` 后 `performActionForItem(at:)`，逐个新建两个真实 WindowGroup 窗口。菜单项缺失/歧义即失败，不猜私有 selector。
3. 等待真实模型与窗口关联，只对两个新窗口调用 `replaceSource("")`，记录其输入/结果确为空。此步骤不验证键盘输入、IME 或文件选择面板。
4. 三窗停留至少 10 秒，逐个 `performClose` 关闭新窗，保持首窗。关窗后 +5/+20 秒记录全部模型编号、内容大小与首窗状态；首窗内容/配置/任务或额度变化会失败。
5. 重复三轮，累计创建 7 个模型。每轮分别观察 2/3、4/5、6/7 是否还活着，不用首窗可能受工具查询影响的存活状态代替新窗结论。
6. 最后关首窗，无外部查询地记录零窗状态 +5/+20 秒，退出自身。驱动总超时 160 秒，CI 子进程超时 180 秒；失败仍归档日志。

驱动只长期保存窗口 ObjectIdentifier、时间与状态哈希，窗口/菜单/模型引用局限在本次同步回调；没有长期保存 OpenWindowAction、模型或菜单项。记录器仍使用弱模型表。未更改 RootView/Router 业务持有关系或依赖缓存。

[Apple 的菜单 API 文档](https://developer.apple.com/documentation/appkit/nsmenu/performactionforitem(at:))说明该调用会发送菜单通知、突出显示菜单并发送无障碍通知。因此这里是“无外部查询”，不能表述为系统完全没有 AX 活动。与 #101 的 openWindow 双窗协议也不能混同。

## 证据与限制

49 项 Python 校验和项目语法检查通过。校验拒绝缺失第三轮、提前结束、保留稿变化、意外扣次与新窗口未清空；模型继续存活是如实报告的结果，不能自动算作协议失败或已证明生产泄漏。

本次源代码候选为 `db77088`，实际 Release 构建及运行结果待补。合成单元测试仅验证协议失败分支，不是真实运行证据。

最低系统实际运行、签名/Xcode Cloud、1/10 MiB 导入转换导出、活动任务中关闭、焦点/IME/键盘及手动 reopen/Settings 仍为独立验收。不会因这项短文稿循环通过而关闭 #90/#93 或整个性能跟踪。

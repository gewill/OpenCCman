# #93：宿主强捕获闭包的分配来源

零窗快照进一步定位到了 **AppKit 创建的通知闭包**：两个存活宿主各有一个明确标为 `__strong [capture]` 的 `__NSMallocBlock__` 入边；对应的分配栈均经过 `NSView._commonAwake` → `NSNotificationCenter.addObserverForName:object:queue:usingBlock:` → `_Block_copy`。这是系统视图初始化路径中的分配，不是最小复现程序自己的业务通知回调。

这证明了闭包的分配来源和闭包到宿主这一段强引用，**没有证明完整持有根因或闭包最终所有者**。后续[真实 OpenCCman 诊断包](native-app/README.md)也取得相同分配路径，但仍不能推断全部生产场景的根因。不据此清空文稿、改写业务模型、移除系统通知或禁用无障碍。

## 过程和复核

- 源码 `24f879800a5d8407b5adc4b54d7d12fceeec3e3e`，工作区干净；使用现有 `prepare-minimal-window-lifetime.py --variant text --automatic --observe-hosts`，生成源码与[原先对照](../Probe.swift) SHA256 相同。
- 本机 macOS 27.0 (26A428)、Swift 6.4、arm64、Swift 5 / `-O`；仅诊断程序最低 macOS 13，应用最低系统未改。
- 将隔离诊断包的可执行文件名、bundle ID 改为唯一名称，并在它自己的 Info.plist 加入 `LSEnvironment = { MallocStackLogging = 1; }`，随后重新 ad-hoc 签名。无全局环境变量或系统设置变更。构建脚本只构建，实际通过 CUA `getApp` 正常启动。
- 首窗由启动操作读取 AX；第二窗可见期间另读一次 AX，确认 `lifetime-AppWindow-2`。无录屏，未再次访问已关闭窗口。固定时序和弱观测器保持原样。
- 最终关窗 +5 秒样本写入后执行 `leaks --noContent --outputGraph=zero-window.memgraph <PID>`。之后仅离线使用 `heap --noContent --addresses=all`、`leaks --noContent --debug=<address> --debug=layout` 与 `malloc_history <memgraph> <address>`。
- 原始样本通过现有 `validate(rows, require_hosts=True)`；分配栈实际解析成功，不只依据环境变量认定已启用。原始 memgraph、全量分配和对象布局只留本机，公开 SHA256 与下列限定摘录。

| 样本 | 模型 / 窗口 / 初始宿主 | 条件 |
| --- | --- | --- |
| 关第二窗 +5 / +20 秒 | 2 / 1 / 2 | 全程开启分配栈记录 |
| 最终关窗 +5 秒 | 2 / 0 / 2 | heap capture 前 |
| 最终关窗 +20 秒 | 2 / 0 / 2 | heap capture 后，不能当作无工具对照 |

程序 PID 34235 已自行退出；测试前的独立偏好已逐项恢复并读回验证；诊断包改名为 `.app.inactive`。未操作其他验收应用、模拟器或 VoiceOver。[清理记录](cleanup.json)。

### 同二进制的首窗查询对照

随后使用同一签名二进制、相同进程级栈记录环境再运行一次（PID 40387），仅由 CUA 启动时查询首窗，不在第二窗可见时调用 AX、截图或录屏。固定时序、日志验证和最终 +5 秒后的 heap capture 相同。

| 条件 | 关第二窗 +5 / +20 秒：模型 / 窗口 / 宿主 | 最终关窗 +5 秒 | 最终 +20 秒（heap 后） |
| --- | --- | --- | --- |
| 仅首窗查询 | 1 / 1 / 1 | 1 / 0 / 1 | 1 / 0 / 1 |
| 两窗均查询 | 2 / 1 / 2 | 2 / 0 / 2 | 2 / 0 / 2 |

[对照原始样本与来源](control/)证明：开启栈记录时，未查询第二窗的窗口、宿主和模型仍能释放。剩下的首窗宿主也有同一 `NSView._commonAwake` 通知注册分配栈。因此，这个成对观察继续支持查询条件与存活的关联，但不能将“存在该通知闭包”本身当作唯一根因；未取得已释放第二窗 block 的全生命周期证据。对照也已退出、恢复偏好并停用诊断包。

## 入边和分配栈

两份宿主布局均报告 `REFERENCES TO THIS: 71 STRONG: 3 CONSERVATIVE: 29 WEAK UU etc: 39`。这些是工具对此快照的分类，不是源语言所有引用的完整证明；不能把 71 条扫描入边都解释为强持有。

| 宿主 | 工具明确标 strong 的入边 | 分配栈证据 |
| --- | --- | --- |
| `0x75ff144000`，首次启动创建 | NSMutableSet storage、NSMutableArray storage、block `0x75ffcd0d50` | [强入边摘录](first-host-incoming-excerpt.txt)、[block 布局](first-host-block-layout.log)、[分配栈](first-block-allocation.txt) |
| `0x75ff146800`，`LifetimeDriver.tick` → `OpenWindowAction` 创建 | 同类两项集合 storage、block `0x75ffccc390` | [强入边摘录](second-host-incoming-excerpt.txt)、[block 布局](second-host-block-layout.log)、[分配栈](second-block-allocation.txt) |

第二个 block 的扫描入边来自 `_CFXNotificationRegistrarAddObserver` 分配的存储区，**该存储区到 block 的边没有 strong 标注**。旧快照的两个集合入边可追到 NSThemeFrame 的 `_subviews` 与 `_geometryInWindowSensitiveSubviews`，但这仍不能给出框架对象从根到模型的全强引用链。无障碍节点的 `viewRendererHost` 在旧快照明确标为 weak，也不能将其误写成直接强持有宿主。

分配栈显示 block 在创建视图时已分配；仅凭随后 AX 查询与存活相关，不能声称“AX 查询创建了这个闭包”，也不能证明它就是唯一阻止释放的原因。

## 下一步与边界

1. 实际 OpenCCman 隔离诊断候选已验证相同宿主/block 分配路径，见[真实应用记录](native-app/README.md)。其弱窗口观测、工具链、文本与系统边界不同，不能将两份协议拼成完整产品验收。
2. 同二进制的无第二窗 AX 查询对照已完成；继续确定 registrar/窗口框架对象的所有权及清理时机。分配栈记录与 heap capture 均需作为独立实验条件。
3. 只有找到可验证的应用代码持有错误后才修改生命周期；若最终定位为系统行为，形成有复现步骤和环境边界的反馈。当前不声明已确认系统缺陷。

#93、#18 继续开放。本次没有应用修复、性能收益、三端或最低系统验收结论。工具使用依据 Apple 的 [Detect and diagnose memory issues](https://developer.apple.com/videos/play/wwdc2021/10180/)：分配栈和 reference tree 帮助定位对象来源与可能所有者；快照不能单独证明所有路径的强弱语义。

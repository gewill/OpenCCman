# #22：当前源码的 Release Services 容量补测（2026-09-24）

本报告补足 [#22](https://github.com/gewill/OpenCCman/issues/22) 在当前 `develop` `736108a0a1a1622e318f20bb70d83416b19b4f3f` 上的同步服务调用样本。**10 MiB 的 `NSPerformService` 输出正确；TextEdit 目标 App 的 10 MiB 菜单转换仍未取得结果。**两者是不同的验收范围，因此本次不制定新的 Services 容量上限，也不关闭 Issue。

## 来源与协议

本机为 Apple M4 Pro／48 GiB、macOS 27.0 (26A428)、Xcode 27.0 (27A266a)。从上述提交构建 Release `-O`，复制为独立 bundle `org.gewill.OpenCCman.ServicesReleaseQA20260924`，保留原沙盒 entitlement 并 ad-hoc 签名；`codesign --verify --deep --strict` 通过。QA 提供者的独立服务名为 `OpenCCman Capacity Release QA Convert`，在 `pbs -dump` 中核对注册。没有调用已安装的正式 App、改动其偏好或触发云端打包。[来源、构建、签名、工具与设置](context.json)逐项记录哈希。

第一次试测时 QA 包延后显示 What’s New，可能混入主线程工作；这些 [Debug](exploratory-debug/) 和 [Release](exploratory-release/) 样本归档但**不参加下表统计**。随后在 QA 包关闭卡片、退出并重启，独立偏好 `lastPresentedWhatsNewVersion` 为 `2.0`，最终取样前后没有该弹窗。转换配置为默认 `s2t`，提供者进程在整套最终取样中保持同一 PID。

使用锁定 OpenCC 1.4.2 CLI 和同版本资源生成短段落、长段落的 UTF-8 语料与期望输出；[语料清单](fixture-manifest.json)记录字节数及 SHA-256，正文大文件仅在本机 `/tmp` 重建，不提交。生成入口：

```bash
python3 scripts/generate-services-fixtures.py \
  --cli /opt/homebrew/bin/opencc \
  --resources /tmp/openccman-22-sourcepackages/checkouts/SwiftyOpenCC/Sources/OpenCC/Resources \
  --output /tmp/openccman-22-target-fixtures-20260924 \
  --modes s2t --sizes 1024 1048576 5242880 10485760
swiftc -O tests/Benchmarks/ServicesWaitProbe.swift -o /tmp/openccman-22-services-wait-probe-20260924
```

最终 [原始记录](final/)包含一次独立 1 KiB 预热，以及每档连续五次调用。另用同一提供者、每次新起一个调用方进程、相邻调用间隔两秒，分别对 10 MiB 短／长段落各取五次。每组最多等待 35 秒；全部调用正常结束、服务返回成功、输出完整字节与同版本 CLI 期望一致。计时只覆盖同步 `NSPerformService`，输出读取、编码、哈希与比较均在计时后；不是目标 App 恢复可编辑或画面呈现时间。[汇总 JSON](summary.json)保留每次原始时延和文件路径；下表为五次中位数（最小–最大），没有剔除慢样本。

| 请求节奏／语料 | 输入 | `NSPerformService` ms | 正确数 |
|---|---:|---:|---:|
| 连续／短段落 | 1 KiB | 108.181（106.450–121.549） | 5/5 |
| 连续／短段落 | 1 MiB | 106.870（105.826–122.569） | 5/5 |
| 连续／短段落 | 5 MiB | 523.083（210.774–525.981） | 5/5 |
| 连续／短段落 | 10 MiB | 1043.724（537.746–1147.379） | 5/5 |
| 间隔两秒／短段落 | 10 MiB | 335.930（331.340–862.792） | 5/5 |
| 间隔两秒／长段落 | 10 MiB | 334.402（333.220–968.962） | 5/5 |

连续 5／10 MiB 请求的后几次明显较慢，而间隔请求多在约 0.33 秒，故不把单个数字宣传为容量承诺或用户体验。当前证据不能区分文本视图回写、Services IPC、系统调度、热状态及其他负载的贡献；没有同步采集阶段内存／主线程堆栈，也未据此改代码。旧版 [Release 服务测量](../2026-09-15/README.md)采用不同源码和条件，不能与本轮直接计算优化百分比。

## 目标 App 与尚缺证据

作为 UI 链路冒烟，TextEdit 用独立 1 KiB TXT 副本选中全文，通过 QA Services 菜单转换并保存；保存文件为 1024 字节，SHA-256 `79063c4fb646e9d1f78c2f32a71d493949f8f0ef6e7f40666552c477e912704c`，与 CLI 完全相同。[此前同一菜单的真实前后截图](../2026-09-24/README.md)提供界面参照，但不作为本次大文稿结果或视频证据。

TextEdit 另正常打开了 10 MiB 测试副本，并在全文选中时列出 QA 转换项；电脑操作接口点击该项返回 `elementHasNoFrame`。尝试展开子菜单仍无法取得可操作项，最终测试副本保持原始 10485760 字节及输入 SHA-256 `8a020df3f5bf1f4e69a4b080da6616d69448a39a30e01a35b3683a8518edb816`。这只能证明自动化没有完成调用，**不能判定 TextEdit 对 10 MiB 成功、失败或超时**。先前 [1 KiB／1／5 MiB TextEdit 单次结果](../2026-09-24/README.md)仍有效；第二种真实目标 App、重复 UI 操作、失败/超时后的原稿保护、最终签名包和最低 macOS 12 都还缺证据。

现阶段保留既有产品语义：主页单文件上限仍为 10 MiB，不从本报告推出新的 Services 上限。下一轮应在可操作的目标 App 菜单上获取 10 MiB 及第二宿主的保存结果与用户等待体验；如果实测出现不可接受等待，再依据该结果选择提示或引导文件工作流，并验证不丢稿。#22 保持开放。

[清理记录](cleanup.json)确认两份隔离提供者已退出并撤销服务注册，专用偏好文件不存在，测试 App 副本移到废纸篓；TextEdit 的 10 MiB 测试副本仍与原始输入逐字节相同。未触碰正式 App 或更改 VoiceOver。

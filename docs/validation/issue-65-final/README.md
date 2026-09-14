# #65 最终源码验收与性能基线

2026-09-14，针对 `develop` 合并 #66、#67 后的 **`5d527bd3978d73be5f028804d579c86da0f66752`**。本次只补验收资料，不修改应用、依赖或发布分支。#65 保持开放；真实辅助技术与最低系统验收边界见下文。

## 结论与覆盖范围

| 项目 | 本次结果 | 证据／限制 |
|---|---|---|
| Mac 原生编辑器 | 通过 | [日志](checks/editor-scroll.log)：1／5／10 MiB、编辑器身份、阅读锚点、选区、marked text、改宽交错导航、换稿；marked-text 测试不等于真实中文输入法 |
| 测量协议 | 26 项通过 | [日志](checks/protocol-tests.log)，没有修改测试或增加等待 |
| 最终源码转换基线 | 5 个独立进程完成 | [原始数据](conversion/)，七组配置、首次／热转换、1／5／10 MiB、导入导出校验、诊断窗口周期 |
| 最终源码重排基线 | 3 个独立进程完成 | [原始数据](reflow/)，1／5／10 MiB × 首／中／尾 × 上下／左右，原生编辑器身份／选区／全文哈希检查 |
| iPhone 实际运行 | 本轮用例通过 | iOS 18.6，1 MiB 内部滚动、设置开关、输入与软件键盘；1／10 MiB 转换、完整复制逐字节一致 |
| iPad 实际运行 | 本轮用例通过 | iOS 18.6，1 MiB 滚动后两轴切换、编辑保留、结果只读；1／10 MiB 转换、完整复制逐字节一致 |
| Mac 普通应用键盘抽查 | 本轮用例通过 | Cmd-T、Cmd-Option-1/2、段落 050 的英文输入及布局切换；并非完整纯键盘流程 |
| VoiceOver／真实中文输入法 | 未通过验收 | 已尝试，工具没有取得可靠朗读／marked-text 交互证据；保留 #20 |
| iOS 14／macOS 11 | 未运行 | 维护者没有设备，按已确认决定保留 #16 发布前验收 |

[三端实际截图、交互视频及环境](runtime-evidence.md) · [移动端字节校验](checks/mobile-results.json) · [媒体哈希与 gh 上传记录](checks/media.json)。截图对照是同一源码不同布局／状态，没有新增 UI 修改；#67 的历史修复前后证据见[原报告](../../performance/2026-09-14-textkit/README.md)。

## Mac 测量条件

- Apple M4 Pro，48 GiB，arm64；macOS 26.6.2 (25G83)，Xcode 26.6 (17F113)。
- 两个全新、独立输出目录分别构建 **Release -O** 诊断包，应用源码与测量入口均来自上述最终提交。构建时工作树干净；在所有采样完成后才添加本文档。原始 `metadata.json`、`build-complete.json` 和 `run-*.json` 原样归档，未改写来源或计时。
- 测量协议 2；1200×800pt 内容区、英文、浅色；每次新进程，未清除 OS／文件缓存。不能将此处冷启动等同冷机启动。
- 先完成两套构建，再关闭模拟器，顺序采集 3 次重排、5 次转换。实际采样期间未进行录屏、AX 查询、profiling 或并行构建。普通应用的 UI 录像在独立环节采集，不用于这些性能数字。
- ad-hoc 签名、独立诊断 bundle／偏好、关闭 sandbox；保留 RevenueCat configure，使用合成 Pro 并抑制刷新／delegate／评价／What's New。不是 TestFlight 或正式签名产物。
- SwiftPM 精确 pins、实际 checkout revision、构建来源和产物哈希均记录在归档中。没有升级依赖或修改开发者已有的 Package.resolved。

## 可重复的描述统计

运行 `python3 docs/validation/issue-65-final/analyze.py` 可重新生成 [analysis.json](analysis.json)。转换数据先经过现有比较器校验；重排另校验完整 18 个布局阶段、9 个滚动阶段、内容哈希、前台可见窗口、内存采集成功与 provenance。表格为中位数及最小—最大值，不作统计显著性声明。

### 转换套件：5 个新进程

| 指标 | 中位数 | 范围 |
|---|---:|---:|
| OS 进程起点 → 首个根布局 | 650.89 ms | 577.54–2328.11 ms |
| App 初始化 → 首个根布局 | 536.13 ms | 470.50–612.76 ms |
| 首次转换，256 KiB | 54.80 ms | 47.94–55.64 ms |
| 热转换，256 KiB | 27.23 ms | 25.52–31.65 ms |
| 1 MiB 转换 | 30.52 ms | 27.63–48.26 ms |
| 5 MiB 转换 | 113.82 ms | 110.63–116.49 ms |
| 10 MiB 转换 | 201.32 ms | 199.77–211.43 ms |
| 全套进程峰值 RSS | 341.44 MiB | 337.03–350.41 MiB |

热转换先求每个进程 5 次操作的中位数，再对 5 个进程汇总。首次启动最慢样本保留，没有按离群值剔除。转换时间是模型完成时间；`result_layout_flush_ms` 是后续确认／flush，不是完整画面呈现，不能两者相加后宣传端到端延迟。

全部七种有效配置都运行并校验完整编辑器与导出内容。模型关闭检查中，两轮手动托管窗口累计 4 个模型仍存活（每次运行相同）；该入口不是原生 WindowGroup 生命周期，不能证明生产多窗口释放通过，也不能凭此断言生产泄漏。#18 仍需原生窗口生命周期证据。

### 重排套件：3 个新进程

| 10 MiB 选区位置 | 上下布局，ms | 左右布局，ms |
|---|---:|---:|
| 首部 | 20.00（14.79–32.02） | 21.11（20.34–22.56） |
| 中部 | 22.05（21.58–22.46） | 29.29（29.15–33.34） |
| 尾部 | 17.50（16.43–30.86） | 24.02（21.64–24.49） |

以上是通知切换到两次 UI yield／布局 flush 的操作区间，停表后才校验全文。重排套件峰值 RSS 中位数 **381.38 MiB**（379.13–388.50）。包括语料、转换结果、哈希校验与先前阶段，不是 OpenCC 核心独占内存。

基准入口检查编辑器身份、选区和全文；实际可见字形范围／阅读锚点由独立原生回归验证。不能仅凭此表证明每帧呈现或所有滚动锚点。语料有换行，没有无换行单段 10 MiB 的等价延迟承诺。

全套 20 ms 主线程定时器的最大间隔仍为：转换中位数 **438.29 ms**（433.48–441.19），重排 **759.38 ms**（759.09–768.25）。该计数累计包含诊断入口造语料、全文校验、调度等工作，不能归为某次 UI 交互；本报告没有证明“主线程从不卡顿”。如要进一步归因，应在正式路径单独录制 Instruments，不把这些数字当作 FPS。

本轮只重测最终源码，没有同步重测旧核心对照，不生成新的升级提速百分比。升级前后结论继续引用[协议 2 修正报告](../../performance/2026-09-14-review/README.md)。以后比较必须保持源码入口、协议、语料和条件可比；旧协议／旧 metadata 不能补写成新基线。

## 复现命令

从本文标注的源提交建立隔离 checkout；为两套实验使用全新目录。首次构建使用精确 pins；本次 `--packages` 指向隔离的锁定版本 checkout，没有修改共享缓存。

```bash
python3 scripts/benchmark-app.py --output /tmp/openccman-65-final-reflow --reflow --packages /tmp/openccman-66-v2b-new/packages --build-only
python3 scripts/benchmark-app.py --output /tmp/openccman-65-final-conversion --packages /tmp/openccman-66-v2b-new/packages --build-only
# 两套构建完成后独立采样，不并行运行 UI、录屏或其他构建。
python3 scripts/benchmark-app.py --output /tmp/openccman-65-final-reflow --reuse-build --reflow --samples 3
python3 scripts/benchmark-app.py --output /tmp/openccman-65-final-conversion --reuse-build --samples 5
bash scripts/check-editor-scroll.sh
python3 -m unittest discover -s Tests/Benchmarks -p 'test_*.py'
python3 docs/validation/issue-65-final/analyze.py
```

本地目录路径是此次记录，不要求其他机器存在。换机器复现时应更换输出和 packages 路径，不能篡改归档条件。

移动端使用普通 Debug 目标与独立 bundle `org.gewill.OpenCCman.Validation65`，源码没有注入基准入口。iPhone 15 Pro Max 与 iPad Air 11-inch (M2) 均为 iOS 18.6 模拟器，分别 430×932pt、820×1180pt。验收通过应用“Paste Text”输入，再转换和“Copy Result”读回；不是文件导入／保存面板验收。合成 fixture 可单独复现：

```bash
python3 docs/validation/issue-65-final/mobile-fixture.py --mib 1 --write /tmp/openccman-fixture.txt
python3 docs/validation/issue-65-final/mobile-fixture.py --mib 10 --write /tmp/openccman-fixture-10MiB.txt
python3 docs/validation/issue-65-final/mobile-fixture.py --mib 10 --verify-copy /path/to/copied-result.txt
```

该校验只针对固定句子与 Traditional/OpenCC 配置。两端 10 MiB 输出哈希均为 `bdd6bb8e7dd86c248f26dfd1e7c1d40cff00c4b1732da5f55b468ac617114d53`。1 MiB 额外验证实际滚动、编辑、布局／键盘；没有把 10 MiB 的转换复制通过写成全套交互矩阵通过。

## 尝试记录与剩余项

- iPhone 首轮出现系统评价弹窗，AX 快照仍给出底层应用按钮；部分操作实际被弹窗拦截。取消评价后重新执行，完整输出校验通过，没有提交评分。iPad 在滚动后的旧位置误触系统文件面板，取消后用新进程、实际输入字节数和复制哈希重测 10 MiB。未将这些失败操作算作通过或应用性能问题。
- 大文本 AX 树包含全文，工具快照可能超时；只有实际界面、内容与哈希确认才记录通过。等待惯性滚动停止后再比较 iPad 两轴位置；不把惯性期间的段落变化判为锚点缺陷。
- VoiceOver 开关已在系统设置验证 on，但工具定向按键没有获得可判定的完整导航／朗读结果；随后恢复 **off** 并确认无 VoiceOver 进程。Mac `n`、`i` 输入落为英文，没有中文候选／组合阶段证据，因此 #20 保留。
- 两台模拟器剪贴板恢复并关闭；使用独立验证 bundle，未改动开发者的原工程工作区或系统输入源。没有触发正式发布。
- 仍需 #20：真实 VoiceOver、完整 Tab／快捷键／错误与文件流程、真实中文输入法；#16：iOS 14／macOS 11；#18：原生 WindowGroup 释放、正式签名产物的性能／文件访问。最低系统按维护者决定留作发布前验收。
- 本轮未覆盖完整主题／语言／最大字号矩阵、iPad 旋转／窄窗口／软件键盘、转换／取消／导入导出任务中切换等全部既有 UI 门禁；已通过的本轮子集不关闭总体验收 Issue。>10 MiB Pro 继续归 #52。

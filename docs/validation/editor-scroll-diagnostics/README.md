# 滚动断言诊断补充（2026-09-15）

## 问题与改动

[历史 CI 失败](https://github.com/gewill/OpenCCman/actions/runs/34949741507/job/104317719921)在初次变宽后的阅读锚点断言退出，只有“Width reflow must retain…”消息，没有前后行范围；同源码另一次 PR CI 通过，原因尚未确定。[#20 的原始记录](https://github.com/gewill/OpenCCman/issues/20#issuecomment-5677727776)保持开放。

本次只修改 `Tests/Regression/EditorScrollChecks.swift`，在原有三个行锚点判定处同步写出 JSON：前后字符行范围、clip bounds、编辑器 frame、选区、是否已挂载窗口、系统版本与判定结果。使用原本已查询的行范围，不为诊断增加 TextKit 布局查询。扩充失败消息中的实际值。

生产 `WorkspaceScrollKeeper`、等待的 0.08 秒、原判定式与容差、测试顺序均保持原样。日志在判定完成后、断言前同步写至 stderr，避免程序终止丢失缓冲内容。该修改提供下次失败的证据，不宣称修复滚动问题。

## 本机固定次数验证

基线 `f51b6fd4ea1e922ca83b67440537f554d6ba1619`，候选测试源码与生产源文件 hash、Xcode/Swift/macOS 版本见 [source.json](source.json)。使用原脚本完成一次入口验证，再预先固定五个独立进程顺序运行同一测试二进制；没有按结果追加重复、放宽断言或延长等待。

- [原脚本入口](script-entry.log)通过；三个诊断场景均输出具体值。
- [五次完整结果](summary.json)均退出 0，包含 15 条行锚点记录；每次原生编辑器的长文、选区、组合文字范围、新文稿及导航竞态检查亦执行到最终 PASS。
- 日志：[1](trial-1.log)、[2](trial-2.log)、[3](trial-3.log)、[4](trial-4.log)、[5](trial-5.log)。初次变宽的前行范围均为 `{6705,77}`，后行范围为 `{6640,153}`，后行包含旧行起点；该阶段是未挂载窗口的原生控件测试，不能把它当作生产 WindowGroup 运行。

本机 macOS 27 的这五次通过只说明此条件未复现历史失败，不能归因原失败为负载、也不能证明所有 CI/系统稳定。保留原失败；后续 CI 再现时直接比较新日志的边界和实际行范围。

## 诊断路径的失败注入

在 `.build` 中的测试副本，为首个判定临时追加 `&& !CommandLine.arguments.contains("--fail-first-anchor")`，运行时传该参数；未把注入条件加入提交的测试源码。

[结果](forced-failure.json)为退出码 -5（SIGTRAP）；`passed:false` 的 JSON 和包含 before/after 的断言消息均在[失败日志](forced-failure.log)中保留。[构建日志](forced-build.log)亦保留。这里的 false 由注入产生，实际前后行仍满足原几何条件，**仅证明失败诊断链路，不是历史滚动问题的复现**。

## 剩余验收

#20／#65 的真实输入法、VoiceOver、完整键盘、目标版本及最终产物验收不由这组测试替代。测试程序已结束；本轮未启动实际 OpenCCman 验证副本、未修改系统设置，也未开启 VoiceOver。

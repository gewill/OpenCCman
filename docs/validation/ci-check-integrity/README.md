# CI 检查退出状态修正（#82，2026-09-15）

## 已复现

runner 没有 `rg`，两个 shell 检查使用 process substitution 获取文件列表。生产者失败未传播到外层，Bash 3.2 对空数组的展开错误也没有让这个脚本最终返回失败。

[旧版真实复现](baseline-exit-codes.json)：在隔离副本中以 `/usr/bin:/bin:/usr/sbin:/sbin` 执行 `461b5bb` 的旧脚本，两项均报 `rg: command not found` 却返回 0；尺寸脚本另报 `sources[@]: unbound variable`。

原始 CI：[34949741507](https://github.com/gewill/OpenCCman/actions/runs/34949741507) / `eab5003`，两项被标成成功但有上述错误。#80 的 [34947427072](https://github.com/gewill/OpenCCman/actions/runs/34947427072) 也有相同日志。因此撤回“这些历史绿色步骤证明实际解析／控件测试成功”的含义；#80 另有本地工程检查、实际完整 Mac／iOS 构建和页面运行证据，不依赖这两个假阳性的步骤。

## 修复

工程入口改为 `exec` Python 检查：枚举错误、缺失目录、空源文件／本地化列表均报错；每个实际 `swiftc`／`plutil` 调用检查退出码。保留原 shell 入口，现有调用者不必改名。

控件入口在普通受检查的 Python 命令中生成 NUL 分隔清单，确认非空后读入数组；不再依赖 process substitution 或 runner 额外安装 rg，保留带空格／换行的文件名。实际编译和测试退出码继续由 shell 传播。

## 验证

- 本机 macOS 27.0（26A428）／Xcode 27，在无 rg PATH 中实际解析 [58 份 Swift 源码、3 份本地化](project-without-rg.log)。
- 同样环境编译锁定 Neumorphic 并实际执行[完整控件尺寸检查](controls-without-rg.log)，通过。第三方 Text 拼接弃用和临时路径双斜杠 linker 提示保留，没有抑制或更改依赖。
- [九项脚本回归](negative-checks.log)：真实语法／strings 格式错误、缺失／空目录、带空格文件名、带换行的无效源码，以及注入枚举命令／测试进程失败的退出码。`python3 Tests/Regression/CheckScriptChecks.py` 可复验，CI 在工程检查前执行。
- [独立原生滚动本地复验](editor-scroll-local.log)。本修复不修改滚动代码或断言，也不扩大等待时间。

## 独立未解决问题

`eab5003` 的手动工作流在原生滚动首个 `Width reflow must retain the old top character's line` 断言失败；同源码 PR 工作流 [34949742984](https://github.com/gewill/OpenCCman/actions/runs/34949742984) 通过。保留到 #20／#65 继续诊断，不归因为 rg、并行负载或简单通过重跑关闭。不以本 PR 声称已修复滚动不稳定。

CI 新提交检查结果待 PR 记录。没有修改 UI、依赖、语言模式、部署下限或发布流程。

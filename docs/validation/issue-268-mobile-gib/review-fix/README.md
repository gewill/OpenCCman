# PR #271 评审修复验证

日期：2026-10-01。[原评审](https://github.com/gewill/OpenCCman/pull/271#issuecomment-5928337045)。
修复源码：`044480cfaf356363af642d06a4ddf80d68187209`；修复前：`802e9eea55c9c420c9e005d77446e6844b944447`。
逐文件哈希见 [source.json](source.json)。本目录替代初次候选中关于默认容量查询有效性及宽松 journal 格式的结论；
父目录原日志仍对应当时源码，不改写为修复后的证据。

## 修复

1. `Hooks.availableBytes` 每次查询前清除 URL 的 resource cache，防止 serial worker 上重用旧读数。
   Foundation 的 resource values 会先使用 URL 缓存；没有 run loop 的工作队列不能依赖自动清理。
   参考 [Apple NSURL resourceValues](https://developer.apple.com/documentation/foundation/nsurl/resourcevalues(forkeys:))。
2. 非 Pro 导入 >100 MiB 时使用三语实验专用文案；10–100 MiB 沿用原提示。
   文案精简至实际弹窗能完整显示，保留上限、实验性质、逐任务确认及失败风险。
3. 完成记录只接受写入端实际生成的两种形式：`schema 1` 无 capacity、`schema 2 + experimental`。
   测试改用服务真实写出的实验记录为有效基准，拒绝不存在的组合，保留未验证的输出。

## 验证与边界

| 项目 | 本轮结果 |
| --- | --- |
| 默认查询回归 | 无容量桩；同一个 worker 的不同 block 中删除目录后重新查询必须失败，重建后恢复。旧服务运行新测试明确失败，修复后通过。 |
| 同一 service 实例真实落盘 | 写入并同步 256 MiB 后，导出及下一任务预检都读到新的容量；仅用 observer 转发默认生产查询，没有返回模拟值。 |
| Native Release / 恢复 | 2 个 XCTest case 通过，5 个真实 SIGKILL 后的新进程恢复通过。 |
| iOS Release 服务 | iPad Pro 13-inch (M4) Simulator / iOS 18.6，3 case 通过，0 失败/跳过；包含默认查询、journal 与生命周期适配器。 |
| 核心 | 共享 stream、七配置 × 11 语料、文件、Mac、Shortcuts、模型/配额回归通过。 |
| 完整 App 构建 | Xcode 27.0 (27A266a)，macOS Debug arm64+x86_64 和 iOS Simulator Debug arm64 通过，禁止签名、锁定依赖。 |
| 文案 UI | XCUITest：三语实验提示与英语标准容量提示，最终 4 case 通过；另有旧包三语对照 3 case。截图人工逐张检查，文字完整。 |
| 静态检查 | 项目、三语、控件脚本及 `git diff --check` 通过。 |

XCTest、核心及构建摘要见 [results.txt](results.txt)，[job-regression.json](job-regression.json)、
[ios-summary.json](ios-summary.json)、[ui-results.json](ui-results.json)。SwiftyOpenCC 仍固定
`564b094b2b69f2c1e907fa3d89fe6845469a4e4e`，未改依赖或其缓存。

实际空间结果见 [capacity-refresh.json](capacity-refresh.json)：

| 时刻 | 系统返回可用字节 |
| --- | ---: |
| 落盘前 | 187169329781 |
| 落盘后导出检查 | 186900886133 |
| 同一 service 下一任务预检 | 186900894325 |

实际分配 268435456 字节，导出读数减少 268443648 字节，下一任务减少 268435456 字节。
这说明缓存已刷新，**不表示存储容量估算能保证转换成功，也不是物理耗尽磁盘测试**。
真实容量探针需至少 1 GiB 可用空间，仅写入并清理自己的临时目录，作为显式 opt-in，
不放入 CI，以免其他进程的容量变化造成波动。无容量桩的目录删除回归已在常规核心测试执行。

```bash
python3 scripts/check-mobile-file-jobs.py --output "$NEW_OUTPUT_DIRECTORY" \
  --opencc-path "$PINNED_OPENCC_CHECKOUT" --check-capacity-refresh
```

## UI 复现与限制

使用独立 QA bundle `org.gewill.OpenCCman.WhatsNewUITests`，iPhone 16 Pro Simulator，
iOS 18.6 (22G86)，402×874 pt / 1206×2622 px，浅色、默认字号。
非 Pro 由 launch argument-domain 的 `-isPro NO` 指定；不修改正式偏好或真实购买状态。
输入是 QA Documents 的稀疏 TXT，实验对照大小 100 MiB+1，标准路径为 10 MiB+1，
仅验证导入后提示，不读取全文或开始转换。

构建 `Tests/UI/WhatsNewPresentation`，在生成的 xctestrun 中为 `testMobileNonProCapacityMessage` 设置：

```text
OPENCCMAN_MOBILE_FIXTURE=<QA Documents 下的独立 TXT>
OPENCCMAN_MOBILE_LANGUAGE=en / zh-Hans / zh-Hant
OPENCCMAN_MOBILE_EXPERIMENTAL=1
OPENCCMAN_MOBILE_PRO_EXPECTED_TEXT=<当前对应本地化文案>
```

测试等待完整 AX label 后截图；长文本采用 NSPredicate 查询，避免 XCUITest identifier 的 128 字符限制。
初次英文测试因该测试 API 限制失败，初版新文案截图也暴露截断；两项均已修正，再跑最终 4 case。
旧包、最终截图哈希在 ui-results 中，上传链接见同目录 media.md。没有用失败截图充当最终效果。
本轮只改文案，没有新增按钮交互；二次确认交互录像仍见父目录 [media.md](../media.md)。

## 未转为通过的验收

`productionEnabled`、`experimentalCapacityEnabled` 继续为 false。#260 既定 100 MiB 验收及真实 iPad、
#268 低内存真机/完整容量矩阵/实际提供方/内存存储峰值/锁屏后台/大字号深色 VoiceOver 继续开放。
本轮未改 VoiceOver 或用户设备设置；完成后关闭本任务的专用模拟器。
最低系统保留 #16，真实权益保留 #14 / #71；不发布新包、不触发 Xcode Cloud。

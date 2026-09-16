# 合并后应用性能基线（#18）

通过 `App Regression` 的 `measure_app_baseline` 手动输入，对选定分支的精确提交运行现有协议 2。不触发 Xcode Cloud，不修改依赖或部署下限。

```sh
gh workflow run app-regression.yml --repo gewill/OpenCCman \
  --ref <candidate-branch> -f measure_app_baseline=true
```

固定 macOS 15 runner、Xcode 26.3、Release、锁定依赖和隔离诊断 bundle；顺序执行 5 个新进程。每进程覆盖首次转换、5 次热转换、七组配置、1/5/10 MiB 文稿和托管多窗口。原始样本、metadata、源码/产物校验和及构建日志保存在 `app-performance-baseline` artifact；失败仍上传已生成的文件，不把部分完成算通过。

新进程不等于冷缓存：不清除系统/文件缓存，首次根布局也不等于像素呈现或可交互时间。内存峰值包含语料、校验和此前操作；多窗口是诊断托管窗口，不代替原生 WindowGroup 生命周期。RevenueCat configure 保留、权益为合成 Pro，不能作为真实购买或发行签名验证。

该入口只在手动选择时运行，不给每个 PR 增加性能矩阵。常规 PR 继续运行必需 App Regression。时长是样本证据，不用任意绝对阈值判定跨机器性能回归；比较需核对环境、来源、协议和依赖。完整 #18 仍需同机升级前后对照及最终产物验收。

## 本次运行

[首轮实际运行 35065648719](https://github.com/gewill/OpenCCman/actions/runs/35065648719) 成功。测量源码为 `a37e8316226240551f95941446b488ef498d5433`；产品源码与整合后的 `develop@ce87387` 相同，该提交只增加 CI 入口和说明。后续提交增加的报告校验步骤已在下载的真实 artifact 上独立运行通过，不将后续文档提交声称为另一次测量。

环境：macOS 15.7.9 (24G830)、Xcode 26.3、arm64、VirtualMac2,1 / Apple M1 (Virtual)、7 GiB RAM。独立 5 个新进程，保留首轮较慢样本。

| 指标 | 中位数 | 最小–最大 |
| --- | ---: | ---: |
| 进程起点 → 首次根布局 | 808.95 ms | 715.35–2370.14 ms |
| 256 KiB 首次转换 | 98.35 ms | 93.30–116.23 ms |
| 256 KiB 第 5 次热转换 | 38.76 ms | 34.41–56.00 ms |
| 10 MiB 转换完成 | 377.36 ms | 351.36–410.84 ms |
| 采样峰值 physical footprint | 100.99 MiB | 98.29–101.58 MiB |
| 进程峰值 RSS | 303.64 MiB | 298.73–307.36 MiB |

每个样本均完成七组配置，前台/可见窗口及内存采集校验通过。两轮托管窗口关闭后，每个样本的 `all_extra_models_alive` 均为 `[0, 0]`。这不能关闭 #93：不同于生产原生窗口、辅助功能观察及活动任务关窗的持有链条件。

本次没有同机运行旧版，不从历史不同机器的数字计算加速比例。256 KiB 热转换只在表中展示第 5 次，全部五次均保留在原始数据；10 MiB 值是模型完成时长，不是完整导入/显示/导出时长。

原始数据位于 [2026-09-16 目录](integrated-baseline/2026-09-16/)，包含 metadata、5 份 run、汇总及文件校验和；完整构建日志保留在该 run 的 artifact 中（14 天）。metadata 固定了全部依赖 revision、构建环境、诊断改动及源码哈希。

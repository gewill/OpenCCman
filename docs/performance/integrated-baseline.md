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

尚未执行云端测量；待记录精确提交、run URL 与实际结果后更新本节。

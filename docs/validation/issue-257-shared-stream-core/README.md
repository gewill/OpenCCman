# #257：跨平台流式核心首项验收

日期：2026-09-30。任务：[#257](https://github.com/gewill/OpenCCman/issues/257)，总跟踪：[#256](https://github.com/gewill/OpenCCman/issues/256)，[完整技术方案](../../IOS_LARGE_FILES.md)。

## 实现与来源

共享 `StreamingConversionPump` 由 Mac 原有流循环提取，256 KiB串行读/转换/立即写，句柄由调用方持有。BOM处理、七配置、错误、取消共享；Mac仍负责源/目标指纹、安全域、同卷staging、同步关闭、协调原子提交和清理。

基线为 develop `9daa9c77eea9d9fb6b0952b63772d4f68baf3bfd`；测量发生在该基线上的未提交候选，精确复制源码及全部App Swift文件的SHA256见[sources.json](sources.json)。SwiftyOpenCC固定 `564b094b2b69f2c1e907fa3d89fe6845469a4e4e`，OpenCC `025f371dc76b598d77384fbdab90c937471844d8`。依赖锁文件未漂移。完整工作树与新生成的依赖clone隔离，不修改旧工作区、依赖缓存或正式App。

## 实际结果

| 验证 | 实际结果 | 证据 |
| --- | --- | --- |
| 共享核心、完整模型/文件/Shortcuts回归 | PASS；七配置、固定/有种子随机块、BOM/内嵌U+FEFF/NUL/IDS/Unicode、输入增长/缩短、非法末尾UTF-8、读写故障、取消、调用方句柄；原有文件/模型规则通过 | [core.log](core.log) |
| iOS Simulator原生XCTest | iPhone15Pro模拟设备、iOS18.6(22G86)、arm64、Release；2测试通过，0跳过/失败 | [ios-tests.json](ios-tests.json)、[ios-pass.log](ios-pass.log) |
| iOS 100MiB七配置完整哈希 | 每种配置104,857,600输入字节，完整输出哈希均与Mac独立整篇转换相同；含BOM/NUL/CRLF/IDS/Emoji/扩张词组 | [整篇oracle](ios-whole-file-oracle.json) |
| Mac原有1GiB服务路径 | 无换行及多行各一个新进程样本，完整输出哈希一致；额外取消保留已有目标并清理 | [无换行](mac-1gib-single.json)、[多行](mac-1gib-multiline.json) |
| Mac强退边界 | 20MiB转换中、提交前SIGKILL均保留源及旧目标；新进程正常输出正确；旧staging仍残留，由探针确认所有权后清理，不宣称生产恢复已实现 | [mac-force-kill.json](mac-force-kill.json) |
| 完整App构建 | Xcode27.0(27A266a)、Debug未签名；Mac arm64/x86_64和iOS Simulator arm64均成功；二进制部署下限12.0/15.0 | [app-builds.json](app-builds.json) |
| 工程/语言/标签/diff | check-project、check-app-language、check-control-labels及diff检查通过 | PR验证日志与对应检查脚本 |

100MiB输入由模拟器用64KiB tile逐块生成；输出按256KiB分块哈希。独立Mac oracle在另一个可执行target使用完整String转换，从未调用makeStream。对照不是重复流式算法，也不依赖任意分块拼接。三个带台湾词组配置的结果112,230,397字节，其余104,857,597字节；减少的3字节为开头BOM。

测试使用新建专用模拟器，结束后shutdown/delete，只清理本任务设备；未启动正式App、访问用户文档或调整VoiceOver等设置。Xcode隔离SwiftPM包使用Release＋ENABLE_TESTABILITY=YES和部署下限设置，生产应用的构建设置未改变。

## 重现

在清洁依赖checkout执行并初始化递归子模块；本次没有使用已经修改的wrapper工作区。

```bash
python3 scripts/check-core.py --opencc-path /path/to/clean/pinned/SwiftyOpenCC
python3 scripts/check-streaming-core.py \
  --opencc-path /path/to/clean/pinned/SwiftyOpenCC \
  --destination 'platform=iOS Simulator,id=<dedicated-simulator-UDID>' \
  --output /tmp/new-stream-core-evidence
python3 scripts/benchmark-streaming-files.py \
  --opencc-path /path/to/clean/pinned/SwiftyOpenCC \
  --sizes-mib 1024 --corpora single multiline --samples 1 \
  --output /tmp/new-mac-file-regression
python3 scripts/probe-streaming-force-kill.py \
  --opencc-path /path/to/clean/pinned/SwiftyOpenCC \
  --output /tmp/new-force-kill-probe
```

`check-streaming-core.py`输出原始日志、整篇oracle、源码哈希、原生xcresult与summary；输出目录必须新建。省略本地wrapper路径时按App锁定revision解析。它是独立共享核心测试宿主，不安装生产App。两个完整App构建使用[CI参数](../../CI.md)，本任务私有临时DerivedData、未签名验证bundle ID，Mac双架构及iOS Simulator arm64。原始完整日志的SHA256保存在报告里；仓库只存紧凑结果，不存100MiB语料或编译产物。

## 证据边界和下一步

- 本次不启用移动端大文件生产入口。定义100MiB策略和Simulator成功不代表整个App、低内存真机、文件提供方、锁屏恢复、保存或真实Pro已验收。
- Mac1GiB样本只用于本次正确性回归；执行时有其他构建并行，不能用其时间/RSS声明优化收益。iOS本轮没有进行整Appphysical-footprint测量，不能声称满足≤16MiB增长目标。
- #258继续实现受控快照、作业存储/恢复/清理和空间/文件metadata声明；#259接入UI和系统保存；#260取得设备容量及性能证据后开放。
- iOS15最低系统仍由#16承接；真实Pro链路由#14/#71承接。2.1已提审版本和线上定价没有更改，本任务没有触发Xcode Cloud。

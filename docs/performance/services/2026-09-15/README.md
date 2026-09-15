# 首组真实 Services 数据（2026-09-15）

应用包 `eab5003`，Xcode 26.3 Release universal，macOS 27.0（26A428），900×450 pt 的独立已开窗副本。显示语言 English、默认字号、浅色；转换配置为默认 Traditional / OpenCC / Not convert（s2t）。同一个提供者进程先完成 1 KiB 冒烟，然后按表格顺序逐例新建 CLI 调用方，每例连续 5 次调用；样本之间未人为插入等待，属于连续请求场景，不自动称为用户正常操作节奏。

[硬件与系统快照](environment.json)：Apple M4 Pro、14 个逻辑 CPU、48 GiB 内存；快照在测量后读取，未采集测量期间热状态或外部并行负载。

## 来源与正确性

- [提供者来源](provider-manifest.json)：artifact、签名前后实际二进制 hash、唯一服务菜单／端口变更及最低系统 11.0；不冒充正式分发签名。
- [注册节选](registration-excerpts.txt) 与[定向采样](provider-identity.sample.txt)共同验证请求确实进入该副本的 TextConversionService／ChineseConversionService。采样期间另跑的[诊断请求](identity-diagnostic.jsonl)不纳入下面统计。
- [官方 CLI 构建](cli-build-provenance.json)：隔离 core `025f371d`、锁定 CMake 4.4.3，版本 1.4.2；没有复用旧演练的 1.4.1 CLI。
- [56 组固定语料清单](corpus-manifest.json)：两种段落形态 × 四个字节尺寸 × 七配置。资源逐项校验，期望由同版本 CLI 生成；本轮服务调用只完成其中 s2t 的八组，其他配置未伪称实测。
- [生成器负向验证](generator-negative-checks.json)：拒绝覆盖现有目录和使用旧版本 CLI。正文不入日志，可按生成器及 manifest 重建。

## 测量结果

计时仅覆盖 NSPerformService 同步调用，不含调用后的读取／编码／hash／完整字节比较，也不代表应用显示完成、FPS、或目标 App 恢复可编辑。下面 40 次调用均成功且输出逐字节正确；不剔除慢样本，不计算升级收益百分比。

| 段落 | 输入字节 | 调用中位数 ms | 最小–最大 ms |
| --- | ---: | ---: | ---: |
| short-paragraphs | 1024 | 106.175 | 105.086–152.955 |
| short-paragraphs | 1048576 | 105.490 | 101.563–150.663 |
| short-paragraphs | 5242880 | 211.002 | 208.438–259.015 |
| short-paragraphs | 10485760 | 419.349 | 418.234–444.881 |
| long-paragraphs | 1024 | 106.237 | 101.340–153.284 |
| long-paragraphs | 1048576 | 106.546 | 101.404–142.953 |
| long-paragraphs | 5242880 | 210.299 | 206.029–254.637 |
| long-paragraphs | 10485760 | 419.394 | 417.431–2189.534 |

原始 JSONL 与本文件同目录，`summary.json` 保留未取整统计。长段落 10 MiB 有一次约 2.19 s 的样本，尚不能从一次样本归因引擎、IPC 或系统负载，继续保留作后续诊断对象。

另有[固定 U+0000 边界](nul-service.jsonl)：输入 `\0鼠标\0\0汉字\0 😀 é\r\n`，期望 `\0鼠標\0\0漢字\0 😀 é\r\n`，成功且 27 字节完整匹配。这是一项独立固定契约，本次未用 CLI 重写预期。

## 保留项

- Services 返回正确，但测试应用窗口仍显示默认文稿／空结果，[观察及截图](https://github.com/gewill/OpenCCman/issues/19#issuecomment-5677727309)留 #19；未推定根因、未用 #77 或正式 bundle 复验。
- 尚缺其他六组配置的服务样本、关闭提供者后的启动场景、TextEdit 与第二种真实目标 App、超时／失败原稿保留和实际容量决定。本轮不关闭 #22，不新增容量限制。
- 手动工作流回归在滚动断言失败，独立 Release 构建成功；不能将整个工作流写成成功。脚本假阳性已由 #83 修复，滚动失败另留 [#20](https://github.com/gewill/OpenCCman/issues/20#issuecomment-5677727776)。

[清理记录](cleanup.json)：提供者进程退出，专用 Applications 副本移回隔离工作区，服务注册已移除、测试偏好恢复为不存在、VoiceOver 始终关闭。没有终止或激活原有 #19 基线应用，没有修改系统主题。

## 后续补测

[六配置补测与进程退出后启动](configuration-series/README.md)已新增 240 次成功调用；加上本页 40 次，七配置矩阵的 280 次完整字节校验全部通过。上文“尚缺其他六组配置”描述首组测量时点，现由后续记录补齐。真实目标 App、完整启动／已关窗场景、失败和容量决定仍开放。

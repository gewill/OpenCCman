# 服务矩阵

21 个完整文件案例，原始报告见同目录 JSON。`metadata.json` 的 `matrix_plan` 是实际执行清单；保留的 `sizes_mib` / `corpora` / `configurations` 是初始均匀矩阵参数，不能把它们相乘当成实际覆盖。

七个已完成的 1 GiB 单行样本来自相同源哈希／二进制的初始队列，停止的是父调度器，没有中断正在转换的子进程。后续按风险覆盖运行其余案例。每个组合只有一个样本，不是统计性能比较。

可用仓库脚本分组重跑，输出目录均需不存在：

```sh
python3 scripts/benchmark-streaming-files.py --opencc-path <pinned-wrapper> --output <seven-configurations> --sizes-mib 1024 --corpora single multiline --samples 1 --configurations s2t t2s s2tw s2hk s2twp s2t-tw-idiom s2hk-tw-idiom --timeout 900
python3 scripts/benchmark-streaming-files.py --opencc-path <pinned-wrapper> --output <capacity-stairs> --experimental --sizes-mib 2048 4096 8192 --corpora single multiline --samples 1 --configurations s2t --timeout 900
python3 scripts/benchmark-streaming-files.py --opencc-path <pinned-wrapper> --output <mixed-eight> --experimental --sizes-mib 8192 --corpora single --samples 1 --configurations s2hk-tw-idiom --timeout 900
```

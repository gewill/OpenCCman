# 截图与交互录像

原始上传及验收边界：[Issue #268 证据](https://github.com/gewill/OpenCCman/issues/268#issuecomment-5928175031)。

## #268 开发候选 UI 与验证证据

源码 `0bd20fff08b29b1226005440cafa5fe720b053f6`，对比基线 `fbd03f79b18a1d8b35c248914e8490cc2d931da5`。
本轮已实现 >100 MiB、≤1 GiB 的逐任务二次确认、统一容量策略、处理中空间检查、完成记录兼容与三语帮助。
**两个生产开关均保持关闭；#260 未完成的 100 MiB 验收和本 Issue 的真机压力矩阵仍需独立完成。无真实 iPad，不计通过。**

实际 QA App，iOS/iPadOS 18.6 (22G86)，浅色、默认字号、竖屏；Pro/本地文件为 Debug QA 注入。
不是系统提供方、签名包、购买或设备内存验收。下列同条件对照均使用相同文件/语言/设备尺寸。

### iPhone 16 Pro：英语、1 GiB，402×874 pt（1206×2622 px）

| 修改前：100 MiB 上限拒绝 | 修改后：每个文件需明确确认 |
| --- | --- |
| ![phone-before](https://github.com/user-attachments/assets/2776a7e6-2478-4eb2-a965-62ac39425ac0) | ![phone-after](https://github.com/user-attachments/assets/ee5c4035-e843-4197-aae9-1916d6a43315) |

### iPad Pro 13-inch (M4)：简体、256 MiB，1032×1376 pt（2064×2752 px）

| 修改前：100 MiB 上限拒绝 | 修改后：实验性转换二次确认 |
| --- | --- |
| ![pad-before](https://github.com/user-attachments/assets/1a2fda54-cbf8-4527-b2c0-3c578f31b94c) | ![pad-after](https://github.com/user-attachments/assets/86cdc50c-45c4-4c44-9bfb-091ec822feda) |

### 三语与完成状态补充

| 繁体 iPhone / 512 MiB | 英语 iPhone / 1 GiB 完成待保存 |
| --- | --- |
| ![phone-hant](https://github.com/user-attachments/assets/a9d9fad3-f33b-43a7-b7a1-1cf39d141149) | ![phone-ready](https://github.com/user-attachments/assets/febaaf50-9483-4d11-b7bd-6dc142452c61) |

### 实际交互录像

保持原始速度，包含取消、重新启动、再次确认和等待转换；完整输出已在宿主机对照独立整篇 oracle，三个容量均长度/SHA-256 一致。
录像总时长不是单次转换耗时，未测整 App physical footprint/存储峰值/热状态，不据此外推真机速度或稳定性。

iPhone 修改前：

https://github.com/user-attachments/assets/c3917118-2790-49ca-96cc-4e4866e64993

iPhone 修改后：

https://github.com/user-attachments/assets/b82875f0-c397-4a24-9244-e3e58e9c810a

iPad 修改前：

https://github.com/user-attachments/assets/3ab57802-3faf-4d82-9251-03afcf78c4f5

iPad 修改后：

https://github.com/user-attachments/assets/3504d2a7-a571-43c1-bb10-5fccf3750bd4

iPhone 繁体：

https://github.com/user-attachments/assets/82135eab-5b61-47ac-9303-7afe2dbec5d7

验证：macOS universal / iOS Simulator 完整构建通过；核心回归通过；native 移动任务 2 case、iOS Release 3 case、5 个新进程 SIGKILL 恢复通过；实验开关关闭时仍拒绝 100 MiB+1。

尚待：#260、低内存 iPhone / 真实 iPad 签名候选、全部七配置容量/语料矩阵、真实提供方/空间不足/锁屏后台/导出、VoiceOver 与最低系统。Issue 保持开放。


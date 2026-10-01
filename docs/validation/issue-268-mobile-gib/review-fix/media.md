# 评审修复三语截图

来源：https://github.com/gewill/OpenCCman/pull/271#issuecomment-5929460624

已按本条评审修复全部三项，源码提交 `044480cfaf356363af642d06a4ddf80d68187209`。

| 评审项 | 修复与验证 |
| --- | --- |
| 空间容量缓存 | 默认查询前清除 URL resource cache。新增不替换查询结果的回归：同一 worker 的目录删除/重建，旧实现明确失败，新实现通过；同一个 service 实例真实写入 256 MiB 后，导出及下一任务预检的容量均下降约 256 MiB。 |
| 非 Pro 实验容量提示 | >100 MiB 使用独立三语文案，明确最大 1 GiB、实验性、逐次确认和可能失败；10–100 MiB 保留原文案。 |
| journal 格式 | 仅接受写入端产生的 schema 1/无 capacity 和 schema 2/experimental；schema 2/standard、schema 1/experimental 均拒绝，并保留未验证输出。 |

本地：native Release 2 tests、iOS Release 3 tests、5 个 SIGKILL 新进程恢复、核心回归、双端完整构建、项目/语言/控件检查均通过。最终 UI：三语实验提示 + 英语标准容量提示共 4 tests 通过（没有跳过）。实际空间探针只观察并转发生产查询，不注入容量值；不是物理磁盘耗尽或真机内存验收。

截图：iPhone 16 Pro Simulator，iOS 18.6 (22G86)，402×874 pt / 1206×2622 px，浅色、默认字号。两侧同为非 Pro（QA argument-domain override）、实验开关开启、100 MiB+1 输入，经 HomeViewModel 导入路径；未购买、未读取全文。修改前 `802e9eea55c9c420c9e005d77446e6844b944447`，修改后 `044480cfaf356363af642d06a4ddf80d68187209`。文案变化不改按钮交互；原二次确认交互录像仍在 PR 主文。

| 语言 | 修改前：错误显示 100 MiB 上限 | 修改后：实验容量提示 |
| --- | --- | --- |
| en | ![en before](https://github.com/user-attachments/assets/ca5b942f-ca6f-4cbf-9240-00eaf108370c) | ![en after](https://github.com/user-attachments/assets/536d7d5a-4ffe-4f5f-8529-5c3b6a5cf1a3) |
| zh-Hans | ![zh-Hans before](https://github.com/user-attachments/assets/3d2637b7-9646-46fa-866b-52e5e0150d6a) | ![zh-Hans after](https://github.com/user-attachments/assets/4d096e6c-062a-43e4-a1c9-3aef698e9687) |
| zh-Hant | ![zh-Hant before](https://github.com/user-attachments/assets/3e07c008-54b2-44ab-8791-9c8b02832196) | ![zh-Hant after](https://github.com/user-attachments/assets/c59c2952-c025-4651-840b-5565cc01e5c4) |

`productionEnabled` / `experimentalCapacityEnabled` 仍为 false。#260、#268 真实设备、提供方、内存/存储及无障碍验收继续跟踪，本次修复不将其计为通过。待本轮最终 HEAD 检查完成后再合并，不触发 Xcode Cloud。

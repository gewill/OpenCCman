## 最终源码运行验收（2026-09-14）

源提交 `5d527bd3978d73be5f028804d579c86da0f66752`，普通 Debug 应用，隔离 bundle `org.gewill.OpenCCman.Validation65`。下列截图是**同一版本的运行状态对照**，没有新增 UI 修改；#67 的修复前后证据继续保留。全部为英文、浅色、默认字号，中文/Emoji/组合字符/CRLF 合成语料。视频只说明交互，不用于性能计时。

| iPhone 15 Pro Max · iOS 18.6 · 430×932pt | 同设备 · 软件键盘与编辑 |
|---|---|
| ![10 MiB 转换](https://github.com/user-attachments/assets/2d2439de-16a5-48e7-a35f-6bd692d709fc) | ![1 MiB 编辑与键盘](https://github.com/user-attachments/assets/7648510a-2423-4629-a959-9aa1a24f4980) |

1 MiB 内部滚动、设置打开/关闭、编辑保留及键盘避让完成；1 MiB 和 10 MiB 复制结果均与预期逐字节一致。英文输入的首字母自动大写属于系统行为。

[1 MiB 滚动与设置交互录像](https://github.com/user-attachments/assets/1e2df1c1-ab30-4f01-bdad-b11fb3102720)

| iPad Air 11-inch (M2) · iOS 18.6 · 820×1180pt · 左右 | 同设备／同一 1 MiB 文稿 · 上下 |
|---|---|
| ![左右，段落 00010](https://github.com/user-attachments/assets/884830a5-2e2d-48cf-b6ce-eb457688de47) | ![上下，段落 00010](https://github.com/user-attachments/assets/784920f6-40f2-469a-bfa5-fde0bb7e2689) |

等惯性滚动停止后，两轴切换保留段落 00010；编辑标记经布局切换保留，结果区输入尝试未改写结果。1 MiB、10 MiB 转换复制逐字节校验通过。10 MiB 输入、输出均为 10,485,760 字节。这里的边界验收通过粘贴输入，不代替系统文件选择器验收。

[1 MiB 滚动、布局切换与复制录像](https://github.com/user-attachments/assets/2ee7723b-8424-41f2-b34e-5ab1acbf7d86)

| Mac · macOS 26.6.2 · 900×450pt 窗口 · 左右 | 同窗口／100 段文稿 · 上下 |
|---|---|
| ![Mac 左右](https://github.com/user-attachments/assets/35ce52a8-67fa-47b0-abc5-0f02a32717f8) | ![Mac 上下](https://github.com/user-attachments/assets/ec1a4c33-a29b-4597-aeca-951206513a82) |

Cmd-T 转换、Cmd-Option-1/2 切换成功，段落 050 的英文编辑内容保留。真实中文输入法组合阶段未获可靠工具证据，不能用英文 `ni` 或原生 marked-text 单测替代。

另已完成协议 2 Release 诊断包的 **5 次转换套件＋3 次重排套件**及原生编辑器回归、26 项测量协议测试；完整来源、原始样本与解释见 [本目录报告](README.md)。没有用录屏/AX 同时采集性能样本，也没有改写历史 metadata。

VoiceOver 已通过系统设置确认关闭，进程退出；两台模拟器剪贴板恢复并关机。完整 VoiceOver、完整纯键盘/真实中文输入法、iOS 14/macOS 11 和签名发布验收仍未完成，#65 保持开放。

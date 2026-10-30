# 剩余验收盘点（2026-10-30）

实时读取到 **46 个 OPEN Issues**。这是对标题、已有记录及本轮选定缺口的排程盘点，不代表对全部 Issue 做完新的源码专项审计，也不改变任何关闭标准。#270 已 squash 合入 develop `54786a26abeb7404ed09aa3207b79b09c80397ab`，合并后 CI 通过；没有因此关闭 Issue。

## Duo 适配及条件素材（6 项）

当前先修复启动环境；姿态/方向/三语/默认与 XXXL、系统溢出等剩余标准保留。

- [#277 [iPhone Duo][跟踪] 适配审查、独立交付与最终候选验收](https://github.com/gewill/OpenCCman/issues/277)
- [#279 [iPhone Duo][B] 将 iPhone 工作区改为容器驱动布局并保持编辑器身份](https://github.com/gewill/OpenCCman/issues/279)
- [#280 [iPhone Duo][C] 适配系统导航栏、竖向工具栏及不对称安全区域](https://github.com/gewill/OpenCCman/issues/280)
- [#281 [iPhone Duo][D] 验证并适配折叠区关键操作与 Pro 自定义提示](https://github.com/gewill/OpenCCman/issues/281)
- [#282 [iPhone Duo][E] 验收最终候选的姿态切换、键盘弹层与任务连续性](https://github.com/gewill/OpenCCman/issues/282)
- [#283 [iPhone Duo][F][条件项] 准备三语内外屏商店截图候选与规格验证](https://github.com/gewill/OpenCCman/issues/283)

## 文件工作流、容量与中断恢复（8 项）

#264/#270 已合并只补工具和历史证据；完整签名设备/资源/故障与扩容门控分别验收。

- [#217 [后续][Mac] 大文件转换的异常中断恢复（强制终止、断电、外接卷、文件提供方）](https://github.com/gewill/OpenCCman/issues/217)
- [#256 [2.2][Pro][跟踪] iPhone/iPad 100 MiB 大文件直接转换与保存](https://github.com/gewill/OpenCCman/issues/256)
- [#257 [2.2][大文件][A] 提取跨平台流式转换核心与容量策略](https://github.com/gewill/OpenCCman/issues/257)
- [#258 [2.2][大文件][B] 实现移动端文件快照、作业恢复与安全清理](https://github.com/gewill/OpenCCman/issues/258)
- [#259 [2.2][大文件][C] 接入iPhone/iPad前台进度与系统文件保存](https://github.com/gewill/OpenCCman/issues/259)
- [#260 [2.2][大文件][D] 完成100 MiB真机容量与资源验收并开放功能](https://github.com/gewill/OpenCCman/issues/260)
- [#268 [后续][iOS/iPadOS] 100 MiB 验收后独立推进 1 GiB 大文件与二次确认](https://github.com/gewill/OpenCCman/issues/268)
- [#269 [后续][Mac] 独立评估并提高超过 1 GiB 的文件容量上限](https://github.com/gewill/OpenCCman/issues/269)

## 共享界面与运行时体验（17 项）

本轮新增 Mac 窄窗菜单/稿件保持；跨 App 快捷键仍缺 QA 辅助功能权限。其他项不能据标题或本次局部验证关闭。

- [#18 [2.1][P1][R7] 建立最终应用冷启动、热转换与内存基线](https://github.com/gewill/OpenCCman/issues/18)
- [#19 [2.1][P1][R8] 验证并修复全部关窗后的系统入口](https://github.com/gewill/OpenCCman/issues/19)
- [#20 [2.1][P1][R9] 完成 VoiceOver、键盘和编辑器运行时验收](https://github.com/gewill/OpenCCman/issues/20)
- [#22 [后续][P2][R10] 测量 NSServices 大文本等待与容量边界](https://github.com/gewill/OpenCCman/issues/22)
- [#34 [2.0] What’s New：完成设备与弹窗延后 UI 验收](https://github.com/gewill/OpenCCman/issues/34)
- [#37 [2.0] Neumorphic 正式版控件 UI 验收](https://github.com/gewill/OpenCCman/issues/37)
- [#45 [UI][跟踪] 第2稿：iPhone／iPad／Mac 自适应转换工作区](https://github.com/gewill/OpenCCman/issues/45)
- [#48 [UI][C] 实现Mac设置侧栏、左右/上下分栏与键盘操作](https://github.com/gewill/OpenCCman/issues/48)
- [#49 [UI][D] 实现iPad双布局、窄窗口与软硬键盘适配](https://github.com/gewill/OpenCCman/issues/49)
- [#50 [UI][E] 实现iPhone上下阅读、转换设置面板与键盘避让](https://github.com/gewill/OpenCCman/issues/50)
- [#57 [UI][Mac] 明确并设置推荐窗口尺寸与最小尺寸](https://github.com/gewill/OpenCCman/issues/57)
- [#65 [性能][Mac] 修复大文稿滚动与布局切换的 TextKit 重排长等待](https://github.com/gewill/OpenCCman/issues/65)
- [#191 [UI][Mac] 明确并实现应用内大字号路径](https://github.com/gewill/OpenCCman/issues/191)
- [#220 [UI] 冷启动开屏转场：启动标记展开为工作区](https://github.com/gewill/OpenCCman/issues/220)
- [#245 [2.1][体验] 新工作区原文默认留空，示例改为主动填入](https://github.com/gewill/OpenCCman/issues/245)
- [#251 [UI] App 图标改用 Icon Composer 分层格式并适配 Liquid Glass](https://github.com/gewill/OpenCCman/issues/251)
- [#274 [macOS] 完善菜单栏图标开关与默认偏好](https://github.com/gewill/OpenCCman/issues/274)

## 签名、系统兼容、购买与发布门槛（8 项）

下一轮先核对实际候选/安装/账户及环境；本轮未执行，不预判当前可用性或替代真实门槛。

- [#11 [跟踪] v2.0 发布与 v2.1 延期验收清单](https://github.com/gewill/OpenCCman/issues/11)
- [#14 [2.1][P0][R1] 完成 Sandbox/TestFlight 购买异常路径与 Pro 资格验收](https://github.com/gewill/OpenCCman/issues/14)
- [#15 [2.1][P0][R2] 完成云端签名包 TXT、权限和跨 App 转换矩阵](https://github.com/gewill/OpenCCman/issues/15)
- [#16 [2.1][P0][R3] 验证 iOS 15／macOS 12 及最终产物核心路径](https://github.com/gewill/OpenCCman/issues/16)
- [#71 [功能] 接入 RevenueCatUI 用户中心及旧系统兼容入口](https://github.com/gewill/OpenCCman/issues/71)
- [#212 [2.1][P0] 调查英国区 TestFlight 商品页与系统购买面板币种不一致](https://github.com/gewill/OpenCCman/issues/212)
- [#218 [StoreKit] Xcode 27／macOS 27 本机两项 StoreKit 回归失败：退款约 15 秒才撤销，模拟购买错误变为 unknown](https://github.com/gewill/OpenCCman/issues/218)
- [#239 [2.1][P0] 本机安装的 Mac TestFlight 2.1(58) 缺少 profile，冷启动报错](https://github.com/gewill/OpenCCman/issues/239)

## 后续功能（7 项）

属于独立功能开发，不作为本轮本机验收扩展。

- [#25 [2.2][功能] 批量 TXT 文件转换](https://github.com/gewill/OpenCCman/issues/25)
- [#26 [2.1][功能] Shortcuts 文本转换动作](https://github.com/gewill/OpenCCman/issues/26)
- [#27 [2.2][功能] 转换前后差异查看](https://github.com/gewill/OpenCCman/issues/27)
- [#28 [后续功能] 默认关闭的本地转换历史](https://github.com/gewill/OpenCCman/issues/28)
- [#29 [2.2][功能] 系统分享菜单中的文字转换扩展](https://github.com/gewill/OpenCCman/issues/29)
- [#30 [后续功能] 图片 OCR 提取文字后转换](https://github.com/gewill/OpenCCman/issues/30)
- [#31 [后续功能] 评估自定义词典与术语保护接口](https://github.com/gewill/OpenCCman/issues/31)

## 本轮新增与边界

详见 [Mac 窄窗菜单与保持验证](iphone-duo/mac-menu-followup-2026-10-30.md)。Duo boot/runtime 环境不一致及 QA 快捷键权限缺口已保留；Mac 100%/150%的一组菜单操作有原生 AX、完整文本和单窗口视频。无产品缺陷被本轮复现，未改代码、部署、分发或关闭 Issue。

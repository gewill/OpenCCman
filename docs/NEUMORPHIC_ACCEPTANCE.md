# Neumorphic UI 验收记录

日期：2026-09-13。PR：[#39](https://github.com/gewill/OpenCCman/pull/39)。测试源码：`26971f1783e9fedac408a7590e09c58628e9c859`。

## 结论

**整体 UI 验收未通过，PR 保留草稿。** 普通字号核心交互通过；iPhone 辅助功能大字号下推荐卡片遮挡内容、页头重叠，修复与复验由 [#40](https://github.com/gewill/OpenCCman/issues/40) 跟踪。没有合并、触发 Xcode Cloud 或更新 TestFlight。

## 环境与证据范围

- Xcode 26.6 / macOS 26.6.2 arm64；使用已构建的最终 Debug 产物，复制并以隔离 bundle ID `org.gewill.OpenCCman.NeumorphicQA20260913` 重新进行 ad hoc 签名。没有操作正式版偏好或执行购买。
- macOS QA 路径 `/tmp/OpenCCmanNeumorphicQA.app`；iPhone 17 Pro / iOS 26.5 模拟器安装同一源码的 iOS Debug 产物。
- 操作与核验依据实际界面截图和辅助功能树。AX 标签、选中/禁用状态检查不等于 VoiceOver 朗读验收。
- macOS/iOS Simulator 构建及现有回归此前通过；测试源码的 [App Regression](https://github.com/gewill/OpenCCman/actions/runs/34746935117) 成功。本轮未修改应用代码，未重复执行同一套构建。

## 已通过

| 范围 | 实际操作和结果 |
| --- | --- |
| macOS 分段选择 | 选择台湾标准后预设显示“自定义”；再选台湾模式后显示“台湾正体＋台湾词组”。香港标准＋不转换被识别为香港预设；OpenCC 标准＋不转换被识别为 OpenCC 预设 |
| 简体禁用 | 切换简体后异体字及地域用词的全部选项禁用，原选中值保留；切回繁体后恢复可操作和原台湾预设 |
| 实际转换 | 台湾词组配置将 `鼠标里面的硅二极管坏了，导致光标分辨率降低。` 转为 `滑鼠裡面的矽二極體壞了，導致游標解析度降低。`；成功后结果可见，复制与导出按钮启用 |
| 预设菜单 | 原生菜单仍显示当前项勾选；菜单操作后能更新为 OpenCC、台湾配置。自动化工具读取菜单关闭后的第一帧有延迟，结果以随后稳定界面为准 |
| 两个开关 | 菜单栏图标 off → on → off；快捷键 on → off → on，AX 状态随操作变化。快捷键页明确提示隔离应用缺少辅助功能权限；未点击授权或跨 App 测试 |
| 语言切换 | 英文、简体、繁体标签可见；应用内切换到简体、繁体后选择器与页面实时更新。保留既有文案，如简体界面中的“繁體中文”原生字形标签 |
| macOS 布局 | 英文普通字号浅色界面、简繁深色界面已观察。400 点宽中文选择器无截断；300 点最小宽度繁体选项换行显示，三组未出现横向滚动。300 点时推荐卡片关闭按钮出界另列失败项 |
| 偏好持久化 | 退出并重新启动 QA 应用，香港标准＋不转换、香港预设、繁体显示语言和深色主题保留 |
| iPhone 普通字号 | 英文浅色界面中三组显示完整，较长的异体字选项正常换行。触控台湾标准使预设变为 Custom；再触控 Taiwan Idiom 使预设变为 Taiwan · Standard + Idioms |
| 新功能弹窗冒烟 | macOS 启动出现 What’s New，Done 能关闭并返回主页；不代替 #34 的完整设备/弹窗调度验收 |

## 失败与修改建议

### 辅助功能大字号遮挡

iPhone 17 Pro 中通过 Simulator → Features → Increase Preferred Text Size 连续增大字号，推荐卡片高度膨胀，名称/说明逐字换行，遮住主要内容；页头标题、副标题及两侧图标重叠。测试后已降低回普通字号。不能据此认定被遮挡的分段控件在最大字号下通过。

代码核对：`MyAppView` 固定宽度 300，使用横向布局和动态字体；`HomeScene` 将其作为不占正文空间的底部覆盖层。页头也使用重叠布局。这些布局在 PR 基线中已存在，但没有运行旧版进行视觉 A/B；不将现象全部归因于依赖升级。

建议在辅助功能字号下采用纵向卡片与独立标题行，让推荐内容参与可滚动布局或为正文预留真实空间；使用可用宽度并将关闭按钮放在边界内。保持 iOS 14 / macOS 11，可使用 `sizeCategory.isAccessibilityCategory` 分支，不以统一限制字号代替可访问布局。详细验收条件见 [#40](https://github.com/gewill/OpenCCman/issues/40)。

## 尚未完成

- iPad：安装成功，模拟器窗口能旋转，但 UI 工具未能点击启动应用，且辅助功能树没有设备内容；不记为应用故障或通过，需恢复模拟器交互后补测。
- 大字号修复后的英语/简繁、浅色/深色、iPhone/iPad 全组合及高对比度。
- 加载圆环运行过程、取消和 Reduce Motion；本轮短文本转换结束较快，未捕获加载动画。
- 完整 VoiceOver 朗读、焦点次序和纯键盘遍历；iPhone 工具只暴露选择器容器，尚不能确认实际 VoiceOver 如何访问内部选项。沿用 [#20](https://github.com/gewill/OpenCCman/issues/20)。
- 辅助功能授权后的跨 App 快捷键、签名分发包文件访问，沿用 [#15](https://github.com/gewill/OpenCCman/issues/15)。本轮仅验证了两个开关的 UI 状态。
- iOS 14 / macOS 11 真机与最终分发产物验收，沿用 [#16](https://github.com/gewill/OpenCCman/issues/16)。模拟器及当前系统 Debug 运行不能替代这些项目。

总清单：[控件 UI 验收 #37](https://github.com/gewill/OpenCCman/issues/37)。控件接入取舍见 [Neumorphic 控件清单](NEUMORPHIC_CONTROLS.md)。

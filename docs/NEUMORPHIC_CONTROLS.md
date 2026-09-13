# Neumorphic 正式版与控件接入清单

核对日期：2026-09-13。范围为 OpenCCman 应用运行时页面；没有为覆盖组件目录而新增产品功能。

## 依赖版本

- 使用 [gewill/neumorphic v2.4.1 正式版](https://github.com/gewill/neumorphic/releases/tag/v2.4.1)，取代 `master` 分支依赖。
- 工程使用 `exactVersion = 2.4.1`；锁文件记录该 tag 对应的 commit `1f5745173dedddf0227fffc47cbdaa3100e5569a`。此前分支锁定为 `e64d6240415537c0b9a1f289e46b92b592dc94db`。
- 该版本支持 iOS 13 / macOS 10.15，Menu/Link 需要 iOS 14 / macOS 11；应用部署下限继续为 iOS 14 / macOS 11。没有引入新的平台要求。
- 正式版接入时其余 14 个依赖保持原锁定值。后续 #38 仅删除 VisualEffects，锁文件从 15 项变为 14 项；剩余各项与清理前逐字段一致，包括 OpenCC 1.4.2 对应的 SwiftyOpenCC revision。

## 本次接入

| 位置 | 控件或样式 | 处理 |
| --- | --- | --- |
| 主页：目标语言、异体字、地域用词 | `SegmentView`，参考 iPerfman `OptionsPicker` | 一体式内凹圆角底座、细分隔线、蓝底白字选中项；标题上置，移除横向滚动；辅助功能字号改用纵向排列 |
| 设置：菜单栏图标开关 | `neumorphicThemedSwitchStyle` | 原 `SwitchToggleStyle()` 为 SwiftUI 系统开关；现在明确调用库样式，并补齐辅助功能标签 |
| 快捷键设置：启用开关 | `neumorphicThemedSwitchStyle` | 同上，绑定仍连接现有快捷键服务 |
| 主页导入与转换、Pro 加载 | `NeumorphicCircularProgressView` | 共用 `LoadingView` 包装，取代原系统 spinner 和自绘三圆动画；没有可测连续进度时传 `nil`，不虚构百分比 |
| 主页三个容器、设置/开源信息/选择列表容器 | `neumorphicCard` | 复用正式卡片 API；既有 `softRectangleStyle` 保留调用接口和 padding 行为，内部转用库卡片 |
| 常用预设菜单触发器 | `neumorphicThemedButtonStyle` + SwiftUI `Menu` | 触发器使用库样式；菜单继续保留当前项勾选和“自定义”状态 |
| 导入与取消导入按钮 | `softButtonStyle` | 补齐与其余文件操作一致的按钮样式 |

按照产品指定的 iPerfman 样式，选择器采用应用内 `SegmentView`，参考 [OptionsPicker](https://github.com/gewill/iperfman/blob/0360d9c74da45e9b815ddb3b4ff3c42b56bcec68/iperfman/components/OptionsPicker.swift)、`OptionsPickerIcon` 与 groove divider。共用 11 点圆角内凹底座、3 点内边距、8 点圆角选中块；保留 OpenCCman 蓝色，不引入 iPerfman 的橙色主题。库的 `NeumorphicPicker` 提供独立胶囊外观，不符合这次指定样式，因此改用库阴影 API 组合。转换模型与偏好键不变，简体仍禁用两组高级选项。

选项使用真实 `Button`，显式保留选中 trait 和整个按钮矩形命中区域；可点击高度至少 44 点。普通字号等宽横排，文字可换行而不截断；辅助功能字号纵排，状态仍由原 Binding 持有。通过 `sizeCategory` 保持 iOS 14 / macOS 11 兼容，不照搬参考控件的固定行高与单行缩字。

`String.localized(in:bundle:)` 根据当前应用语言解析标签，处理 `zh_Hans`/`zh_Hant` 与 lproj 命名差异；现有标签文案保留。

## 其余控件是否都用了库

**没有全部替换，也不需要为了用全库而改变控件语义。** 下面逐类列出当前选择：

| 控件类型与位置 | 当前实现 | 结论与原因 |
| --- | --- | --- |
| 主要操作按钮、返回/设置、复制/导出、购买/恢复、快捷键测试 | `softButtonStyle` / `fixedSizeSoftButtonStyle` | 已使用 Neumorphic 按钮样式，沿用原行为 |
| 设置导航行、帮助图标、反馈复制按钮 | SwiftUI `Button`，部分为 `.plain` | 行导航和轻量图标动作保留系统语义；不是所有按钮都使用凸起外观 |
| 语言和外观单选列表 | `PickableView` / `PickableSingleChoiceView`，外层库卡片 | 保留带勾选的竖向列表，适合不同长度的语言名称；未接 `NeumorphicRadio`。以后可评估 Radio，但不在本次改变选择逻辑 |
| 常用预设选择 | SwiftUI `Menu` + 库按钮样式 | 未换成 `NeumorphicMenu`；正式版 Menu 的选项正文只有文本，直接替换会丢掉当前菜单中的勾选提示 |
| 输入和结果正文 | SwiftUI `TextEditor`，macOS TextKit 配置 | 保留多行编辑、文本选择和只读结果能力；库的 `NeumorphicTextField` 是单行输入，不适合替换 |
| 帮助、反馈及正文中的链接 | SwiftUI `Link` / Markdown 链接 | 保留行内链接和现有布局；未接凸起的 `NeumorphicLink` |
| 新功能卡片与关闭按钮 | 原生 SwiftUI sheet、系统字体/配色 | 沿用 What’s New 的既定可访问性与系统弹窗设计；没有替换为 Neumorphic 装饰卡片 |
| Pro 展示卡片 | `CardReflectionView` / ColorfulX | 属于产品展示动画，保留既有设计；不混同于表单卡片容器 |
| 快捷键录制器 | KeyboardShortcuts 的 recorder | 保留其按键录制与清除语义，库没有等价控件 |
| 文件选择/保存、错误提示、系统评价与权限提示 | 系统文件 API、SwiftUI/AppKit/StoreKit | 保留平台行为；不使用仿制弹窗替代 |
| 菜单栏、菜单命令和 macOS Services | AppKit / SwiftUI Commands | 保留系统菜单与跨 App 集成 |
| Slider、Stepper、DatePicker、Checkbox、DisclosureGroup | 应用无对应操作 | 未使用，不为接库新增无关输入项 |
| 线性 Progress | 未使用 | 转换引擎不提供可测连续进度，当前圆形不定进度更符合实际状态 |

## 闲置样式与依赖清理

清理任务：[未使用样式与 VisualEffects #38](https://github.com/gewill/OpenCCman/issues/38)。详见 [清理验证与前后截图](UNUSED_CONTROLS_CLEANUP.md)。

- 已移除无运行时调用的 `SmallButtonStyle` / `smallButtonStyle`、`MacButtonStyle`，以及只用于自身预览的 `smallSizeSoftButtonStyle`；删除专用 `ButtonStyles.swift` 和工程中的源文件引用。现用的 `softRectangleStyle` 和 `modify` 保留。
- 分段选择器移除模糊背景后，VisualEffects 已无源码调用或其他包的依赖入口；已删除 package/product/framework、锁文件 pin 及应用内开源声明，其他依赖不变。历史截图/验收文档中的旧版记录保留。
- 高对比主题、VoiceOver、键盘与最大字号需要整体页面验收；仅使用库不能证明整页对比度或焦点顺序已合格。沿用 [#20](https://github.com/gewill/OpenCCman/issues/20) 和 [#16](https://github.com/gewill/OpenCCman/issues/16) 的设备验收范围。

## 验证

- Xcode 26.6：macOS 与 iOS Simulator Debug 构建成功，仍以应用原部署下限编译。
- `scripts/check-control-labels.sh` 使用真实字符串资源和生产语言解析函数，验证英文、简繁、下划线 locale、切换语言和缺失键回退；已加入 App Regression CI。
- 工程/字符串语法、What’s New 状态、核心/预设/文件、额度及剪贴板回归由现有脚本覆盖。
- 2026-09-13 已执行隔离应用 UI 验收：普通字号核心交互通过，辅助功能大字号发现遮挡和重叠。**整体 UI 验收未通过，PR #39 保留草稿。** 逐项证据见 [本轮验收记录](NEUMORPHIC_ACCEPTANCE.md)，跟踪于 [#37](https://github.com/gewill/OpenCCman/issues/37)；布局修复见 [#40](https://github.com/gewill/OpenCCman/issues/40)。

相关 API 以 [v2.4.1 源码](https://github.com/gewill/neumorphic/tree/v2.4.1/Sources/Neumorphic) 为准。

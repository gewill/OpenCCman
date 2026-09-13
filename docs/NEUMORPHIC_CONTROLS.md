# Neumorphic 正式版与控件接入清单

核对日期：2026-09-13。范围为 OpenCCman 应用运行时页面；没有为覆盖组件目录而新增产品功能。

## 依赖版本

- 使用 [gewill/neumorphic v2.4.1 正式版](https://github.com/gewill/neumorphic/releases/tag/v2.4.1)，取代 `master` 分支依赖。
- 工程使用 `exactVersion = 2.4.1`；锁文件记录该 tag 对应的 commit `1f5745173dedddf0227fffc47cbdaa3100e5569a`。此前分支锁定为 `e64d6240415537c0b9a1f289e46b92b592dc94db`。
- 该版本支持 iOS 13 / macOS 10.15，Menu/Link 需要 iOS 14 / macOS 11；应用部署下限继续为 iOS 14 / macOS 11。没有引入新的平台要求。
- 其余 14 个依赖保持原锁定值，包括 OpenCC 1.4.2 对应的 SwiftyOpenCC revision。

## 本次接入

| 位置 | 控件或样式 | 处理 |
| --- | --- | --- |
| 主页：目标语言、异体字、地域用词 | `NeumorphicPicker` | 使用库提供的分段选择器，替换自行拼接的胶囊按钮、阴影和模糊背景；标题置于选项上方，移除横向滚动 |
| 设置：菜单栏图标开关 | `neumorphicThemedSwitchStyle` | 原 `SwitchToggleStyle()` 为 SwiftUI 系统开关；现在明确调用库样式，并补齐辅助功能标签 |
| 快捷键设置：启用开关 | `neumorphicThemedSwitchStyle` | 同上，绑定仍连接现有快捷键服务 |
| 主页导入与转换、Pro 加载 | `NeumorphicCircularProgressView` | 共用 `LoadingView` 包装，取代原系统 spinner 和自绘三圆动画；没有可测连续进度时传 `nil`，不虚构百分比 |
| 主页三个容器、设置/开源信息/选择列表容器 | `neumorphicCard` | 复用正式卡片 API；既有 `softRectangleStyle` 保留调用接口和 padding 行为，内部转用库卡片 |
| 常用预设菜单触发器 | `neumorphicThemedButtonStyle` + SwiftUI `Menu` | 触发器使用库样式；菜单继续保留当前项勾选和“自定义”状态 |
| 导入与取消导入按钮 | `softButtonStyle` | 补齐与其余文件操作一致的按钮样式 |

`NeumorphicPicker` 是库公开 API 中的 segmented picker；本次没有另造一个分段选择器，也没有更换为系统 `PickerStyle.segmented`。转换模型与偏好键保持不变，选择简体时仍禁用异体字/地域用词两组。

该控件的 label 回调接收 `String`。`String.localized(in:bundle:)` 根据 SwiftUI 环境中的当前应用语言查找资源，处理 `zh_Hans`/`zh_Hant` 与 lproj 命名差异；不使用始终跟随系统语言的固定 `NSLocalizedString` 结果。现有标签文案原样保留。

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

## 后续可精简项

清理任务：[未使用样式与 VisualEffects #38](https://github.com/gewill/OpenCCman/issues/38)。

- `smallButtonStyle`、`MacButtonStyle` 没有运行时调用；`smallSizeSoftButtonStyle` 只用于自身预览。可在单独清理中移除，避免维护多套未使用样式。
- 分段选择器移除模糊背景后，应用 Swift 源码已没有 `VisualEffects` 的调用；它仍在 SPM 和开源声明中。本次保持其他依赖锁定，建议单独验证后连同无用引用和声明一起移除。
- 高对比主题、VoiceOver、键盘与最大字号需要整体页面验收；仅使用库不能证明整页对比度或焦点顺序已合格。沿用 [#20](https://github.com/gewill/OpenCCman/issues/20) 和 [#16](https://github.com/gewill/OpenCCman/issues/16) 的设备验收范围。

## 验证

- Xcode 26.6：macOS 与 iOS Simulator Debug 构建成功，仍以应用原部署下限编译。
- `scripts/check-control-labels.sh` 使用真实字符串资源和生产语言解析函数，验证英文、简繁、下划线 locale、切换语言和缺失键回退；已加入 App Regression CI。
- 工程/字符串语法、What’s New 状态、核心/预设/文件、额度及剪贴板回归由现有脚本覆盖。
- 实际界面验收暂未执行：Mac 锁定，无法打开隔离测试版。窄窗口、深色、大字号、选中/禁用状态及两个开关交互不能仅凭构建成功认定通过；解锁后应优先补验，跟踪于 [控件 UI 验收 #37](https://github.com/gewill/OpenCCman/issues/37)。

相关 API 以 [v2.4.1 源码](https://github.com/gewill/neumorphic/tree/v2.4.1/Sources/Neumorphic) 为准。

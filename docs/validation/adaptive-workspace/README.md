# 自适应工作区实施与验收记录

更新：2026-09-13。日常目标为 develop，原工作区未切换或重置。未推送 build*，未发布 Xcode Cloud/TestFlight；10 MiB 上限不变，Pro 大文件另由 #52 跟踪。

## 实现交付

| Issue | 实现 PR | 证据 |
|---|---|---|
| #46 布局偏好 | [#53](https://github.com/gewill/OpenCCman/pull/53) 已合并 | check-workspace：719/720/759/760、暂时回退、侧栏预算、比例异常值、窗口值隔离 |
| #47 共用组件 | [#54](https://github.com/gewill/OpenCCman/pull/54) 已合并 | [运行前后](47/README.md)、真实 HomeViewModel 核心检查 |
| #40 推荐与页头 | [#55](https://github.com/gewill/OpenCCman/pull/55) 已合并 | [运行前后](40/README.md)、推荐参与滚动，移除推荐仍到 Pro |
| #48 Mac | [#56](https://github.com/gewill/OpenCCman/pull/56) 已合并 | [两轴与窗口记录](48/README.md) |
| #49 iPad | [#58](https://github.com/gewill/OpenCCman/pull/58) 已合并 | [两轴、旋转与键盘](49/README.md) |
| #50 iPhone | [#59](https://github.com/gewill/OpenCCman/pull/59) 已合并 | [320pt、最大字号与键盘](50/README.md) |
| #34 呈现 | [#60](https://github.com/gewill/OpenCCman/pull/60) 已合并 | [设置关闭动画互斥](34/README.md) |
| #37 视觉补验 | 独立分支 codex/workspace-validation | [深色与最大字号前后截图](37/README.md) |
| #20 无障碍 | [#61](https://github.com/gewill/OpenCCman/pull/61) 已合并 | [44pt运行测量与只读结果检查](20/README.md) |

合并不等同于 issue 所有设备验收完成。各截图记录自己的来源 SHA；不能将早期平台截图组合成最终 SHA 全平台通过。

## 当前验证边界

- 共用源码 5bd8783（#34）、72bf310（#20）macOS / iOS Simulator 完整构建通过；命中区修复保持业务源码不变。#37继续修复深色转换按钮及最大字号设置页头，见[最终视觉补验](37/README.md)。
- 实际核心回归：7组配置×8份语料，Unicode/换行/复用；重复点击、取消/替换/释放、单次发布；BOM/NUL/非法编码/容量/文件提供者取消通过。
- 跨窗口额度预约：并发上限、幂等释放、取消/析构、午夜完成、Pro 豁免通过。
- 剪贴板回归：文本/RTF/图片/文件URL多项目保留、所有权/用户后续复制/空剪贴板通过。
- 布局边界、What’s New 呈现状态与三语言控件检查通过。
- Mac #48 运行证据：50次两轴切换保留选中“鼠标”；1200→650→1200回退/恢复；分隔线AX调整50→55%；两窗口不同布局/比例/结果相互独立。重启是否恢复同一 scene 取决于系统窗口恢复设置，不保存稿件或承诺全新窗口继承旧布局。
- iPad #49 实际触控、旋转侧栏、键盘中切换保留原文通过；iPhone #50 软件键盘中仅一个转换按钮、推荐隐藏、收起键盘、320pt与最大字号截图已记录。
- host macOS 26.6.2、Xcode/SDK26.5。旧记录将SDK版本写成host版本，已更正。

## 尚未完成与建议

以下维持开放，不关闭 #45：

| 跟踪 | 尚缺的实际证据 | 下一步 |
|---|---|---|
| #20 | VoiceOver 朗读/顺序/选中/禁用，中文 marked text，长文本滚动锚点，结果只读选择复制，最终SHA键盘流程 | Mac 解锁后接续宿主 UI；软件注入普通文字不能冒充真实输入法组合。iPad adjustable 在AXe中数值为nan但描述50%，需实际播报判断，不按工具格式臆测修复 |
| #37 / #40 | 三语言、浅深色、高对比度、最大字号、Pro/非Pro的完整组合，Reduce Motion/加载/取消 | 用同一最终SHA定向补齐，早期截图只作历史证据 |
| #34 | 未读卡片与真实转换/导入/系统面板、错误/Pro、交互下滑关闭/横屏全屏sheet的UI竞态 | 状态回归已覆盖guard；继续真实UI验收，不能以单元测试代替 |
| #49 / #50 | Stage Manager自由窗口、真实软硬键盘细节，最低系统回退 | 需要相应设备/环境，保留 #16 |
| #15 / #16 / #14 | 签名包文件权限/跨App、iOS14/macOS11与真实购买 | 本轮不发布；后续授权云端构建后使用准确SHA与分发包验收 |

执行中 Mac 锁定，宿主 UI 工具明确拒绝交互；已请求解锁。独立模拟器 API 仍可检查其专用测试实例，未绕过锁屏，也未更改正式应用数据。

## 复验命令

```bash
bash scripts/check-project.sh
bash scripts/check-workspace.sh
bash scripts/check-whats-new.sh
bash scripts/check-control-labels.sh
bash scripts/check-quota.sh
bash scripts/check-pasteboard.sh
python3 scripts/check-core.py --opencc-path <SwiftyOpenCC-checkout> --defaults-path <SwiftyUserDefaults-checkout>
```

构建使用 scheme OpenCCman、Debug、CODE_SIGNING_ALLOWED=NO、锁定的 SourcePackages，分别指定 platform=macOS 与 generic/platform=iOS Simulator。模拟器测试包只在本次创建的专用实例中完整 ad-hoc 签名后安装；不是签名分发包验收。

补充：iPad 长文本补验中，AXe 的 HID 输入只支持US字符，Unicode测试输入被拒绝；后续设备AX树只返回空Application，无法证明注入或布局切换成功。因此没有把该尝试列为长文本、Unicode或输入法通过证据。

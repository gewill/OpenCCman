# #259 移动端大文件工作流验收记录

2026-10-01，应用实现提交 `338dfde9dd3dd030107e5e1ea6205e4ee2508ec6`；依赖 #262 的 `3f3bd8b03b583c45bf1563282eac6cf9f3818ea7`。这是开发候选，**生产入口仍关闭**，不能据此宣传移动端已支持 100 MiB。

## 实现

- App 级唯一运行时与任务协调器；仅系统选择器将 >10 MiB、≤100 MiB TXT 路由到独立 Pro 文件任务。编辑器与拖放仍为 10 MiB，不加载大文件正文、不扣主页次数。QA 权益只在专用 Debug Bundle + 显式参数下生效，不写入购买状态。
- 冻结配置、开始前重查资格和源文件指纹；私有快照、流式转换、完整待保存结果、恢复/清理错误提示以及确认删除。准备与进度更新在后台，取消不阻塞主线程。
- UIKit 生命周期处理、窗口所有权与完整结果接管；系统导出只传 URL，取消保留结果。
- 实际保存测试发现 SwiftUI 关闭回调可能先于文档选择器成功回调；已按每次导出尝试生成 UUID，迟到的旧尝试不能影响新尝试。增加顺序反转和旧回调回归测试。

## 已验证

| 范围 | 实际结果 |
|---|---|
| 双端构建 | Xcode 27.0 (27A266a)，macOS arm64/x86_64、iOS Simulator arm64 Debug 均成功；未签名 |
| 静态/本地回归 | project、language、control labels、core 均通过；服务/协调器 native 测试和五处 SIGKILL 新进程恢复通过 |
| iOS XCTest | iOS 18.6，服务、协调器、UIKit 通知适配共 3 项通过 |
| iPhone 系统选取与保存 | iPhone 15 Pro Simulator，393×852pt，浅色简中；从系统 Files 本地提供方选取 11 MiB → 确认 → 转换 → 取消保存 → 重试 → 系统“保留两者”保存成功；私有任务目录为空 |
| 内容完整性 | 11 MiB 包含中文、Emoji、组合字符、CRLF、U+0000；系统保存结果与锁定 wrapper 的整篇转换逐字节相等，SHA 见 ui-report.json |
| 编辑器保留 | 系统选取至保存前后 AX 读回的原文、结果完全一致；这不证明光标、输入法组合态和滚动位置全矩阵 |
| iPad 后台取消 | iPad Pro 11-inch M4 Simulator，834×1210pt，iOS 18.6；100 MiB 实际任务在 2% 时 Home 退后台，回前台显示 Task stopped，私有任务目录为空 |
| 语言与外观 | iPhone 简中浅色，iPad 英语浅色/繁中深色实际截图；辅助最大字号有初步截图，完整滚动与操作尚未验收 |

截图和视频通过 gh 附件发布到对应 PR，来源 SHA 和文件哈希见 ui-report.json。iPad 输入使用专用 QA 自动选取参数，不能代替 iPad 系统选择器验收。未触碰正式 App 数据、购买账号、已有其他项目模拟器或依赖缓存。

### 测试限制与诊断

- 第一次手工 iOS XCTest 命令遗漏脚本规定的 `ENABLE_TESTABILITY=YES`，导致测试模块编译失败；按脚本参数修正后 3 项通过。没有改产品代码来绕过失败。
- SwiftPM 无界面 xctest 中设置 idleTimer 不能证明真实 App 防锁屏；早期断言失败已保留为测试宿主限制，不能报作通过。
- Homebrew OpenCC 1.4.2 CLI 对本次含 NUL 的 11 MiB 语料只产生 678 字节，不适合作为这项完整性测试基准。最终采用应用锁定 wrapper 的独立整篇转换（不调用 streaming），不是修改预期迁就输出。
- iPad 100 MiB 后台中止是 Simulator 真实 App 生命周期证据，不是物理设备内存/锁屏保护验收，也未量化后台 lease 和 idleTimer 的释放。

## 尚未完成

- #259 当前余项：真实后台 lease 过期；其他任务状态的最大字号操作、VoiceOver、窄窗口与布局切换的完整编辑器阅读状态矩阵。iPad 系统导入/导出、任务占用、准备/转换/保存窗口关闭及 ready 接管、idle 原值 false/true 恢复已由下方后续证据补齐（均为 Simulator 范围）。
- #260：签名 iPhone/iPad 100 MiB 全流程和峰值内存、低内存设备、真实 Files/iCloud/第三方提供方、低空间、锁屏文件保护、异常终止；通过后才评估打开生产开关。
- #16：最低系统；#14/#71：真实 Pro 资格与购买。

以上均未计为通过，本记录不关闭 #259/#260。

## 后续验收：导出窗口关闭与 iPad 系统工作流

应用提交 `663fe6dcb21d861f58370af26cde3cf8f82f6dde` 修复保存面板所属窗口被关闭后仍停留 exporting 的问题：立即撤销该次导出身份并回到 ready，异步准备和旧窗口的迟到回调均不得再次发布 URL 或清理新窗口使用的结果。native 回归覆盖准备中关闭、已呈现关闭、另一个 owner 接管与旧成功回调；双端构建通过。此项协调器证据不能替代真实 iPad 双窗口交互验收。

iPad Pro M4 / iOS 18.6 Simulator / 834×1210pt / 繁中浅色：最大辅助字号的确认面板可滑动到转换与取消按钮，点击可见取消后任务面板消失；已恢复默认字号。随后从系统“我的 iPad”选择 11 MiB TXT，转换并通过系统保存面板导出，输出 SHA 与先前独立整篇参考完全一致、私有任务目录为空、界面回到主页。录屏分为选取/转换/打开保存，以及保存完成两段；第一段首次点击时面板尚在移动，未触发保存，第二段稳定后完成。

因此本地模拟器的 iPad 系统导入/导出、最大字号确认页滚动取消已补齐。iCloud/第三方提供方与物理设备仍在 #260；其他状态的大字号、VoiceOver、实际多窗口、idleTimer/lease 与窄窗口编辑状态仍未完成。

## 真正 App 宿主的资源读回

应用提交 `df3f57594d38a60d2277cbbdb9c720a5bd2752f9` 增加只读 QA 资源追踪：仅 `DEBUG`、专用 Bundle `org.gewill.OpenCCman.WhatsNewUITests` 且显式 `-qa-mobile-file-resource-trace` 时生效，记录事件、App 是否 active、idleTimer 和资源所有权布尔值，不记录正文或文件名；在串行队列写入 QA App 的 tmp/mobile-file-resources-qa.json，正式构建不包含该追踪。正常文件任务仍需原有 `-qa-enable-mobile-large-files`、QA 资格参数。

在真正运行的 iPad iOS 18.6 Simulator App 中，完成 11 MiB 转换、100 MiB 转换中 Home 退后台取消，分别读回 before_begin → after_begin → after_end：

| 时点 | idleTimerDisabled | 持有 idle 覆盖 | 持有后台任务 |
|---|---|---|---|
| 开始前 | false | false | false |
| 开始后 | true | true | true |
| worker 返回后 | false | false | false |

成功路径结束时 App active；后台取消路径结束时 App 非 active，且未完成私有目录为空。该证据来自实际协调器 beginWork/endWork 调用的 UIKit 适配器，不是无界面 XCTest 注入通知。资源所有权读回结合源码中的 beginBackgroundTask/endBackgroundTask 调用，不是对系统任务登记表的独立查询。精确事件、源码哈希和双端构建日志哈希见 app-resource-lifetime.json。

重现步骤：在隔离 QA Simulator 中以对应参数启动 App，选取测试 TXT，点击转换；成功路径等待 ready，取消路径在转换中按 Home。等实际 worker 结束后读取容器 tmp 中的 JSON，确认三条事件顺序和上述资源状态；取消再核对私有任务目录。使用专用模拟器与自生成语料；不向正式 App 写设置。

本次补齐默认 idle=false 的成功与后台取消资源恢复。原先 idle=true、系统真实 lease 过期、真机锁屏与文件保护尚未计为通过，仍保持后续验收；未修改或启用 VoiceOver。

## 实际双窗口：初始路由与结果接管

2026-10-01，在 e04863d 基础上将应用 Router 初始路径明确为 `/home`。iPad 第二个 UIKit 场景原先持续空白；修改后第二窗口可显示主页，避免依赖 `/` 的出现回调再跳转。没有改动路由库或依赖缓存。iOS Simulator arm64、macOS arm64/x86_64 Debug 构建及 project/language/control labels 检查通过。

在英语浅色、834×1210pt 的 iPad M4 / iOS 18.6 Simulator 中，实际创建两个前台 UIWindowScene（504pt/320pt）：左窗持有 11 MiB 确认任务，右窗从系统 Files 导入会提示已有任务；左窗完成转换后，通过 UIKit `requestSceneSessionDestruction` 关闭左窗，右窗出现 Open file task，点击后显示 Ready to save 和可用保存/删除操作。结果仍为 11,534,336 字节，SHA 与独立整篇参考一致。

场景创建/销毁通过 LLDB 附加专用 QA App 调用 UIKit，交互用 AXe 与系统选择器，未直接调用协调器修改状态。录屏、源码哈希及精确范围见 two-window-runtime.json。此项证明真实模拟器场景的 ready 接管，不证明转换中关闭、保存面板打开时关闭、接管后实际保存或物理设备资源行为；这些仍保留待验收。

### 保存面板打开时关闭窗口

在 `4b36d7a` 的同一 QA App 中补齐：左窗口打开系统保存面板后，通过 UIKit 销毁其 scene；右窗口接管保留任务，再次打开系统保存面板，保存到“我的 iPad”并选择“保留两者”。新文件 `地区用词测试-converted 2.txt` 为 11,534,336 字节，SHA-256 `bb91fb919f2671d9538af2e97e016b435746eff3ea385169db5d63bcc4947c67`，与独立整篇参考一致；保存后私有任务目录为空。

因此上一节中“保存面板打开时关闭、接管后实际保存”两项已补齐实际模拟器证据。并未人工注入迟到回调，此项由此前协调器测试覆盖；转换中关闭、物理设备、VoiceOver 等尚未完成。录像包含系统保存面板、场景关闭、另一窗口接管与重新保存，见同一 JSON 媒体哈希。

## 转换阶段关闭所属窗口

源码 `4b36d7a`，iPad M4 / iOS 18.6 Simulator，英语浅色默认字号，834×1210pt。自生成 100 MiB 输入进入实际 `Converting File / 5%`，通过 UIKit 销毁所属 scene，另一窗口保持前台。worker 结束后私有任务目录为空；before_begin → after_begin → after_end 读回 idle=false → true → false，后台任务/idle 覆盖所有权最终均 false，App 始终 active。源码未修改，QA 参数只用于入口与资格。录像、截图哈希和资源读回见 converting-owner-close.json。

准备阶段关闭另有 PR 附件证据；本项补齐实际转换中的窗口关闭。测试过程中一次检测脚本因大小写不匹配而错过状态，未执行销毁，未计通过。多窗口系统恢复也曾不带启动参数，已读取 NSProcessInfo arguments 确认；通过 UIKit 关闭专用 QA 场景后重新启动并核对参数，才进行本次测试。未修改生产逻辑或依赖。

这里证明 Simulator 生命周期与清理，不证明真机内存/文件保护、原 idle=true 恢复、真实后台期限到期、VoiceOver 或完整编辑器阅读状态矩阵。生产开关仍关闭。

## 原先已经禁止自动锁屏的恢复

2026-10-01，iPad M4 / iOS 18.6 Simulator 专用 QA App，源码 `4b36d7a`。读到初始 idleTimerDisabled=false 后，通过 LLDB 在主线程仅设置 UIKit 该属性为 true，再由正常确认页开始 11 MiB 转换。实际资源追踪 before_begin / after_begin / after_end 中 idle 均为 true；覆盖与后台任务所有权 false → true → false，界面完成到 Ready to save。

转换后的 UIKit 再读回 true，随后恢复测试前的 false 并再次读回 false。没有开关 VoiceOver，没有修改正式 App 偏好。精确事件见 idle-prior-true.json。本项证明原值 true 的成功恢复，加上此前原值 false 的成功与取消路径；不证明真机自动锁屏计时或真实后台 lease 到期。

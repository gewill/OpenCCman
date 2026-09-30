# #259 移动端工作流开发检查点

日期：2026-10-01。依赖 #262 的 `3f3bd8b03b583c45bf1563282eac6cf9f3818ea7`。本记录不是 #259 完成声明，生产移动端仍限制 10 MiB。

## 已实现但尚未接入主页

- `MobileLargeFileCoordinator`：主线程上的 App 级任务状态、一次预约、开始时重查 Pro、冻结配置、准备/转换/取消/待保存/保存状态、原窗口关闭后的完整结果接管、保存取消/失败重试、按 UUID 拒绝迟到回调。
- 对 worker 的取消派发到后台，避免主线程等待提交锁；工作资源仅在实际 worker 及输入句柄收尾后释放。数值更新在进入主线程任务队列前按 100 ms 节流。
- `MobileLargeFileService` 增加确认时的源指纹校验，防止确认期间文件被修改后按旧信息开工。快照完成回调在文件 worker 上释放原选择器输入句柄和安全域。
- `MobileFileLifecycle`：UIKit 通知适配与有限后台任务/自动锁屏状态的成对管理；短暂 inactive 不取消，App 后台、全部 scene 后台、内存警告和保护数据不可用请求中止。
- `MobileFileExporter`：使用 `UIDocumentPickerViewController(forExporting:asCopy:true)`，只传文件 URL；代理只回报一次，空 URL 或取消不算保存成功。成功回调不代表云端同步完成。

以上组件尚未由 App 级唯一实例和 RootView/HomeScene 调用，没有开放文件入口或改变现有稿件、额度、购买逻辑。

## 当前运行证据

`check-core.py` 使用实际服务与协调器通过：Pro 选择/开始双重检查、多个窗口的唯一预约、配置冻结、开始/结束资源配对、窗口接管、旧保存回调拒绝、保存取消及重试、确认后源文件被改写的拒绝；完整原有转换、Mac 文件服务及 Shortcuts 回归同样通过。

`check-mobile-file-jobs.py` 同时执行服务、协调器和 UIKit 通知适配测试，以及五处实际 SIGKILL 后新进程恢复。精确源码哈希和 XCTest 结果随本检查点保存。

### 已发现的测试宿主边界

SwiftPM 的 iOS XCTest 是无界面 `xctest` 进程。在该进程中设置 `UIApplication.isIdleTimerDisabled` 不能证明 App 的防自动锁屏行为，第一次此断言实际失败。该失败未作为产品功能通过：仅保留通知注入测试，真实 App 中的 idleTimer 原值恢复、后台 lease 配对/过期、真实 scene 后台与锁屏列为下方必做项。通知注入不能取代真实系统事件。

## 继续顺序

1. 创建 App 级唯一运行时：私有目录在 worker 初始化，配对 UIKit 生命周期适配；以 QA 独立 Bundle + 显式参数启用，生产保持关闭直到 #260。
2. 系统选择器的大文件路由与 Pro 入口（拖放维持 10 MiB），接入三语任务面板，保留编辑器和结果；补损坏 journal/清理失败的用户确认删除与重试。
3. 保存 sheet 的取消、系统回调和交互式关闭都按捕获的任务 ID 处理，恢复结果只能由一个窗口呈现。
4. iPhone/iPad 同条件真实前后截图、交互录像，经 gh --attach 上传；实际 App 验证后台/锁屏/窗口关闭、idleTimer/后台 lease、取消及恢复、保存取消重试、布局切换和原稿保持。
5. 运行最终候选双端完整构建及回归后创建 #259 PR（依赖前序分支），不关闭尚有未完成验收的 Issue。

#260 继续承接真实提供方、低空间、签名 100 MiB 全 App 容量及内存；#16 最低系统、#14/#71 真实 Pro/购买仍须独立证据。不得把本检查点写成移动端 100 MiB 已开放。

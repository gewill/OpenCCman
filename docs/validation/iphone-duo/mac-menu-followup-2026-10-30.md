# Mac 窄窗菜单与稿件保持补验（2026-10-30）

关联 #280 / #282；两项继续开放。对 [46 个剩余 Issues 的盘点](../remaining-acceptance-2026-10-30.md) 后，本轮先尝试 Duo 未完成菜单矩阵；启动环境阻塞后，完成 Mac 共享工作区的一组独立补验。没有复现需要修改产品代码的缺陷。

## 合并、源码与产物

#270 固定 HEAD `f99385364792fb91d920507e427aa63f6309f0a2` 的 App Regression / App icon 与两轴审核均通过，无未解决审核线程；按 expected HEAD squash 合入 develop `54786a26abeb7404ed09aa3207b79b09c80397ab`。单父且 tree 与审核 HEAD 一致，[该精确 squash 的 push CI](https://github.com/gewill/OpenCCman/actions/runs/41009437322) 已通过。不是外部 GitHub APPROVED，也没有发布。

验收时工作区干净，App/工程 tree 与冻结 `bccf261` 相同。复用既有 Debug QA 2.1(30)、Bundle ID `org.gewill.OpenCCman.WhatsNewUITests`；Mac dylib SHA-256 `9f226919e7e888996cc2c0f0b34bf94c720d048006f5979dd303e101cbd0da9e` 匹配 [原构建记录](input-task-followup-2026-10-29.json)。这不是新构建或签名分发产物；本次没有新增 Xcode 构建、改依赖或生产开关。

主机 macOS 27.2 (26B123)，Xcode 27.1 (27A9275)，devicectl 651.32，sim-use 0.16.0，AXe 1.8.0。工具版本以本次读回为准，不照抄上轮的 devicectl 651.13.5。Mac 交互使用 CUA，记录器只捕获指定 QA 窗口及其子菜单，不录全屏/其他 App/音频/麦克风。

## 实际完成的范围

英语，窗口实际 **300×412 pt**（600×824 像素）；沿用已存在的窄窗状态，没有重新测量系统最小尺寸。普通示例输入与结果均为 22 UTF-16、66 UTF-8 字节，精确全文哈希见 [结构化结果](mac-menu-followup-2026-10-30.json)。

| 操作 | 实际结果 | 范围限制 |
| --- | --- | --- |
| 普通转换 | 点击示例后实际 Convert，原文/结果分别为简体/繁体预期全文；复制/导出入口 enabled | 非性能/额度/提供方矩阵；本轮没有再导出文件 |
| 100% 左右布局偏好 | 实际选择后显示 “Using stacked layout in this window. Side by side will return when space permits.”；原稿/结果保持 | 证明窄窗回退，未验证这次再拉宽自动恢复 |
| 150% 增大结果 | 分栏比例 55%→50%，完整原文/结果保持 | 比例依据原生 AX，不只凭点击成功 |
| 150% 增大原文 | 50%→55%，完整原文/结果保持 | 本次短文样本 |
| 150% 等分 | 55%→50%，完整原文/结果保持 | 未扩大到所有连续比例 |
| 150% 上下布局 | 实际选择，窄窗回退提示消失；原文/结果保持 | 未测本次横向宽窗 |
| 设置/返回/正文滚动与恢复 | 150% 设置返回、滚动后全文保持；恢复 100%、上下布局和 50%，原文/结果仍相同 | 只证明记录覆盖的状态；不宣称全部菜单/所有控件可达 |

七份独立 AX 快照核对精确原文、结果、比例与预期一致。没有将默认/150% 的局部结果扩写为完整三语/字号、VoiceOver、系统工具栏溢出或 Duo 矩阵。

## 精选证据

两张截图均为同一 QA App 的真实窄窗，不是代码前后改版：

| 100% 左右偏好的窄窗回退 | 150% 正文实际滚动后 |
| --- | --- |
| ![100% 窄窗回退](https://github.com/user-attachments/assets/42d0b408-86d8-4748-b510-9270514daea3) | ![150% 正文滚动](https://github.com/user-attachments/assets/f57abd81-cc28-4c57-8128-d1d2bebc6ed5) |

https://github.com/user-attachments/assets/f2f771d3-b00a-47c0-a42f-eeae8ee2cce0

原片 72.16 秒，分享副本为 H.264、600×824、CFR 15 fps、72.20 秒、250,226 字节，无音轨；不剪动作、仅普通菜单演示降帧/压缩，不作为动画/时序指标。原片与副本均用系统播放器从 0 播放至尾，另完整解码、抽帧核对。原片变帧率，在 null mux 解码检查时有时间戳警告；原件保留，CFR 副本整段解码无该警告。

原 PNG 已约 58/59 KiB，保留同字节副本；当前 FFmpeg 没有 WebP encoder，未为此安装编码器。实际上传仅两图一视频，总 367,259 字节，全部读回远端字节并核对 SHA，后续 Issue/PR 复用 URL。上传时 gh 未替换正文中含空格的本地路径，已在同一原评论修正为成功附件 URL并回读，无重新上传或死链。

[Issue #282 实际补证评论](https://github.com/gewill/OpenCCman/issues/282#issuecomment-6516196687)。源文件、上传副本哈希、原生快照与日志索引见 JSON；原件在仓库外保留，媒体不加入 Git。

## 失败、操作偏差与未执行项

- 专用 Duo `4CAD3041-0744-41A6-8B4E-F934CA9F0778` 初始为 Shutdown。两轮 boot/bootstatus 组合调用均退出 145，stderr 均报告 CoreSimulator 401 “runtime path not found”，尽管 runtime 列表标为可用且路径可读。启动环境不一致原因未定位，未进入 App，不能归因产品，也不能记姿态通过。
- 在 Shutdown 状态读取 fold 又报 Get Display Information capability 不支持；前置未满足，不能由此诊断 sim-use 不支持原生折叠。没有重启/强停共享 CoreSimulator 服务、删除/重装 runtime 或操作其他设备。
- QA 快捷键页实际显示 “Accessibility permission required”。没有点击 Grant Permission 或授予新权限；跨 App 快捷键/Services 仍由 #19/#274 跟踪。不是生产 App 的权限结论，也没有把权限提示当成功。
- 100% 时一次额外 Return 在菜单异步更新后落入焦点编辑器，增加换行并按正常规则使旧结果失效。该快照单独排除；恢复固定输入并实际重新 Convert 后才运行 150% 测试。不归因布局菜单丢稿，不把修正前后混作连续全文保持。
- 旧单窗口 recorder 退出 134，报 `CGS_REQUIRE_INIT` 断言。使用正常 AppKit delegate/主循环初始化的新记录器后实际录制成功；本轮仅确认替代入口有效，未声称单独定位断言根因。录像只含 PID 29557 的指定 QA 窗口，失败原件日志保留。

Duo 方向/姿态/默认与 XXXL/三语、实际溢出、导入中跨尺寸、Preparing/Cancelling、保护数据、最终签名包与真机仍未由本次完成。最低系统 #16、交易 #14/#71、生产开放/容量 #260/#268、完整系统入口 #19 各自保留。

## 收尾

100% 文字大小、上下布局、50% 比例已回读；菜单栏图标及登录启动保持 off。取消了不必要的 Clear Source 确认，没有删除数据。随后退出本轮 QA App；只关闭新回放窗口，保留既有 QuickTime 窗口。记录器均已结束。

Duo 始终未启动成功，最终回读 Shutdown，无需再发 shutdown；没有批量关闭或删除设备。未改变全局工具链、辅助功能权限、生产 App、账户/购买或用户稿件；本轮无提交商店、分发或部署。

# iPhone Duo 分阶段验收补充（2026-10-29）

关联 #277–#282。应用冻结于 develop `bccc0df9f7f59b5d172d3396c1ee8f2aea13047c`，
其 tree 与 PR #284 的 `898b74a8ca660c4a74c385dd999213a9595d18d2` 一致。
本轮只新增／修正 UI 测试和证据记录；应用、工程、依赖、CI、额度／购买、容量及生产开关不变。
[机器可读结果](acceptance-followup-2026-10-29.json)记录实际测试源码哈希，未把旧 SHA 当作修改后的测试来源。

## A 构建基线已单独收口

[#278 关闭复核](https://github.com/gewill/OpenCCman/issues/278#issuecomment-6475193989)逐项对应其四项关闭标准。
重新核对已有两端原生日志的成功结束、产物哈希和 dirty delta 与最终源码的对应，
不是冒称本轮重新构建。iOS SDK 27.1、macOS SDK 27.0，最低系统保持 15/12；
锁文件未变。产物校验 6 项通过，实际 CLI 的 Xcode 27.0 负对照返回 1 且 report=failed。
合并提交的 [push CI](https://github.com/gewill/OpenCCman/actions/runs/40696252781)已完成：
App Regression 和 App icon 成功。原 Actions 工具链仍为 26.3，不代表 27.1 云端验证。
Cloud 签名候选仍归 #282，最低系统运行归 #16，真实交易／用户中心归 #14/#71。

[远端截图／录像与失败回读记录](https://github.com/gewill/OpenCCman/issues/282#issuecomment-6475733596)共 6 张图片、1 段录像；
已确认正文无本机媒体路径，未重复上传既有英语素材。

## 本轮运行结果

环境：Xcode 27.1 (27A9275)，iOS 27.1 (24A94425)，专用模拟器
`OpenCCman Duo QA 277 / D4FE3CC7-4DBF-4333-84A7-FEA788DBD897`，
QA Bundle ID `org.gewill.OpenCCman.WhatsNewUITests`。
应用执行文件 SHA-256 为 `31b4512f5d393e9e1348f996ab56dd3710fbeea21984e0cf75696fcf5be5b30e`。
每次 Xcode 调用前检查在运行构建，不终止其他项目进程；证据、xcresult、原图与录像在仓库外保留。

| 场景 | 状态 | 实际证据及边界 |
| --- | --- | --- |
| 窄外屏三语 Pro，默认 large | 通过 | 3 项、0 失败、0 跳过，52.370 秒；每张 alert／Pro sheet 的 App 与 window 均为 466×678 |
| 同上，系统 XXXL | 通过 | 3 项、0 失败、0 跳过，52.371 秒；同为 466×678，结束恢复 large；不是 AX 字号 |
| 提示可读性与动作 | 通过（上述局部场景） | 六张提示原图及副本分别检查，标题／说明／两种动作完整；取消→再次打开→打开 Pro→关闭，原文保持；不证明真实购买或 offerings 可用 |
| 设置弹层打开时拉宽 | 验收失败，原因未定 | 宿主和 App trace 确认 466×678→950×669；Done 移动／可点击联合判据超时，1 项失败，103.354 秒；未执行后续窄态返回与关闭后全文校验 |
| 原生身份（上行局部） | 通过（元数据范围） | 同一 scene／模型／两个 UITextView；转换完成后两种尺寸均为 22 UTF-16 原文和结果；division 没有激活，不是折叠区通过 |
| 完整姿态与双侧分屏、IME、选区／中段滚动、运行中任务／系统文件面板、启动交接 | 未执行 | 仍按 #279–#282 原标准推进；不从尺寸、短文或当前截图外推 |
| 真机、最终签名分发包、最低系统、真实交易 | 未执行 | 原验收归属保留；VoiceOver 体验未验证 |

Pro 测试新增简体／繁体用例，分别定位实际本地化的“会员／會員”；不再假设中文按钮叫 Pro。
取证使用所有 active simulator screens 并标明 display index，再挑选实际可见 QA 画面。
App-scoped screenshot 曾输出黑图，不能作为视觉通过依据。窗口 frame 日志、截图和动作结果相互核对。
[复跑入口与三个选择器](../../../Tests/UI/WhatsNewPresentation/README.md#duo-pro-alert-localization)。

## 设置缩放失败的最小复现与下一步

1. 选中专用设备并确认外屏竖向。启动 QA App，填入示例并转换，打开 Conversion settings。
2. 从宿主运行以下命令并保持该会话；实际 start 输出 Requested 与 Actual 均为 950×669。

```bash
DEVELOPER_DIR=/Applications/Xcode-27.1.0.app/Contents/Developer \
  xcrun devicectl device appResize start --device <dedicated-duo-udid> --preferred-size 950x669
```

3. App probe 确认 window=950×669、container=950×575、safe area=[74,0,20,0]；
   设置 sheet 的实际截图仍显示标题、选项与 Done（勾号）。
4. 临时 XCTest 等待 `close.frame.midX > initialClose.midX + 100 && close.isHittable`，
   90 秒内未满足。可见按钮不能替代点击成功，该联合条件也不足以单独证明产品缺陷。
   临时失败用例、完整源码及日志已保留于外部证据，未把未稳定的用例混入本 PR 的常规测试。
5. 下一次先分别采集当前 `close.frame`、`isHittable` 与所在 display／window，并与专用 Device Hub
   窗口中的真实关闭动作对照；确定是测试定位、系统跨显示器自动化还是应用问题，再定向修复。
   不删除条件或改写通过口径。该项及窄态返回仍由 #282 承接，#280 回链。

## 失败、重跑与取证边界

- 初次中文测试使用英文 Pro 定位而失败，实际按钮是正确的“会员／會員”；修正测试后通过，没有修改产品本地化。
- 早期三语动作已通过，但 app-scoped 图像为黑图，不能证明可读性；改为多屏捕获后补采。
  早期内屏宽态与最终 466×678 窄态结果分别保存，不把宽态计作窄态。
- 首次设置缩放被 appResize 以 24001 拒绝（当时方向不支持），不计作产品失败；
  切回可用外屏竖向后，第二次实际拉宽成功，但联合判据超时，仍不计该场景通过。
- Device Hub 原窗口被其他任务切换，已另建独立窗口；没有把工具动作返回或未核对的姿态操作计为通过。
- 测试 runner 提示链接的 XCTest 库最低为 iOS 17；实际运行在 27.1，不宣称 iOS 15 测试通过，应用下限未变。
- 本轮未重新运行 #284 全部矩阵或重做共享 Mac 构建；本轮没有影响应用构建输入。
  原先成功的证据按其原始来源保留，当前增量不替代原 Issues 的完整关闭标准。

#279–#282 继续开放；#283 仍按条件项处理。没有触发 Xcode Cloud、分发、部署或商店提交。

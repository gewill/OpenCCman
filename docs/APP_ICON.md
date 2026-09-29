# App 图标

App 图标是 Icon Composer 格式的 `OpenCCman/AppIcon.icon`，iOS 与 macOS 共用一份分层源文件。Xcode 26 及以上编译时，为 iOS 26 / macOS 26 起的系统生成 Liquid Glass 分层图标，并为部署下限以上的旧系统生成拍平的回退图：iOS 15–17 的 PNG、iOS 18 的浅色／深色／着色三种 1024 图，以及 macOS 12–15 带传统留白与投影的 `AppIcon.icns`。资源目录中不再保留 `AppIcon.appiconset`。

## 结构

| 组（由前到后） | 图层 | 内容 |
| --- | --- | --- |
| Glyphs | `glyph-jian.svg`、`glyph-fan.svg` | “简”“繁”，霞鹜文楷 Medium 的字形轮廓 |
| Ring | `ring-blue.svg`、`ring-purple.svg` | 两段 90° 圆弧，末端向圆心回折 45°；蓝色为简→繁，紫色为繁→简 |

- 图层 SVG 使用开屏标记的 1024 pt 设计空间，坐标与 `LaunchMark` 常量相同；`icon.json` 把两组放大 1.16 倍放到底板上。
- 圆环图层只用填充路径：圆弧带与回钩都按圆头描边的外形轮廓化，不用 SVG `stroke`。iOS 26.5 的系统图标渲染把每条路径当作填充形状并自动闭合，描边在深色、透明和着色外观下会变成实心弓形，浅色下也会沿弦出现高光；Icon Composer 的预览看不出这个问题。
- 字形组不透明，带中性阴影；圆环组关闭半透明，保留蓝紫两色的饱和度，阴影取图层颜色。
- 底板：浅色 `#F7F9FB`→`#E1E6EA`，深色 `#3C3D42`→`#25262A`，两者中点接近启动画面底色 `LaunchBackground`。
- 深色外观使用开屏深色色板（`LaunchInk`、`LaunchRingBlue`、`LaunchRingPurple` 的深色值）。着色与透明外观中字形为白色、圆环为 72% 白，未设置时黑色字形在这两种外观下几乎不可见。

## 与开屏标记同源

`OpenCCman/Model/LaunchMotion.swift` 中的 `LaunchMark` 是标记几何与笔画样式的唯一来源。`scripts/render-brand-mark.swift` 据此生成图标的两个圆环图层和开屏图 `LaunchMark`。开屏图按转场首帧的画法绘制（同一折线、线宽、端点样式，以及 `LaunchGlyph*` 模板图），系统启动画面淡出时两者重合，不会出现重影。

修改几何或颜色后重新生成：

```bash
xcrun swiftc OpenCCman/Model/LaunchMotion.swift scripts/render-brand-mark.swift -o "$TMPDIR/render-brand-mark"
"$TMPDIR/render-brand-mark"
```

需要重新导出字形时追加 `--font ~/Library/Fonts/LXGWWenKai-Medium.ttf`。玻璃材质、外观特化和缩放写在 `icon.json`，可直接在 Icon Composer 中调整。

`scripts/check-launch-transition.sh`（App Regression 的一部分）会运行 `render-brand-mark --check`：圆环图层与 `LaunchMark` 不一致，或图标的深色颜色与开屏色板不一致时失败。

编译 `.icon` 需要 macOS 26 及以上的主机：Xcode 26.3 的 actool 在 macOS 15 上会崩溃。CI 在 macOS 15 上构建时经 `scripts/without-app-icon.xcconfig` 省略图标，另由 `App icon` 任务在 macOS 26 上运行 `scripts/check-app-icon.sh`，编译两端并检查浅色、深色、着色图标与旧系统回退图；本地也可直接运行该脚本。详见 [CI 说明](CI.md)。

## 字体来源与授权

“简”“繁”的轮廓取自霞鹜文楷（LXGW WenKai）Medium 1.520，采用 SIL Open Font License 1.1。2.0 图标中的两个字就是用这款字体排的：按字形外框对齐后，与旧图标逐像素比对的差异只在抗锯齿边缘。矢量化没有改变字形。仓库和 App 只包含这两个字的轮廓路径，不分发字体文件。

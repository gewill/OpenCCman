# OpenCCman

[English](README.md) · [简体中文](README.zh-Hans.md) · 繁體中文

基於 [OpenCC](https://github.com/BYVoid/OpenCC) 的原生中文轉換 App，支援 iPhone、iPad 與 Mac。在裝置本機完成簡繁轉換，並調整地區用詞。

[官網](https://openccman.gewill.org/zh-Hant/) · [App Store](https://apps.apple.com/app/id6474449401) · [隱私權政策](https://openccman.gewill.org/zh-Hant/privacy.html) · [支援](https://openccman.gewill.org/zh-Hant/support.html)

[![在 App Store 下載](assets/Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917.svg)](https://apps.apple.com/app/id6474449401)

## OpenCCman 2.2

- 提供簡體中文、OpenCC 繁體、臺灣正體與臺灣詞組、香港繁體四種常用預設，異體字與地區用詞仍可在進階選項中調整。簡體輸出不等於完整的臺灣詞彙反向轉換。
- 在 Mac 與 iPad 上，原文與結果可左右或上下對照。每個視窗保留獨立的佈局選擇，窄視窗暫時採用上下排列。iPhone 的工作區依視窗大小排列，寬視窗也可左右對照，並使用精簡的「轉換」按鈕，為文字留出更多空間。
- 在 Mac 上，可用自訂全域快速鍵轉換其他 App 中選取的文字，並取代可編輯內容，或將選取文字送到 OpenCCman。相容的 App 也可透過 macOS「服務」呼叫轉換。取代操作需要輔助使用權限，並取決於來源 App 是否支援。
- 可匯入或拖入單一不超過 10 MiB 的 UTF-8 TXT，支援含 BOM 的檔案；最近一次成功結果可匯出為不含 BOM 的 UTF-8，並保留換行、空行與 Unicode 字元。在 Mac 上，Pro 可將單一大於 10 MiB、最多 1 GiB 的 UTF-8 TXT 直接轉換為檔案，顯示進度、可以取消，編輯器中的稿件保持不變。在 iPhone 與 iPad 上，Pro 可將單一大於 10 MiB、最多 100 MiB 的 UTF-8 TXT 直接轉換為在儲存面板中選定的檔案；轉換在 App 開啟時進行，切到背景會安全中止。所有裝置上的拖放與編輯器仍限 10 MiB。暫不支援批次轉換與 Big5／GBK 解碼。
- 在 iOS／iPadOS 16 以上與 macOS 13 以上，可用免費的「捷徑」動作自動轉換文字：支援四個預設、最多 10 MiB 的 UTF-8 文字，不計入首頁轉換次數。
- 新稿從空白工作區開始，也可「填入範例」。「清空原文」會先確認，再清除原文與結果。
- 可以取消轉換或匯入，之後才傳回的結果不會覆蓋目前文字。取消不會強行中斷已在進行的原生轉換。
- 免費版每天可完成 12 次成功的首頁轉換。終身 Pro 解除這項限制並隱藏 App 推薦，已有的終身購買繼續有效。匯入、匯出及切換預設不計入每日次數。

OpenCCman 2.2 需要 **iOS／iPadOS 15 或 macOS 12**，可選的「登入時啟動」需要 macOS 13 以上。技術變更與驗證範圍見 [2.2 發布說明](https://github.com/gewill/OpenCCman/releases/tag/v2.2)（含繁體中文段落）與英文 [更新日誌](CHANGELOG.md#22---2026-11-01)；先前的 [2.1 發布記錄](docs/release/launch-2.1-20261001.md) 仍可查看。

## 開發

日常 App 開發以 `develop` 為目標；`main` 承載已發布版本與每週執行的上游同步協調器。只有暫時的 `build` 前綴分支會觸發 Xcode Cloud 打包。修改發布或建置設定前，先讀 [分支規範](docs/BRANCHING.md)、[CI 指南](docs/CI.md) 與 [Xcode Cloud 指南](docs/XCODE_CLOUD.md)。

在裝有 Xcode 命令列工具與 Python 3 的 macOS 上，依需要執行相關的獨立檢查：

```sh
bash scripts/check-project.sh
python3 scripts/check-core.py
bash scripts/check-quota.sh
bash scripts/check-whats-new.sh
bash scripts/check-control-labels.sh
bash scripts/check-pasteboard.sh
```

這些檢查不能取代 Xcode Cloud 簽署建置或裝置驗收。[自適應工作區驗收](docs/validation/adaptive-workspace/README.md)、[效能證據](docs/performance/README.md) 與 [Build 56 記錄](docs/validation/build-56/README.md) 說明已測試的內容與仍未完成的事項。

[2.1 捷徑動作範例](docs/SHORTCUTS.md) 介紹純文字自動化及其支援的系統。[行動裝置大檔案說明](docs/IOS_LARGE_FILES.md) 介紹 2.2 在 iPhone／iPad 上的 100 MiB Pro 檔案流程及其剩餘驗證。

[上游同步指南](docs/upstream-sync.md) 說明每週經審查的 SwiftyOpenCC 與 OpenCC 更新流程。引擎相關維護見 [SwiftyOpenCC 儲存庫](https://github.com/gewill/SwiftyOpenCC/blob/master/docs/upstream-sync.md)。

早期的 [1.3 驗收](docs/version-1.3-validation.md)、[專案稽核](docs/project-status-and-follow-up-2026-09-13.md) 與 [交接記錄](docs/handoff/2026-09-16/README.md) 是附日期的歷史記錄，不代表目前的發布狀態。

## 致謝與授權

OpenCCman 基於 BYVoid 的 [OpenCC](https://github.com/BYVoid/OpenCC) 與 ddddxxx 的 [SwiftyOpenCC](https://github.com/ddddxxx/SwiftyOpenCC)，以 [MIT](LICENSE) 授權條款釋出。

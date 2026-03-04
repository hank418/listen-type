# ListenType

macOS 語音輸入工具 — 按快捷鍵錄音，自動轉成文字並輸入到任何應用程式。

## 運作原理

```
⌥S 按下 → 麥克風錄音 → WAV 音檔 → whisper.cpp 語音辨識 → (Ollama 潤飾) → 模擬貼上到游標位置
```

ListenType 常駐在 menu bar，透過全域快捷鍵 `⌥S` 觸發錄音。錄音結束後將音檔交給本機端的 [whisper.cpp](https://github.com/ggerganov/whisper.cpp) 進行語音轉文字（使用 large-v3 模型，支援繁體中文）。如果有安裝 [Ollama](https://ollama.com)，會再經過 LLM 潤飾（修正口誤、去贅字、加標點）。最後透過模擬 `⌘V` 將文字貼到當前游標位置。

**所有處理都在本機完成，音檔不會上傳到任何伺服器。**

## 技術相依

| 元件 | 用途 | 備註 |
|------|------|------|
| [whisper.cpp](https://github.com/ggerganov/whisper.cpp) | 語音轉文字（STT） | 靜態編譯，已打包在 app 內 |
| ggml-large-v3 模型 | Whisper 語音辨識模型 | 約 3GB，首次啟動自動從 HuggingFace 下載 |
| [Ollama](https://ollama.com) + gemma3:4b | 文字潤飾（選用） | 需另外安裝，不裝也能用 |
| AVAudioEngine | 麥克風錄音 | macOS 內建框架 |
| Carbon Events | 全域快捷鍵 `⌥S` | macOS 內建框架 |
| CGEvent | 模擬鍵盤貼上 | macOS 內建框架 |
| SwiftUI MenuBarExtra | Menu bar 常駐 UI | macOS 13+ |
| Metal (GPU) | whisper.cpp 推論加速 | Apple Silicon / Intel GPU |

## 系統需求

- macOS 13 (Ventura) 以上
- Apple Silicon Mac（M1/M2/M3/M4）
- 約 3GB 磁碟空間（語音辨識模型）

## 安裝

1. 開啟 `ListenType-1.0.dmg`
2. 將 `ListenType.app` 拖到 `Applications` 資料夾
3. 首次開啟 app，系統會顯示無法打開的警告
4. 到「**系統設定 → 隱私與安全性**」→ 下方找到 ListenType 的提示 → 點擊「**仍要打開**」

### 權限設定

macOS 會要求以下權限，請務必允許：

- **麥克風** — 錄音用，系統會自動跳出提示
- **輔助使用** — 模擬鍵盤貼上文字用，需到「系統設定 → 隱私與安全性 → 輔助使用」手動加入 ListenType

## 首次使用

> **⚠️ 注意：首次啟動會自動下載約 3GB 的語音辨識模型，請確保網路暢通且有足夠磁碟空間。下載完成前無法使用錄音功能。**

1. 啟動後 ListenType 會出現在 menu bar（🎙 麥克風圖示）
2. 畫面上方會出現通知提示模型正在下載
3. 點擊 menu bar 圖示可查看下載進度（已下載 / 總共 MB）
4. 下載完成後會播放提示音，即可開始使用

模型儲存位置：`~/Library/Application Support/ListenType/models/`

## 使用方式

| 快捷鍵 | 功能 |
|--------|------|
| `⌥S` (Option+S) | 開始 / 停止錄音 |

1. 將游標放在要輸入文字的地方（任何 app 都行）
2. 按 `⌥S` 開始錄音 — 畫面上方出現紅點「錄音中…」
3. 說完後再按 `⌥S` 停止 — 顯示「處理中…」
4. 稍等幾秒，辨識出的文字會自動打在游標位置

## Ollama 文字潤飾（選用）

安裝 [Ollama](https://ollama.com/download) 可啟用文字潤飾功能，自動修正口誤、去除贅字、加入標點符號。

```bash
# 安裝 Ollama 後，拉模型
ollama pull gemma3:4b
```

未安裝 Ollama 時 app 仍可正常使用，只是輸出原始轉錄文字。Menu bar 選單會顯示 Ollama 連線狀態。

## 建置（開發者）

```bash
# 1. 編譯靜態 whisper-cli（首次）
cd /private/tmp/whisper.cpp
mkdir -p build && cd build
cmake .. -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DGGML_METAL=ON
cmake --build . --config Release -j$(sysctl -n hw.ncpu)

# 2. 建置 app
scripts/build.sh

# 3. 建立 DMG
scripts/build-dmg.sh
```

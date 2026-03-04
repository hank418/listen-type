# ListenType — macOS 語音輸入 App 設計文件

## 概述

一個 macOS 選單列 App，按 Option+S 觸發錄音，使用本地 Whisper 模型將語音轉為文字，再透過本地 Ollama LLM 潤飾成書面文字，最後模擬鍵盤逐字輸入到當前焦點 App。

**目標**：免費、本地執行、類似 Typeless 的語音輸入體驗。

## 使用流程

1. App 常駐選單列，顯示狀態圖示
2. 按 Option+S → 開始錄音（圖示變紅）
3. 再按 Option+S → 停止錄音（圖示變處理中）
4. 自動執行：Whisper 語音轉文字 → Ollama 潤飾 → 模擬打字輸入
5. 完成後圖示恢復待命狀態

## 架構

```
┌─────────────────────────────────────────┐
│          ListenType (Menu Bar App)       │
│                                         │
│  HotKey Manager (Option+S)              │
│       │                                 │
│       ▼                                 │
│  Audio Recorder (AVAudioEngine)         │
│       │  16kHz mono WAV                 │
│       ▼                                 │
│  Whisper STT (whisper.cpp)              │
│       │  raw text                       │
│       ▼                                 │
│  Ollama LLM (HTTP localhost:11434)      │
│       │  polished text                  │
│       ▼                                 │
│  Type Simulator (CGEvent / 剪貼簿)      │
└─────────────────────────────────────────┘
```

## 元件細節

### 1. Menu Bar App

- SwiftUI `MenuBarExtra`
- 最低支援 macOS 13 (Ventura)
- 狀態：idle / recording / processing
- 圖示隨狀態變化（麥克風圖示 + 顏色）
- 選單提供：開始/停止、設定、退出

### 2. HotKey Manager

- 使用 `CGEvent` tap 監聽全域 Option+S
- 需要 Accessibility 權限
- Toggle 模式：第一次按開始錄音，第二次按停止

### 3. Audio Recorder

- `AVAudioEngine` 錄音
- 輸出格式：16kHz, mono, 16-bit PCM WAV（Whisper 要求）
- 需要麥克風權限
- 錄音暫存於 temp 目錄

### 4. Whisper STT

- 使用 whisper.cpp Swift binding
- 預設模型：`ggml-small.bin`（466 MB）
- 語言設定：zh（中文）
- 模型存放於 App 的 Application Support 目錄

### 5. Ollama LLM 潤飾

- HTTP POST 到 `http://localhost:11434/api/generate`
- 模型：llama3.2 或 gemma3（使用者可選）
- System prompt：「將以下語音轉錄的口語化中文整理成通順的書面文字。保留原意，去除贅字和語助詞，修正語法。不要添加原文沒有的內容。」
- 如果 Ollama 未啟動，跳過潤飾直接輸出原始轉錄

### 6. Type Simulator

- 中文無法用 CGEvent 直接逐字輸入
- 策略：將文字分段，每段透過剪貼簿 + 模擬 Cmd+V 貼上
- 逐段貼上之間加入短暫延遲（50ms），模擬打字效果
- 完成後恢復原本的剪貼簿內容

## 前置需求

- macOS 13+ (Ventura)
- Xcode 15+
- Ollama 已安裝並執行中
- 系統權限：Accessibility、Microphone

## 技術選型

| 元件 | 技術 | 理由 |
|------|------|------|
| UI | SwiftUI MenuBarExtra | 原生、輕量 |
| 快捷鍵 | CGEvent tap | 不需額外依賴 |
| 錄音 | AVAudioEngine | 原生、低延遲 |
| STT | whisper.cpp (SPM) | M1 優化、免費 |
| LLM | Ollama HTTP API | 免費、本地、模型可換 |
| 打字模擬 | 剪貼簿 + CGEvent | 中文相容性最好 |

## 使用者環境

- MacBook Pro M1 Pro 16GB
- 主要語言：中文（偶爾中英夾雜）
- 使用場景：全場景（訊息、文件、IDE）

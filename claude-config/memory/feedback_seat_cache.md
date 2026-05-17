---
name: feedback-seat-cache
description: 每日報告機位警示應讀快取，不每次抓 Google Sheets
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ca10f521-aa3e-46a1-b609-5d9b8627f088
---

每日報告（daily-report.ps1）的長榮北海道機位警示區塊，改為讀取 `seat-warnings-cache.txt` 快取，不每次連線 Google Sheets。

**Why:** Google Sheets 機位資料大約一兩週才更新一次，每天抓沒意義，浪費時間也可能因網路失敗卡住。

**How to apply:** 要更新機位快取時，跑 `update-seat-cache.ps1`（Eric 說他更新 Sheet 後會主動要求）。日報執行時直接讀 `seat-warnings-cache.txt`，並在標題顯示快取日期。

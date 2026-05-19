---
name: project-seat-analysis
description: 雄獅北海道航班機位競爭分析工作流程與資料來源
metadata: 
  node_type: memory
  type: project
  originSessionId: 3b69fc47-ef18-415e-bdc2-02eea734dcf0
---

分析雄獅（TRV）在 BR116 / BR166（北海道）與其他同業的機位使用量排名比較。

**Why:** Eric 負責雄獅北海道 RC，需要定期掌握各家旅行社在同班機的機位使用量，判斷哪個月雄獅落後需要加強推力。

**資料來源：** Google Sheets「長榮每週機位數追蹤」（ID: `1S8-cPyo0W2FTwIFZTQCnjdDwVIhCr9mMcj60DImgjiY`），按月份分頁（5月、6月...）。欄位為各旅行社代碼（AHY、DAS、CFT、LIF、SET、SIG、**TRV**、BWT、COS、MST、GLL、RMD）。

**分析輸出：** 存至 `C:\Users\s2633\seat-control\`，檔名格式 `YYYY-MM-目的地班號-分析.md`。

**How to apply:** 用戶說「幫我看幾月機位」→ 讀該月份頁籤 → 針對 BR116 / BR166 算各家排名、雄獅 vs 第二名差距 → 存 Markdown → 未來要做成 HTML 供同事使用。

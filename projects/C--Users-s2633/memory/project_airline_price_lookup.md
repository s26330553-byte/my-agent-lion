---
name: project-airline-price-lookup
description: 航司票價查詢工具 — 已上線，GitHub Pages，含密碼鎖、週末加價、代理商折扣
metadata: 
  node_type: memory
  type: project
  originSessionId: 01811a17-d1ca-4c3a-bb7c-a02304ced460
---

# 航司票價查詢工具

已完成並上線（2026-05-19）。

**Why:** RC 查價要翻 PDF + 人工算週末加價，浪費時間；這個工具讓查價變成兩步。

## 線上資訊

| 項目 | 值 |
|:--|:--|
| 線上網址 | https://s26330553-byte.github.io/airline-price-lookup |
| GitHub | https://github.com/s26330553-byte/airline-price-lookup |
| 本機路徑 | `C:\Users\s2633\Documents\airline-price-lookup\` |
| 存取密碼 | 123456（前端密碼鎖，sessionStorage 記住） |

## 目前資料範圍

- **航司**：中華航空（CI）
- **路線**：46 條，涵蓋 NRT / NGO / CTS / KIX / TAK / HIJ / FUK / KMJ / KOJ / OKA
- **資料格式**：v1.2 compact（dateRanges 模板 + p[] positional 陣列）
- **規則**：
  - 週末加價：CTS/OKA +1000，其他 +500，同時含六日才收
  - 假日免收：中秋/雙十/光復/行憲（各目的地期間略不同）
  - 盂蘭盆（8/10-8/16）：**不免收**，須加價
  - 代理商折扣：CI 一律 -500（`agentDiscount` 欄位）

## 更新方式

- 票價資料：在 GitHub 網頁直接編輯 `data/prices.json` → Commit → 約 1 分鐘生效
- 使用 `/update-prices` skill 可走完整 SOP（讀 PDF → 改 JSON → push）

## 待加入

- 長榮航空（BR）票價表（票價表到手後執行 `/update-prices`）
- 星宇航空（JX）票價表（同上）

**How to apply:** 下次說「更新票價」或「加 BR」，直接呼叫 `/update-prices`，不需重新解釋背景。

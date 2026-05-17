// ── 常數 ────────────────────────────────────────────────
const LINE_API      = 'https://api.line.me/v2/bot/message';
const NOTION_API    = 'https://api.notion.com/v1';
const NOTION_DB_ID  = '363611aa-feae-8119-a717-cf1e08267b4b';
const NOTION_VER    = '2022-06-28';
const ERIC_USER_ID  = 'U6a66d105ece115724eb6d9ebd3ebaf4a';

// ── Gemini 解析意圖 ──────────────────────────────────────
async function parseIntent(text, apiKey) {
  const today = new Date().toLocaleDateString('zh-TW', {
    timeZone: 'Asia/Taipei', year: 'numeric', month: '2-digit', day: '2-digit'
  }).replace(/\//g, '-');

  const prompt = `你是任務解析助手，今天是 ${today}。解析訊息並回傳 JSON，不要說明文字。

訊息：「${text}」

判斷規則（優先順序由上到下）：
- 訊息中任何一行含有「<<」符號 → type="批次更新"，解析出 items 陣列，每筆含 flight/date/name/status/remark。「<<」左側是任務（日期＋名稱），右側是要更新的狀態或備註：右側若為「已完成/完成/done」→ status="已完成"；「已確認/確認」→ status="已確認"；「取消」→ status="已取消"；其他文字 → status="處理中", remark=右側文字。flight 從該行所屬的航班群組標題繼承。
- 訊息含多行，且有「航班代碼獨立成一行」作為群組標題（後面跟著多個日期行）→ type="批次建立"，解析出 items 陣列，每筆含 flight/date/name
- 含「已完成/完成了/搞定/done」→ type="更新狀態", status="已完成", 同時解析 flight/date/name
- 含「已確認/確認了/confirm」→ type="更新狀態", status="已確認", 同時解析 flight/date/name
- 含「取消/不用了/cancel」→ type="更新狀態", status="已取消", 同時解析 flight/date/name
- 含「處理中」或任何括號外的附加說明（例：BR處理中、待回覆、聯繫中）→ type="更新備註", status="處理中", remark=附加說明文字, 同時解析 flight/date/name
- 查詢類（查看/有哪些/待處理/進度/今日完成/已完成清單）→ type="查詢", subtype="全部" 或 "已完成"
- 新增/更新欄位/選項 → type="更新欄位", target=欄位名, value=新選項
- 含 BR116/BR166/JX850/JX860/CI130/超賣管控（單筆）→ type="機位追蹤", flight=對應代碼
- 不含航班代碼 → type="雜事", flight="雜事"

共用規則：
- flight: 航班代碼（BR116/BR166/JX850/JX860/CI130/超賣管控），無則 null
- date 格式 YYYY-MM-DD（月份只有數字時補今年 ${today.substring(0,4)}）
- name = 任務說明（去掉日期、航班、時間、狀態詞，只留核心描述）
- remark = 備註內容（只在 type="更新備註" 時出現）

批次更新範例輸入：
更新狀態

BR116
6/17  +散位 << BR處理中
7/17  超賣兩席 << BR處理中

BR166
7/16  +散位 << 已完成
8/16  一組超賣 << BR處理中

批次更新範例輸出：
{"type":"批次更新","items":[{"flight":"BR116","date":"${today.substring(0,4)}-06-17","name":"+散位","status":"處理中","remark":"BR處理中"},{"flight":"BR116","date":"${today.substring(0,4)}-07-17","name":"超賣兩席","status":"處理中","remark":"BR處理中"},{"flight":"BR166","date":"${today.substring(0,4)}-07-16","name":"+散位","status":"已完成"},{"flight":"BR166","date":"${today.substring(0,4)}-08-16","name":"一組超賣","status":"處理中","remark":"BR處理中"}]}

批次建立範例輸入：
BR116
6/16 +散位
7/16 超賣兩席

BR166
7/15 +散位

批次建立範例輸出：
{"type":"批次建立","items":[{"flight":"BR116","date":"${today.substring(0,4)}-06-16","name":"+散位"},{"flight":"BR116","date":"${today.substring(0,4)}-07-16","name":"超賣兩席"},{"flight":"BR166","date":"${today.substring(0,4)}-07-15","name":"+散位"}]}

只回傳 JSON，不要說明文字。`;

  const resp = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }),
    }
  );

  const data = await resp.json();
  const raw = data.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || '{}';
  // 去掉 Gemini 可能回傳的 ```json ``` 包裝
  const clean = raw.replace(/^```json\s*/i, '').replace(/```\s*$/, '').trim();
  try {
    return JSON.parse(clean);
  } catch {
    return { type: '雜事', flight: '雜事', date: null, name: text };
  }
}

// ── Notion：建立任務 ─────────────────────────────────────
async function createNotionTask(intent, token) {
  const properties = {
    '名稱': { title: [{ type: 'text', text: { content: intent.name || '（未命名）' } }] },
    '航班': { select: { name: intent.flight || '雜事' } },
    '狀態': { select: { name: '待確認' } },
  };
  if (intent.date) properties['出發日期'] = { date: { start: intent.date } };

  const resp = await fetch(`${NOTION_API}/pages`, {
    method: 'POST',
    headers: notionHeaders(token),
    body: JSON.stringify({ parent: { database_id: NOTION_DB_ID }, properties }),
  });
  return resp.json();
}

// ── Notion：查詢任務 ─────────────────────────────────────
async function queryNotionTasks(token, statusFilter = null) {
  const filter = statusFilter
    ? { or: statusFilter.map(s => ({ property: '狀態', select: { equals: s } })) }
    : undefined;

  const body = {
    sorts: [{ property: '出發日期', direction: 'ascending' }],
    page_size: 30,
    ...(filter && { filter }),
  };

  const resp = await fetch(`${NOTION_API}/databases/${NOTION_DB_ID}/query`, {
    method: 'POST',
    headers: notionHeaders(token),
    body: JSON.stringify(body),
  });
  return resp.json();
}

// ── Notion：依條件找任務（回傳第一筆）────────────────────
async function findNotionTask(flight, date, name, token) {
  const filters = [];
  if (flight) filters.push({ property: '航班',    select: { equals: flight } });
  if (date)   filters.push({ property: '出發日期', date:   { equals: date  } });

  const body = {
    page_size: 10,
    sorts: [{ property: '出發日期', direction: 'ascending' }],
    ...(filters.length > 0 && { filter: filters.length === 1 ? filters[0] : { and: filters } }),
  };

  const resp = await fetch(`${NOTION_API}/databases/${NOTION_DB_ID}/query`, {
    method: 'POST',
    headers: notionHeaders(token),
    body: JSON.stringify(body),
  });
  const data = await resp.json();
  const results = data.results || [];

  // 若有多筆，優先選名稱最接近的
  if (results.length === 0) return null;
  if (results.length === 1 || !name) return results[0];
  const scored = results.map(p => {
    const pName = p.properties['名稱']?.title?.[0]?.text?.content || '';
    const score = [...name].filter(c => pName.includes(c)).length;
    return { p, score };
  });
  scored.sort((a, b) => b.score - a.score);
  return scored[0].p;
}

// ── Notion：更新任務（狀態 / 名稱備註 / 已完成群組移動）──
async function updateNotionStatus(pageId, status, token, originalFlight, originalName, remark) {
  const properties = { '狀態': { select: { name: status } } };

  if (status === '已完成') {
    // 移到已完成群組
    properties['航班'] = { select: { name: '已完成' } };
    // 名稱加上航班前綴（若還沒有的話）
    if (originalFlight && originalName && !originalName.startsWith(originalFlight)) {
      properties['名稱'] = {
        title: [{ type: 'text', text: { content: `${originalFlight} ${originalName}` } }],
      };
    }
  } else if (remark) {
    // 備註更新：把現有備註替換，或在名稱後附加 (備註)
    // 去掉舊的括號備註，再加上新的
    const baseName = (originalName || '').replace(/（[^）]*）$/, '').replace(/\([^)]*\)$/, '').trim();
    properties['名稱'] = {
      title: [{ type: 'text', text: { content: `${baseName}（${remark}）` } }],
    };
  }

  const resp = await fetch(`${NOTION_API}/pages/${pageId}`, {
    method: 'PATCH',
    headers: notionHeaders(token),
    body: JSON.stringify({ properties }),
  });
  return resp.json();
}

// ── Notion：新增欄位選項 ─────────────────────────────────
async function addNotionSelectOption(fieldName, optionName, token) {
  // 先取得目前 DB schema
  const db = await fetch(`${NOTION_API}/databases/${NOTION_DB_ID}`, {
    headers: notionHeaders(token),
  }).then(r => r.json());

  const existing = db.properties?.[fieldName]?.select?.options || [];
  if (existing.find(o => o.name === optionName)) {
    return { already_exists: true };
  }

  const updated = [...existing, { name: optionName, color: 'default' }];
  const resp = await fetch(`${NOTION_API}/databases/${NOTION_DB_ID}`, {
    method: 'PATCH',
    headers: notionHeaders(token),
    body: JSON.stringify({
      properties: {
        [fieldName]: { select: { options: updated } },
      },
    }),
  });
  return resp.json();
}

// ── LINE：回覆 ────────────────────────────────────────────
async function replyLine(replyToken, text, lineToken) {
  await fetch(`${LINE_API}/reply`, {
    method: 'POST',
    headers: lineHeaders(lineToken),
    body: JSON.stringify({ replyToken, messages: [{ type: 'text', text }] }),
  });
}

// ── LINE：主動推播 ─────────────────────────────────────────
async function pushLine(userId, text, lineToken) {
  await fetch(`${LINE_API}/push`, {
    method: 'POST',
    headers: lineHeaders(lineToken),
    body: JSON.stringify({ to: userId, messages: [{ type: 'text', text }] }),
  });
}

// ── 日期格式化：YYYY-MM-DD → M/D ─────────────────────────
function fmtDate(d) {
  if (!d || d === '—') return '—';
  const [, m, day] = d.split('-');
  return `${parseInt(m)}/${parseInt(day)}`;
}

// ── 狀態顯示設定 ──────────────────────────────────────────
const STATUS_ORDER = ['待確認', '處理中', '候補中', '已確認', '已取消', '已完成'];
const STATUS_LABEL = {
  '待確認': '🔴 待確認',
  '處理中': '🔵 處理中',
  '候補中': '🟡 候補中',
  '已確認': '🟢 已確認',
  '已取消': '⚫ 已取消',
  '已完成': '✅ 已完成',
};

// ── 格式化任務清單（依狀態分組）─────────────────────────
function formatTasks(results, showCompleted = false) {
  const pages = results.results || [];
  if (pages.length === 0) {
    return showCompleted ? '今日尚無已完成任務' : '目前沒有任務 🎉';
  }

  if (showCompleted) {
    // 只看已完成
    const done = pages.filter(p => p.properties['狀態']?.select?.name === '已完成');
    if (done.length === 0) return '今日尚無已完成任務';
    const lines = [`✅ 已完成（${done.length} 筆）`];
    for (const page of done) {
      const p      = page.properties;
      const name   = p['名稱']?.title?.[0]?.text?.content || '（無標題）';
      const flight = p['航班']?.select?.name || '';
      const date   = fmtDate(p['出發日期']?.date?.start);
      lines.push(`${flight !== '已完成' ? flight + '  ' : ''}${date}  ${name}`);
    }
    return lines.join('\n');
  }

  // 依狀態 → 依航班 雙層分組
  // byStatus[status][flight] = [line, ...]
  const byStatus = {};
  for (const page of pages) {
    const p      = page.properties;
    const name   = p['名稱']?.title?.[0]?.text?.content || '（無標題）';
    const flight = p['航班']?.select?.name || '—';
    const date   = fmtDate(p['出發日期']?.date?.start);
    const status = p['狀態']?.select?.name || '待確認';
    const line   = `${date !== '—' ? date + '  ' : ''}${name}`;

    if (!byStatus[status]) byStatus[status] = {};
    if (!byStatus[status][flight]) byStatus[status][flight] = [];
    byStatus[status][flight].push(line);
  }

  const total = pages.length;
  const lines = [`📋 共 ${total} 筆任務`];

  for (const status of STATUS_ORDER) {
    const flightGroups = byStatus[status];
    if (!flightGroups) continue;

    const count = Object.values(flightGroups).flat().length;
    lines.push('');
    lines.push(`${STATUS_LABEL[status]}（${count}）`);

    for (const [flight, entries] of Object.entries(flightGroups)) {
      // 已完成/雜事 不再重複顯示群組標題（航班資訊已在名稱裡）
      if (flight !== '已完成' && flight !== '雜事') {
        lines.push('');
        lines.push(flight);
      }
      entries.forEach(e => lines.push(e));
    }
  }

  return lines.join('\n');
}

// ── 排程推播邏輯 ─────────────────────────────────────────
async function handleScheduled(env, cronExpr) {
  const isEvening = cronExpr.startsWith('0 9'); // 09:00 UTC = 17:00 台灣
  const result = await queryNotionTasks(cleanSecret(env.NOTION_TOKEN), ['待確認', '候補中']);
  const today  = new Date().toLocaleDateString('zh-TW', {
    timeZone: 'Asia/Taipei', month: 'numeric', day: 'numeric', weekday: 'short',
  });

  let msg;
  if (!isEvening) {
    msg = `☀️ 早安，Eric！\n今日（${today}）待辦摘要：\n\n` + formatTasks(result);
  } else {
    msg = `🌆 今日進度摘要（${today}）\n\n` + formatTasks(result);
  }

  await pushLine(ERIC_USER_ID, msg, cleanSecret(env.LINE_CHANNEL_ACCESS_TOKEN));
}

// ── 共用 Headers ─────────────────────────────────────────
function notionHeaders(token) {
  return {
    'Authorization': `Bearer ${token}`,
    'Notion-Version': NOTION_VER,
    'Content-Type': 'application/json',
  };
}
function lineHeaders(token) {
  return {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
  };
}

// ── 清除 BOM 與空白（所有 secret 統一處理）────────────────
function cleanSecret(s) {
  return (s || '').replace(/^﻿/, '').trim();
}
function checkSecret(input, envSecret) {
  return input === cleanSecret(envSecret);
}

// ── 處理單一 LINE 訊息事件（背景執行）────────────────────
async function processLineEvent(event, env) {
  const userId     = event.source?.userId;
  const replyToken = event.replyToken;
  if (!userId) return;

  // 記錄 userId
  const now      = new Date().toISOString();
  const existing = await env.LINE_USERS.get(userId, { type: 'json' });
  await env.LINE_USERS.put(userId, JSON.stringify({
    userId,
    firstSeen: existing?.firstSeen || now,
    lastSeen: now,
    lastEventType: event.type,
  }));

  // 只處理文字訊息
  if (event.type !== 'message' || event.message?.type !== 'text') return;
  const text = event.message.text.trim();

  try {
    const intent = await parseIntent(text, cleanSecret(env.GEMINI_API_KEY));

    // ── 批次更新 ──
    if (intent.type === '批次更新' && Array.isArray(intent.items) && intent.items.length > 0) {
      const notionToken = cleanSecret(env.NOTION_TOKEN);
      const lineToken   = cleanSecret(env.LINE_CHANNEL_ACCESS_TOKEN);

      // 逐筆尋找並更新（平行執行）
      const results = await Promise.allSettled(
        intent.items.map(async item => {
          const task = await findNotionTask(item.flight, item.date, item.name, notionToken);
          if (!task) return { ok: false, item };
          const origFlight = task.properties['航班']?.select?.name || '';
          const origName   = task.properties['名稱']?.title?.[0]?.text?.content || '';
          await updateNotionStatus(task.id, item.status, notionToken, origFlight, origName, item.remark);
          return { ok: true, item };
        })
      );

      const updated  = results.filter(r => r.status === 'fulfilled' && r.value?.ok).map(r => r.value.item);
      const notFound = results.filter(r => r.status === 'fulfilled' && !r.value?.ok).map(r => r.value.item);

      // 依航班分組回覆
      const grouped = {};
      for (const item of updated) {
        if (!grouped[item.flight]) grouped[item.flight] = [];
        const statusTag = { '已完成':'✅', '已確認':'🟢', '已取消':'⚫', '處理中':'🔵' }[item.status] || '🔴';
        const remarkStr = item.remark ? `（${item.remark}）` : '';
        grouped[item.flight].push(`${fmtDate(item.date)}  ${item.name}${remarkStr} ${statusTag}`);
      }

      const lines = [`✅ 已更新 ${updated.length} 筆`];
      for (const [flight, entries] of Object.entries(grouped)) {
        lines.push('');
        lines.push(flight);
        lines.push(...entries);
      }

      if (notFound.length > 0) {
        lines.push('');
        lines.push(`⚠️ 找不到（${notFound.length} 筆）`);
        notFound.forEach(item => lines.push(`${item.flight} ${fmtDate(item.date)} ${item.name}`));
      }

      await replyLine(replyToken, lines.join('\n'), lineToken);
      return;
    }

    // ── 批次建立 ──
    if (intent.type === '批次建立' && Array.isArray(intent.items) && intent.items.length > 0) {
      const notionToken = cleanSecret(env.NOTION_TOKEN);
      const lineToken   = cleanSecret(env.LINE_CHANNEL_ACCESS_TOKEN);

      // 全部平行寫入 Notion
      const results = await Promise.allSettled(
        intent.items.map(item => createNotionTask(item, notionToken))
      );

      const success = results.filter(r => r.status === 'fulfilled' && r.value?.object === 'page');
      const failed  = results.length - success.length;

      // 依航班分組整理回覆
      const grouped = {};
      for (const item of intent.items) {
        if (!grouped[item.flight]) grouped[item.flight] = [];
        grouped[item.flight].push(`${fmtDate(item.date)}  ${item.name}`);
      }

      const lines = [`✅ 已建立 ${success.length} 筆${failed > 0 ? `（${failed} 筆失敗）` : ''}`];
      for (const [flight, entries] of Object.entries(grouped)) {
        lines.push('');
        lines.push(flight);
        lines.push(...entries);
      }
      lines.push(`\n已寫入 Notion 👌`);

      await replyLine(replyToken, lines.join('\n'), lineToken);
      return;
    }

    // ── 查詢 ──
    if (intent.type === '查詢') {
      const isCompletedQuery = intent.subtype === '已完成';
      // 查所有任務（不過濾狀態），formatTasks 內部依狀態分組
      const result = await queryNotionTasks(cleanSecret(env.NOTION_TOKEN), null);
      await replyLine(replyToken, formatTasks(result, isCompletedQuery), cleanSecret(env.LINE_CHANNEL_ACCESS_TOKEN));
      return;
    }

    // ── 更新狀態 / 更新備註（共用同一段邏輯）──
    if (intent.type === '更新狀態' || intent.type === '更新備註') {
      const notionToken = cleanSecret(env.NOTION_TOKEN);
      const lineToken   = cleanSecret(env.LINE_CHANNEL_ACCESS_TOKEN);
      const task = await findNotionTask(intent.flight, intent.date, intent.name, notionToken);

      if (!task) {
        await replyLine(replyToken,
          `⚠️ 找不到符合的任務\n航班：${intent.flight || '—'}\n日期：${intent.date || '—'}\n名稱：${intent.name || '—'}\n\n請確認後再試，或直接到 Notion 手動更新。`,
          lineToken);
        return;
      }

      const taskName   = task.properties['名稱']?.title?.[0]?.text?.content || '（無標題）';
      const taskFlight = task.properties['航班']?.select?.name || '—';
      await updateNotionStatus(task.id, intent.status, notionToken, taskFlight, taskName, intent.remark);
      const taskDate    = task.properties['出發日期']?.date?.start || '—';
      const statusEmoji = { '已完成':'✅', '已確認':'🟢', '已取消':'⚫', '處理中':'🔵' }[intent.status] || '🔴';
      const newName     = intent.remark
        ? `${taskName.replace(/（[^）]*）$/, '').replace(/\([^)]*\)$/, '').trim()}（${intent.remark}）`
        : taskName;

      const lines = [
        `${statusEmoji} 任務已更新`,
        ``,
        `✈️ ${taskFlight}　${taskDate}`,
        `📝 ${newName}`,
        `→ ${intent.status}`,
      ];
      await replyLine(replyToken, lines.join('\n'), lineToken);
      return;
    }

    // ── 更新欄位 ──
    if (intent.type === '更新欄位') {
      const field  = intent.target || '航班';
      const option = intent.value;
      if (!option) {
        await replyLine(replyToken, '⚠️ 無法辨識要新增的選項名稱，請再說一次。', cleanSecret(env.LINE_CHANNEL_ACCESS_TOKEN));
        return;
      }
      const r = await addNotionSelectOption(field, option, cleanSecret(env.NOTION_TOKEN));
      const msg = r.already_exists
        ? `ℹ️「${option}」已存在於「${field}」欄位，不需重複新增。`
        : `⚙️ 已更新 Notion 欄位\n\n「${field}」新增選項：${option} ✅`;
      await replyLine(replyToken, msg, cleanSecret(env.LINE_CHANNEL_ACCESS_TOKEN));
      return;
    }

    // ── 建立任務（機位追蹤 / 雜事）──
    await createNotionTask(intent, cleanSecret(env.NOTION_TOKEN));

    const typeLabel = intent.type === '機位追蹤' ? '✈️ 機位追蹤' : '📝 雜事';
    const reply = [
      `✅ 已建立${typeLabel}任務`,
      ``,
      intent.flight !== '雜事' ? `✈️ 航班：${intent.flight}` : null,
      intent.date   ? `📅 日期：${intent.date}` : null,
      `📝 名稱：${intent.name}`,
      `🔴 狀態：待確認`,
      ``,
      `已寫入 Notion 北海道機位控管 👌`,
    ].filter(l => l !== null).join('\n');

    await replyLine(replyToken, reply, cleanSecret(env.LINE_CHANNEL_ACCESS_TOKEN));

  } catch (err) {
    await replyLine(replyToken, `⚠️ 處理時發生錯誤：${err.message}`, cleanSecret(env.LINE_CHANNEL_ACCESS_TOKEN));
  }
}

// ── Worker 主程式 ─────────────────────────────────────────
export default {
  // ── Webhook（LINE 傳訊觸發）─────────────────────────────
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // LINE Webhook：立刻回 200，背景處理（避免 3 秒 timeout）
    if (url.pathname === '/webhook' && request.method === 'POST') {
      const body = await request.json();

      // 用 waitUntil 讓 Cloudflare 在回應後繼續執行
      ctx.waitUntil(
        Promise.all((body.events || []).map(event => processLineEvent(event, env)))
      );

      return new Response('OK', { status: 200 });
    }

    // ── 手動觸發排程（測試用）──
    if (url.pathname === '/push-test' && request.method === 'GET') {
      const secret = url.searchParams.get('secret');
      if (!checkSecret(secret, env.ADMIN_SECRET)) return new Response('Unauthorized', { status: 401 });
      const type = url.searchParams.get('type') || 'morning';
      await handleScheduled(env, type === 'evening' ? '0 9 * * 1-5' : '50 0 * * 1-5');
      return new Response('Pushed!', { status: 200 });
    }

    // ── 查詢 userId 清單 ──
    if (url.pathname === '/users' && request.method === 'GET') {
      const secret = url.searchParams.get('secret');
      if (!checkSecret(secret, env.ADMIN_SECRET)) return new Response('Unauthorized', { status: 401 });
      const list = await env.LINE_USERS.list();
      const users = [];
      for (const key of list.keys) {
        if (key.name.startsWith('__')) continue;
        const val = await env.LINE_USERS.get(key.name, { type: 'json' });
        if (val) users.push(val);
      }
      return new Response(JSON.stringify(users, null, 2), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 臨時：模擬訊息處理，逐步回報每個步驟
    if (url.pathname === '/debug-msg' && request.method === 'GET') {
      if (!checkSecret(url.searchParams.get('secret'), env.ADMIN_SECRET)) {
        return new Response('Unauthorized', { status: 401 });
      }
      const text = url.searchParams.get('msg') || '8/16 BR116 缺兩席機位';
      const log = [];
      try {
        log.push(`[1] 收到訊息: ${text}`);
        const intent = await parseIntent(text, cleanSecret(env.GEMINI_API_KEY));
        log.push(`[2] Gemini 解析: ${JSON.stringify(intent)}`);
        const result = await createNotionTask(intent, cleanSecret(env.NOTION_TOKEN));
        log.push(`[3] Notion 建立: status=${result.object} id=${result.id} err=${result.message || 'none'}`);
      } catch (err) {
        log.push(`[ERROR] ${err.message}\n${err.stack}`);
      }
      return new Response(log.join('\n'), { status: 200 });
    }

    // 臨時：逐步測試各元件
    if (url.pathname === '/debug-push' && request.method === 'GET') {
      if (!checkSecret(url.searchParams.get('secret'), env.ADMIN_SECRET)) {
        return new Response('Unauthorized', { status: 401 });
      }
      const lineToken = cleanSecret(env.LINE_CHANNEL_ACCESS_TOKEN);
      const notionToken = cleanSecret(env.NOTION_TOKEN);

      // 1. 測試 LINE push
      const lineResp = await fetch(`${LINE_API}/push`, {
        method: 'POST',
        headers: lineHeaders(lineToken),
        body: JSON.stringify({
          to: ERIC_USER_ID,
          messages: [{ type: 'text', text: '🔧 Worker debug：LINE token 正常' }],
        }),
      });
      const lineStatus = lineResp.status;
      const lineBody   = await lineResp.text();

      // 2. 測試 Notion query
      const notionResp = await fetch(`${NOTION_API}/databases/${NOTION_DB_ID}/query`, {
        method: 'POST',
        headers: notionHeaders(notionToken),
        body: JSON.stringify({ page_size: 1 }),
      });
      const notionStatus = notionResp.status;
      const notionBody   = await notionResp.text();

      return new Response(JSON.stringify({
        lineToken_prefix: lineToken.substring(0, 8),
        lineToken_len: lineToken.length,
        line: { status: lineStatus, body: lineBody.substring(0, 200) },
        notionToken_prefix: notionToken.substring(0, 10),
        notion: { status: notionStatus, body: notionBody.substring(0, 200) },
      }, null, 2), { headers: { 'Content-Type': 'application/json' } });
    }

    return new Response('LINE Webhook OK', { status: 200 });
  },

  // ── Cron Trigger（排程推播）──────────────────────────────
  async scheduled(event, env) {
    await handleScheduled(env, event.cron);
  },
};

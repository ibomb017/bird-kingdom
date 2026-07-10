const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const app = express();
app.use(cors());
app.use(express.json());

const pool = mysql.createPool({
  host: '127.0.0.1', port: 3306,
  user: 'root', password: 'Chen_20040601',
  database: 'bird_kingdom',
  waitForConnections: true, connectionLimit: 5
});

// Helper: snake_case -> camelCase conversion (matches Swift backend DTO conventions)
function toCamel(str) {
  return str.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
}
function camelizeObj(obj) {
  if (Array.isArray(obj)) return obj.map(camelizeObj);
  if (obj && typeof obj === 'object' && !(obj instanceof Date)) {
    const out = {};
    for (const [k, v] of Object.entries(obj)) {
      out[toCamel(k)] = v;
    }
    return out;
  }
  return obj;
}
function camelizeRows(rows) {
  return rows.map(camelizeObj);
}

// Helper: paginated query
async function paginated(table, req, extraWhere, extraParams, orderCol) {
  const page = parseInt(req.query.page) || 0;
  const size = parseInt(req.query.size) || 20;
  const offset = page * size;
  const where = extraWhere ? 'WHERE ' + extraWhere : '';
  const order = orderCol || 'id';
  const params = extraParams || [];
  const [rows] = await pool.query(
    `SELECT * FROM ${table} ${where} ORDER BY ${order} DESC LIMIT ? OFFSET ?`,
    [...params, size, offset]
  );
  const [[{total}]] = await pool.query(
    `SELECT COUNT(*) as total FROM ${table} ${where}`,
    params
  );
  return { content: camelizeRows(rows), totalElements: total };
}

// Helper: wrap response in standard {code:0, data:...} format
function ok(res, data) {
  res.json({ code: 0, message: 'success', data });
}

// =============== 用户管理 ===============

// GET /users - 用户列表（分页+搜索）
app.get('/users', async (req, res) => {
  try {
    const keyword = req.query.keyword || '';
    const vipStatus = req.query.vipStatus || '';
    let conditions = [];
    let params = [];
    if (keyword) {
      conditions.push('(nickname LIKE ? OR phone LIKE ?)');
      params.push(`%${keyword}%`, `%${keyword}%`);
    }
    if (vipStatus === 'VIP') {
      conditions.push('vip_type IS NOT NULL AND vip_expire_date > NOW()');
    }
    if (vipStatus === 'NORMAL') {
      conditions.push('(vip_type IS NULL OR vip_expire_date <= NOW())');
    }
    const where = conditions.length > 0 ? conditions.join(' AND ') : null;
    const data = await paginated('users', req, where, params);
    ok(res, data);
  } catch(e) { console.error(e); res.status(500).json({error: true, reason: e.message}); }
});

// GET /users/vip - VIP用户列表（必须放在 /users/:id 前面）
app.get('/users/vip', async (req, res) => {
  try {
    const data = await paginated('users', req, 'vip_type IS NOT NULL AND vip_expire_date > NOW()', []);
    ok(res, data);
  } catch(e) { console.error(e); res.status(500).json({error: true, reason: e.message}); }
});

// GET /users/couples - 情侣用户
app.get('/users/couples', async (req, res) => {
  try {
    const data = await paginated('users', req, "vip_type = 'COUPLE'", []);
    ok(res, data);
  } catch(e) { console.error(e); res.status(500).json({error: true, reason: e.message}); }
});

// POST /users/:id/extend-vip
app.post('/users/:id/extend-vip', async (req, res) => {
  try {
    const days = parseInt(req.body.days) || 30;
    await pool.query(
      'UPDATE users SET vip_expire_date = DATE_ADD(COALESCE(vip_expire_date, NOW()), INTERVAL ? DAY) WHERE id = ?',
      [days, req.params.id]
    );
    res.json({code: 0, message: 'success'});
  } catch(e) { res.status(500).json({error: true, reason: e.message}); }
});

// POST /users/:id/revoke-vip
app.post('/users/:id/revoke-vip', async (req, res) => {
  try {
    await pool.query('UPDATE users SET vip_type = NULL, vip_expire_date = NULL WHERE id = ?', [req.params.id]);
    res.json({code: 0, message: 'success'});
  } catch(e) { res.status(500).json({error: true, reason: e.message}); }
});

// POST /users/restore-couple-vip
app.post('/users/restore-couple-vip', async (req, res) => {
  try {
    const { userId } = req.body;
    await pool.query("UPDATE users SET vip_type = 'COUPLE' WHERE id = ?", [userId]);
    res.json({code: 0, message: 'success'});
  } catch(e) { res.status(500).json({error: true, reason: e.message}); }
});

// POST /users/cancel-couple-vip
app.post('/users/cancel-couple-vip', async (req, res) => {
  try {
    const { userId } = req.body;
    await pool.query("UPDATE users SET vip_type = NULL WHERE id = ?", [userId]);
    res.json({code: 0, message: 'success'});
  } catch(e) { res.status(500).json({error: true, reason: e.message}); }
});

// GET /users/:id - 用户详情
app.get('/users/:id', async (req, res) => {
  try {
    const [[user]] = await pool.query('SELECT * FROM users WHERE id = ?', [req.params.id]);
    if (!user) return res.status(404).json({error: true, reason: 'User not found'});
    const [[{birdCount}]] = await pool.query('SELECT COUNT(*) as birdCount FROM birds WHERE user_id = ?', [req.params.id]);
    const [[{postCount}]] = await pool.query('SELECT COUNT(*) as postCount FROM forum_posts WHERE user_id = ?', [req.params.id]);
    const [[{logCount}]] = await pool.query('SELECT COUNT(*) as logCount FROM bird_logs WHERE user_id = ?', [req.params.id]);
    user.birdCount = birdCount;
    user.postCount = postCount;
    user.logCount = logCount;
    ok(res, camelizeObj(user));
  } catch(e) { console.error(e); res.status(500).json({error: true, reason: e.message}); }
});

// =============== 百科模块 ===============

// GET /encyclopedia/species - 品种知识库（从 bird_encyclopedia 表）
app.get('/encyclopedia/species', async (req, res) => {
  try {
    const keyword = req.query.keyword || '';
    const category = req.query.category || '';
    let where = null;
    let params = [];
    let conditions = [];
    if (keyword) { conditions.push('(name LIKE ? OR description LIKE ?)'); params.push(`%${keyword}%`, `%${keyword}%`); }
    if (category) { conditions.push('category = ?'); params.push(category); }
    if (conditions.length) where = conditions.join(' AND ');
    const data = await paginated('bird_encyclopedia', req, where, params);
    ok(res, data);
  } catch(e) { console.error(e); res.status(500).json({error: true, reason: e.message}); }
});

// GET /encyclopedia/foods - 食物安全库
app.get('/encyclopedia/foods', async (req, res) => {
  try {
    const keyword = req.query.keyword || '';
    let where = null;
    let params = [];
    if (keyword) { where = '(food_name LIKE ? OR category LIKE ?)'; params = [`%${keyword}%`, `%${keyword}%`]; }
    const data = await paginated('bird_foods', req, where, params);
    ok(res, data);
  } catch(e) { console.error(e); res.status(500).json({error: true, reason: e.message}); }
});

// GET /encyclopedia/symptoms - 症状速查
app.get('/encyclopedia/symptoms', async (req, res) => {
  try {
    const keyword = req.query.keyword || '';
    let where = null;
    let params = [];
    if (keyword) { where = '(name LIKE ? OR description LIKE ?)'; params = [`%${keyword}%`, `%${keyword}%`]; }
    const data = await paginated('symptoms', req, where, params);
    ok(res, data);
  } catch(e) { console.error(e); res.status(500).json({error: true, reason: e.message}); }
});

// GET /encyclopedia/parrots - 鹦鹉品种库
app.get('/encyclopedia/parrots', async (req, res) => {
  try {
    const keyword = req.query.keyword || '';
    const category = req.query.category || '';
    let where = null;
    let params = [];
    let conditions = [];
    if (keyword) { conditions.push('(name LIKE ?)'); params.push(`%${keyword}%`); }
    if (category) { conditions.push('category = ?'); params.push(category); }
    if (conditions.length) where = conditions.join(' AND ');
    const data = await paginated('parrot_species', req, where, params);
    ok(res, data);
  } catch(e) { console.error(e); res.status(500).json({error: true, reason: e.message}); }
});

// GET /encyclopedia/parrots/categories - 鹦鹉分类
app.get('/encyclopedia/parrots/categories', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT category, COUNT(*) as count FROM parrot_species GROUP BY category ORDER BY count DESC');
    ok(res, camelizeRows(rows));
  } catch(e) { console.error(e); res.status(500).json({error: true, reason: e.message}); }
});

// =============== 饲养日志 ===============
app.get('/bird-logs', async (req, res) => {
  try {
    const data = await paginated('bird_logs', req);
    ok(res, data);
  } catch(e) { console.error(e); res.status(500).json({error: true, reason: e.message}); }
});

// =============== 论坛管理 ===============
app.get('/forum/posts', async (req, res) => {
  try {
    const keyword = req.query.keyword || '';
    const postType = req.query.postType || '';
    let conditions = [];
    let params = [];
    if (keyword) {
      conditions.push('(content LIKE ? OR bird_name LIKE ? OR bird_species LIKE ?)');
      params.push(`%${keyword}%`, `%${keyword}%`, `%${keyword}%`);
    }
    if (postType) {
      conditions.push('post_type = ?');
      params.push(postType);
    }
    const where = conditions.length > 0 ? conditions.join(' AND ') : null;
    
    const page = parseInt(req.query.page) || 0;
    const size = parseInt(req.query.size) || 20;
    const offset = page * size;
    const [rows] = await pool.query(
      `SELECT p.*, u.nickname as authorNickname, u.avatar_url as authorAvatarUrl 
       FROM forum_posts p LEFT JOIN users u ON p.user_id = u.id 
       ${where ? 'WHERE ' + where : ''} ORDER BY p.id DESC LIMIT ? OFFSET ?`,
      [...params, size, offset]
    );
    const [[{total}]] = await pool.query(`SELECT COUNT(*) as total FROM forum_posts ${where ? 'WHERE ' + where : ''}`, params);
    ok(res, { content: camelizeRows(rows), totalElements: total });
  } catch(e) { console.error(e); res.status(500).json({error: true, reason: e.message}); }
});

app.get('/forum/posts/:id', async (req, res) => {
  try {
    const [[post]] = await pool.query(
      `SELECT p.*, u.nickname as authorNickname, u.avatar_url as authorAvatarUrl 
       FROM forum_posts p LEFT JOIN users u ON p.user_id = u.id WHERE p.id = ?`,
      [req.params.id]
    );
    if (!post) {
      return res.status(404).json({error: true, reason: 'Post not found'});
    }
    if (post.media_urls) {
      try { post.media_urls = JSON.parse(post.media_urls); } catch(e) { post.media_urls = []; }
    } else {
      post.media_urls = [];
    }
    ok(res, camelizeObj(post));
  } catch(e) { console.error(e); res.status(500).json({error: true, reason: e.message}); }
});

app.delete('/forum/posts/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM post_comments WHERE post_id = ?', [req.params.id]);
    await pool.query('DELETE FROM forum_posts WHERE id = ?', [req.params.id]);
    res.json({code: 0, message: 'success'});
  } catch(e) { res.status(500).json({error: true, reason: e.message}); }
});

// =============== 论坛评论（独立列表） ===============
app.get('/forum/comments', async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 0;
    const size = parseInt(req.query.size) || 20;
    const offset = page * size;
    const [rows] = await pool.query(
      `SELECT c.*, u.nickname as userNickname, u.avatar_url as userAvatarUrl 
       FROM post_comments c LEFT JOIN users u ON c.user_id = u.id 
       ORDER BY c.id DESC LIMIT ? OFFSET ?`,
      [size, offset]
    );
    const [[{total}]] = await pool.query('SELECT COUNT(*) as total FROM post_comments');
    ok(res, { content: camelizeRows(rows), totalElements: total });
  } catch(e) { console.error(e); res.status(500).json({error: true, reason: e.message}); }
});

// =============== 举报管理 ===============
app.get('/forum/reports', async (req, res) => {
  try {
    const status = req.query.status || '';
    let where = '1=1';
    let params = [];
    if (status) { where += ' AND r.status = ?'; params.push(status); }
    const page = parseInt(req.query.page) || 0;
    const size = parseInt(req.query.size) || 20;
    const offset = page * size;
    const [rows] = await pool.query(
      `SELECT r.*, u.nickname as reporterNickname, u.avatar_url as reporterAvatarUrl 
       FROM post_reports r LEFT JOIN users u ON r.reporter_id = u.id 
       WHERE ${where} ORDER BY r.id DESC LIMIT ? OFFSET ?`,
      [...params, size, offset]
    );
    const [[{total}]] = await pool.query(
      `SELECT COUNT(*) as total FROM post_reports r WHERE ${where}`,
      params
    );
    rows.forEach(r => {
      r.targetType = 'POST';
      r.targetId = r.post_id;
    });
    ok(res, { content: camelizeRows(rows), totalElements: total });
  } catch(e) { console.error(e); res.status(500).json({error: true, reason: e.message}); }
});

// POST /forum/reports/:id/resolve
app.post('/forum/reports/:id/resolve', async (req, res) => {
  try {
    const action = req.body.action;
    const status = action === 'APPROVE' ? 'APPROVED' : 'REJECTED';
    await pool.query('UPDATE post_reports SET status = ?, reviewed_at = NOW() WHERE id = ?', [status, req.params.id]);
    res.json({code: 0, message: 'success'});
  } catch(e) { res.status(500).json({error: true, reason: e.message}); }
});

// =============== 财务模块 ===============

// GET /finance/reports
app.get('/finance/reports', async (req, res) => {
  try {
    const [[{splashRevenue}]] = await pool.query(
      "SELECT COALESCE(SUM(amount), 0) as splashRevenue FROM splash_order WHERE status = 'COMPLETED'"
    );
    const [[{vipUsers}]] = await pool.query(
      "SELECT COUNT(*) as vipUsers FROM users WHERE vip_type IS NOT NULL AND vip_expire_date > NOW()"
    );
    const [[{userExpenses}]] = await pool.query(
      "SELECT COALESCE(SUM(amount), 0) as userExpenses FROM expenses"
    );
    const estimatedVipRevenue = vipUsers * 25;
    ok(res, { splashRevenue: Number(splashRevenue), estimatedVipRevenue, vipUsers, userExpenses: Number(userExpenses) });
  } catch(e) { console.error(e); res.status(500).json({error: true, reason: e.message}); }
});

// GET /finance/vip-income
app.get('/finance/vip-income', async (req, res) => {
  try {
    const [[{monthlyCount}]] = await pool.query(
      "SELECT COUNT(*) as monthlyCount FROM users WHERE vip_type = 'MONTHLY' AND vip_expire_date > NOW()"
    );
    const [[{yearlyCount}]] = await pool.query(
      "SELECT COUNT(*) as yearlyCount FROM users WHERE vip_type = 'YEARLY' AND vip_expire_date > NOW()"
    );
    const [[{coupleCount}]] = await pool.query(
      "SELECT COUNT(*) as coupleCount FROM users WHERE vip_type = 'COUPLE' AND vip_expire_date > NOW()"
    );
    ok(res, { 
      monthly: { count: monthlyCount, revenue: monthlyCount * 12 },
      yearly: { count: yearlyCount, revenue: yearlyCount * 98 },
      couple: { count: coupleCount, revenue: coupleCount * 168 },
      totalRevenue: monthlyCount * 12 + yearlyCount * 98 + coupleCount * 168
    });
  } catch(e) { console.error(e); res.status(500).json({error: true, reason: e.message}); }
});

// GET /finance/expenses
app.get('/finance/expenses', async (req, res) => {
  try {
    const data = await paginated('expenses', req);
    ok(res, data);
  } catch(e) { console.error(e); res.status(500).json({error: true, reason: e.message}); }
});

// GET /finance/splash-orders
app.get('/finance/splash-orders', async (req, res) => {
  try {
    const data = await paginated('splash_order', req);
    ok(res, data);
  } catch(e) { console.error(e); res.status(500).json({error: true, reason: e.message}); }
});

const PORT = 3001;
app.listen(PORT, '127.0.0.1', () => {
  console.log(`[BirdKingdom Admin API] Running on port ${PORT}`);
});

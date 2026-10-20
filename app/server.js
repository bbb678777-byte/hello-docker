'use strict';

// 只使用 Node.js 自带模块，不需要 npm install
const http = require('http');
const os = require('os');
const path = require('path');

// 版本号统一从 package.json 读取，发版时只改这一个地方
const pkg = require(path.join(__dirname, 'package.json'));
const VERSION = pkg.version;

const PORT = Number(process.env.PORT) || 3000;
const HOSTNAME = os.hostname(); // 在 Docker 里就是容器 ID 的前 12 位
const STARTED_AT = new Date();

let visits = 0;

// 把时间格式化成北京时间，不依赖服务器/容器的时区设置
function toBeijingTime(date) {
  return date.toLocaleString('zh-CN', {
    timeZone: 'Asia/Shanghai',
    hour12: false,
  });
}

function sendJson(res, status, data) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(data, null, 2));
}

function renderHome() {
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Hello Docker v${VERSION}</title>
  <style>
    body { font-family: -apple-system, "Microsoft YaHei", sans-serif; background: #f4f6fa; margin: 0; }
    .card { max-width: 520px; margin: 60px auto; background: #fff; border-radius: 12px;
            padding: 28px 32px; box-shadow: 0 4px 20px rgba(0,0,0,.08); }
    h1 { margin-top: 0; color: #1d63ed; }
    table { width: 100%; border-collapse: collapse; }
    td { padding: 10px 4px; border-bottom: 1px solid #eee; }
    td:first-child { color: #666; width: 40%; }
    .ver { font-weight: bold; color: #e8590c; }
    footer { margin-top: 18px; font-size: 13px; color: #999; }
    a { color: #1d63ed; }
  </style>
</head>
<body>
  <div class="card">
    <h1>🐳 Hello Docker</h1>
    <table>
      <tr><td>当前版本</td><td class="ver">v${VERSION}</td></tr>
      <tr><td>容器主机名</td><td>${HOSTNAME}</td></tr>
      <tr><td>启动时间（北京）</td><td>${toBeijingTime(STARTED_AT)}</td></tr>
      <tr><td>访问次数</td><td>${visits}</td></tr>
    </table>
    <footer>接口：<a href="/health">/health</a> · <a href="/api/info">/api/info</a></footer>
  </div>
</body>
</html>`;
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');

  if (url.pathname === '/health') {
    return sendJson(res, 200, { status: 'ok', version: VERSION });
  }

  if (url.pathname === '/api/info') {
    return sendJson(res, 200, {
      name: pkg.name,
      version: VERSION,
      hostname: HOSTNAME,
      node: process.version,
      startedAt: toBeijingTime(STARTED_AT),
      uptimeSeconds: Math.round(process.uptime()),
      visits,
    });
  }

  if (url.pathname === '/') {
    visits += 1;
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    return res.end(renderHome());
  }

  sendJson(res, 404, { error: 'Not Found', path: url.pathname });
});

server.listen(PORT, () => {
  console.log(`[hello-docker] v${VERSION} 已启动：http://localhost:${PORT}  主机名=${HOSTNAME}`);
});

// 优雅退出：docker stop 会先发 SIGTERM，等待 10 秒后才强制 SIGKILL
function shutdown(signal) {
  console.log(`[hello-docker] 收到 ${signal}，停止接收新请求，正在退出...`);
  server.close(() => {
    console.log('[hello-docker] 已安全退出');
    process.exit(0);
  });
  // 兜底：5 秒内没关完就强制退出
  setTimeout(() => process.exit(1), 5000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT')); // 本地 Ctrl+C

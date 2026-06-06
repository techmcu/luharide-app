const https = require('https');
const logger = require('../config/logger');

const RATE_LIMIT_MS = 5000;
let lastSentAt = 0;

function sendTelegramAlert(text) {
  const botToken = process.env.TELEGRAM_BOT_TOKEN;
  const chatId = process.env.TELEGRAM_CHAT_ID;
  if (!botToken || !chatId) return;

  const now = Date.now();
  if (now - lastSentAt < RATE_LIMIT_MS) return;
  lastSentAt = now;

  const payload = JSON.stringify({
    chat_id: chatId,
    text: text.slice(0, 4000),
    parse_mode: 'HTML',
  });

  const req = https.request(
    {
      hostname: 'api.telegram.org',
      path: `/bot${botToken}/sendMessage`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
      },
      timeout: 5000,
    },
    (res) => res.resume()
  );

  req.on('error', (err) => {
    logger.warn({ msg: 'Telegram alert failed', error: err.message });
  });

  req.write(payload);
  req.end();
}

function formatErrorAlert(statusCode, message, url, method, stack, extra = {}) {
  const svc = process.env.LUHA_SERVICE_NAME || 'luharide-api';
  const env = process.env.NODE_ENV || 'development';
  const lines = [
    `<b>🚨 ${svc} Error</b>`,
    `<b>Env:</b> ${env}`,
    `<b>Status:</b> ${statusCode}`,
    `<b>Route:</b> ${method} ${url}`,
    `<b>Message:</b> ${message}`,
  ];
  if (extra.userId) lines.push(`<b>User:</b> ${extra.userId}`);
  if (extra.ip) lines.push(`<b>IP:</b> ${extra.ip}`);
  if (stack) {
    const short = stack.split('\n').slice(0, 4).join('\n');
    lines.push(`<pre>${short}</pre>`);
  }
  return lines.join('\n');
}

function formatInfraAlert(component, message, details) {
  const svc = process.env.LUHA_SERVICE_NAME || 'luharide-api';
  const env = process.env.NODE_ENV || 'development';
  const lines = [
    `<b>🔴 ${svc} Infra</b>`,
    `<b>Env:</b> ${env}`,
    `<b>Component:</b> ${component}`,
    `<b>Message:</b> ${message}`,
  ];
  if (details) lines.push(`<pre>${String(details).slice(0, 500)}</pre>`);
  return lines.join('\n');
}

function formatJobAlert(jobName, message, details) {
  const svc = process.env.LUHA_SERVICE_NAME || 'luharide-api';
  const env = process.env.NODE_ENV || 'development';
  const lines = [
    `<b>⚙️ ${svc} Job Failed</b>`,
    `<b>Env:</b> ${env}`,
    `<b>Job:</b> ${jobName}`,
    `<b>Error:</b> ${message}`,
  ];
  if (details) lines.push(`<pre>${String(details).slice(0, 500)}</pre>`);
  return lines.join('\n');
}

function formatCrashAlert(type, error) {
  const svc = process.env.LUHA_SERVICE_NAME || 'luharide-api';
  const env = process.env.NODE_ENV || 'development';
  const msg = error instanceof Error ? error.message : String(error);
  const stack = error instanceof Error ? error.stack : '';
  const lines = [
    `<b>💀 ${svc} CRASH</b>`,
    `<b>Env:</b> ${env}`,
    `<b>Type:</b> ${type}`,
    `<b>Error:</b> ${msg}`,
  ];
  if (stack) {
    const short = stack.split('\n').slice(0, 4).join('\n');
    lines.push(`<pre>${short}</pre>`);
  }
  return lines.join('\n');
}

module.exports = { sendTelegramAlert, formatErrorAlert, formatCrashAlert, formatInfraAlert, formatJobAlert };

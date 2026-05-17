const logger = require('../config/logger');
const { sendTelegramAlert, formatCrashAlert } = require('./telegramAlert');

function installProcessGuard() {
  process.on('uncaughtException', (err) => {
    logger.error({
      msg: 'Uncaught Exception — process will restart',
      error: err.message,
      stack: err.stack,
    });
    sendTelegramAlert(formatCrashAlert('uncaughtException', err));
    setTimeout(() => process.exit(1), 500);
  });

  process.on('unhandledRejection', (reason) => {
    logger.error({
      msg: 'Unhandled Promise Rejection — process will restart',
      reason: reason instanceof Error ? reason.message : String(reason),
      stack: reason instanceof Error ? reason.stack : undefined,
    });
    sendTelegramAlert(formatCrashAlert('unhandledRejection', reason));
    setTimeout(() => process.exit(1), 500);
  });
}

module.exports = { installProcessGuard };

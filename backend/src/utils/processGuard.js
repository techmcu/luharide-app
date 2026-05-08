const logger = require('../config/logger');

function installProcessGuard() {
  process.on('uncaughtException', (err) => {
    logger.error({
      msg: 'Uncaught Exception — process will restart',
      error: err.message,
      stack: err.stack,
    });
    process.exit(1);
  });

  process.on('unhandledRejection', (reason) => {
    logger.error({
      msg: 'Unhandled Promise Rejection — process will restart',
      reason: reason instanceof Error ? reason.message : String(reason),
      stack: reason instanceof Error ? reason.stack : undefined,
    });
    process.exit(1);
  });
}

module.exports = { installProcessGuard };

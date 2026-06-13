const { pool, poolRead } = require('../config/database');
const logger = require('../config/logger');

const SHUTDOWN_TIMEOUT_MS = 15000;
let shuttingDown = false;

function installGracefulShutdown(server, { jobs = [], serviceName = 'service' } = {}) {
  const shutdown = async (signal) => {
    if (shuttingDown) return;
    shuttingDown = true;
    logger.info(`[${serviceName}] ${signal} received — starting graceful shutdown`);

    for (const job of jobs) {
      try { job.stop(); } catch (_) {}
    }

    const forceTimer = setTimeout(() => {
      logger.error(`[${serviceName}] Forced shutdown after ${SHUTDOWN_TIMEOUT_MS}ms timeout`);
      process.exit(1);
    }, SHUTDOWN_TIMEOUT_MS);
    forceTimer.unref();

    if (server) {
      server.close(async () => {
        await closePools(serviceName);
        process.exit(0);
      });
    } else {
      await closePools(serviceName);
      process.exit(0);
    }
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

async function closePools(serviceName) {
  try {
    await Promise.all([
      pool.end(),
      poolRead !== pool ? poolRead.end() : Promise.resolve(),
    ]);
    logger.info(`[${serviceName}] DB pools closed`);
  } catch (e) {
    logger.error(`[${serviceName}] Pool shutdown error: ${e.message}`);
  }
}

function isShuttingDown() {
  return shuttingDown;
}

module.exports = { installGracefulShutdown, isShuttingDown };

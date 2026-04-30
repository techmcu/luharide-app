const logger = require('../config/logger');
const { isRedisEnabled, getRedisClient } = require('../config/redis');
const {
  buildWatermarkedPdfFromUploadUrls,
  copyAndWatermarkExistingPdf,
} = require('../utils/kycBuildPdfFromUploadUrls');

let queue = null;

function getQueue() {
  if (queue) return queue;
  if (!isRedisEnabled()) return null;
  const client = getRedisClient();
  if (!client) return null;

  try {
    const Bull = require('bull');
    queue = new Bull('luha:kyc-pdf', {
      createClient(type) {
        if (type === 'client') return client;
        return client.duplicate();
      },
      defaultJobOptions: {
        attempts: 2,
        timeout: 120000,
        removeOnComplete: 50,
        removeOnFail: 200,
      },
    });

    queue.process('build', 2, async (job) => {
      const { urls, inputSubdir, filePrefix } = job.data;
      return buildWatermarkedPdfFromUploadUrls(urls, inputSubdir, filePrefix);
    });

    queue.process('copy', 2, async (job) => {
      const { url, filePrefix } = job.data;
      return copyAndWatermarkExistingPdf(url, filePrefix);
    });

    queue.on('failed', (job, err) => {
      logger.warn('KYC queue job failed', {
        id: job.id,
        name: job.name,
        error: err.message,
      });
    });

    logger.info('KYC PDF queue initialised (Bull + Redis)');
    return queue;
  } catch (e) {
    logger.warn('KYC queue init failed, using direct processing', {
      error: e.message,
    });
    return null;
  }
}

async function enqueueBuildPdf(urls, inputSubdir, filePrefix) {
  const q = getQueue();
  if (!q) {
    return buildWatermarkedPdfFromUploadUrls(urls, inputSubdir, filePrefix);
  }
  const job = await q.add('build', { urls, inputSubdir, filePrefix });
  return job.finished();
}

async function enqueueCopyPdf(url, filePrefix) {
  const q = getQueue();
  if (!q) {
    return copyAndWatermarkExistingPdf(url, filePrefix);
  }
  const job = await q.add('copy', { url, filePrefix });
  return job.finished();
}

module.exports = { enqueueBuildPdf, enqueueCopyPdf };

const logger = require('../src/config/logger');

class ServiceCircuitBreaker {
  constructor(name, options = {}) {
    this.name = name;
    this.failureThreshold = options.failureThreshold || 5;
    this.resetTimeoutMs = options.resetTimeoutMs || 30000;
    this.monitorWindowMs = options.monitorWindowMs || 60000;
    this.state = 'CLOSED';
    this.failures = [];
    this.openedAt = 0;
  }

  recordFailure() {
    const now = Date.now();
    this.failures = this.failures.filter((t) => now - t < this.monitorWindowMs);
    this.failures.push(now);
    if (this.failures.length >= this.failureThreshold && this.state === 'CLOSED') {
      this.state = 'OPEN';
      this.openedAt = now;
      logger.warn(
        `Circuit OPEN for ${this.name} (${this.failures.length} failures in ${this.monitorWindowMs}ms window)`
      );
    }
  }

  recordSuccess() {
    if (this.state === 'HALF_OPEN') {
      this.state = 'CLOSED';
      this.failures = [];
      logger.info(`Circuit CLOSED for ${this.name} (probe succeeded)`);
    }
  }

  isAvailable() {
    if (this.state === 'CLOSED') return true;
    if (this.state === 'OPEN') {
      if (Date.now() - this.openedAt >= this.resetTimeoutMs) {
        this.state = 'HALF_OPEN';
        logger.info(`Circuit HALF_OPEN for ${this.name} (allowing probe request)`);
        return true;
      }
      return false;
    }
    return true;
  }

  toJSON() {
    return {
      name: this.name,
      state: this.state,
      recentFailures: this.failures.length,
    };
  }
}

const breakers = {};

function getBreaker(name) {
  if (!breakers[name]) {
    breakers[name] = new ServiceCircuitBreaker(name, {
      failureThreshold: parseInt(process.env.CB_FAILURE_THRESHOLD || '5', 10),
      resetTimeoutMs: parseInt(process.env.CB_RESET_TIMEOUT_MS || '30000', 10),
      monitorWindowMs: parseInt(process.env.CB_MONITOR_WINDOW_MS || '60000', 10),
    });
  }
  return breakers[name];
}

function getAllBreakers() {
  return Object.values(breakers).map((b) => b.toJSON());
}

module.exports = { ServiceCircuitBreaker, getBreaker, getAllBreakers };

/**
 * PM2 staging ecosystem — temporary processes on ports 3100-3104.
 * Used ONLY during deploy pipeline for pre-production health checks.
 * Auto-deleted after validation passes or fails.
 */
const prodBase = { NODE_ENV: 'production', TRUST_PROXY: '1' };

const sharedOpts = {
  max_memory_restart: '300M',
  max_restarts: 3,
  min_uptime: '5s',
  restart_delay: 1000,
  kill_timeout: 5000,
};

module.exports = {
  apps: [
    {
      name: 'staging-auth-service',
      script: 'microservices/authService.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      env: { ...prodBase, AUTH_SERVICE_PORT: '3101' },
      ...sharedOpts,
    },
    {
      name: 'staging-core-ride-service',
      script: 'microservices/coreService.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      env: { ...prodBase, CORE_SERVICE_PORT: '3102' },
      ...sharedOpts,
    },
    {
      name: 'staging-union-admin-service',
      script: 'microservices/unionService.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      env: { ...prodBase, UNION_SERVICE_PORT: '3103' },
      ...sharedOpts,
    },
    {
      name: 'staging-platform-admin-service',
      script: 'microservices/platformService.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      env: { ...prodBase, PLATFORM_SERVICE_PORT: '3104' },
      ...sharedOpts,
    },
    {
      name: 'staging-api-gateway',
      script: 'gateway/server.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      env: {
        ...prodBase,
        GATEWAY_PORT: '3100',
        AUTH_URL: 'http://127.0.0.1:3101',
        CORE_URL: 'http://127.0.0.1:3102',
        UNION_URL: 'http://127.0.0.1:3103',
        PLATFORM_URL: 'http://127.0.0.1:3104',
      },
      ...sharedOpts,
    },
  ],
};

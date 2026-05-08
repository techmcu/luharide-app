/**
 * PM2 ecosystem — Phase 4 production default: 4 domain microservices + 1 API gateway (5 processes).
 * Gateway starts LAST so upstream services on ports 3001–3004 accept traffic before proxy.
 *
 * Usage (from backend/):
 *   pm2 start pm2-ecosystem-luharide-api-gateway-and-microservices.config.cjs
 *
 * Verify after deploy: npm run phase4:verify:stack
 * Mobile / Flutter: public URL = gateway only (default port 3000).
 */
const internalUpstreamBaseUrls = {
  AUTH_URL: 'http://127.0.0.1:3001',
  CORE_URL: 'http://127.0.0.1:3002',
  UNION_URL: 'http://127.0.0.1:3003',
  PLATFORM_URL: 'http://127.0.0.1:3004',
};

/**
 * Nginx/HTTPS in front — TRUST_PROXY=1 for correct rate limits per user.
 * To force off (direct :3000 only): remove TRUST_PROXY from prodBase or set TRUST_PROXY=0 in PM2 env.
 */
const prodBase = { NODE_ENV: 'production', TRUST_PROXY: '1' };

const sharedOpts = {
  max_memory_restart: '500M',
  max_restarts: 15,
  min_uptime: '10s',
  restart_delay: 2000,
  kill_timeout: 8000,
};

module.exports = {
  apps: [
    {
      name: 'luharide-auth-service',
      script: 'microservices/authService.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      env: { ...prodBase, AUTH_SERVICE_PORT: '3001' },
      ...sharedOpts,
    },
    {
      name: 'luharide-core-ride-service',
      script: 'microservices/coreService.js',
      cwd: __dirname,
      instances: parseInt(process.env.LUHA_CORE_INSTANCES, 10) || 2,
      exec_mode: 'cluster',
      env: { ...prodBase, CORE_SERVICE_PORT: '3002' },
      ...sharedOpts,
    },
    {
      name: 'luharide-union-admin-service',
      script: 'microservices/unionService.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      env: { ...prodBase, UNION_SERVICE_PORT: '3003' },
      ...sharedOpts,
    },
    {
      name: 'luharide-platform-admin-payments-service',
      script: 'microservices/platformService.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      env: { ...prodBase, PLATFORM_SERVICE_PORT: '3004' },
      ...sharedOpts,
    },
    {
      name: 'luharide-api-gateway',
      script: 'gateway/server.js',
      cwd: __dirname,
      instances: parseInt(process.env.LUHA_GATEWAY_INSTANCES, 10) || 2,
      exec_mode: 'cluster',
      env: {
        ...prodBase,
        GATEWAY_PORT: '3000',
        ...internalUpstreamBaseUrls,
      },
      ...sharedOpts,
    },
  ],
};

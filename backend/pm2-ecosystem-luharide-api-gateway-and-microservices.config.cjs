/**
 * PM2 ecosystem — LuhaRide: 4 domain microservices + 1 API gateway (5 Node processes).
 * Gateway starts LAST so upstream services on ports 3001–3004 accept traffic before proxy.
 *
 * Usage (from backend/):
 *   pm2 start pm2-ecosystem-luharide-api-gateway-and-microservices.config.cjs
 *
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

module.exports = {
  apps: [
    {
      name: 'luharide-auth-service',
      script: 'microservices/authService.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      env: { ...prodBase, AUTH_SERVICE_PORT: '3001' },
    },
    {
      name: 'luharide-core-ride-service',
      script: 'microservices/coreService.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      env: { ...prodBase, CORE_SERVICE_PORT: '3002' },
    },
    {
      name: 'luharide-union-admin-service',
      script: 'microservices/unionService.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      env: { ...prodBase, UNION_SERVICE_PORT: '3003' },
    },
    {
      name: 'luharide-platform-admin-payments-service',
      script: 'microservices/platformService.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      env: { ...prodBase, PLATFORM_SERVICE_PORT: '3004' },
    },
    {
      name: 'luharide-api-gateway',
      script: 'gateway/server.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      env: {
        ...prodBase,
        GATEWAY_PORT: '3000',
        ...internalUpstreamBaseUrls,
      },
    },
  ],
};

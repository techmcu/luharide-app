/**
 * PM2 — 4 microservices + API Gateway (LuhaRide)
 * Usage (from backend/):
 *   pm2 start ecosystem.microservices.config.cjs
 *   pm2 logs
 *
 * Mobile: point to gateway only (port 3000).
 */
module.exports = {
  apps: [
    {
      name: 'luharide-gateway',
      script: 'gateway/server.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      env: { NODE_ENV: 'production', GATEWAY_PORT: 3000 },
    },
    {
      name: 'luharide-auth',
      script: 'microservices/authService.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      env: { NODE_ENV: 'production', AUTH_SERVICE_PORT: 3001 },
    },
    {
      name: 'luharide-core',
      script: 'microservices/coreService.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      env: { NODE_ENV: 'production', CORE_SERVICE_PORT: 3002 },
    },
    {
      name: 'luharide-union',
      script: 'microservices/unionService.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      env: { NODE_ENV: 'production', UNION_SERVICE_PORT: 3003 },
    },
    {
      name: 'luharide-platform',
      script: 'microservices/platformService.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      env: { NODE_ENV: 'production', PLATFORM_SERVICE_PORT: 3004 },
    },
  ],
};

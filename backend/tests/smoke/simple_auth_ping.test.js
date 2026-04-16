const request = require('supertest');
const { createBaseApp, attachErrorHandlers } = require('../../microservices/sharedApp');
const simpleAuthRoutes = require('../../src/routes/simpleAuth');

describe('simple-auth', () => {
  test('GET /api/simple-auth/ping returns ok', async () => {
    const app = createBaseApp('test');
    app.use('/api/simple-auth', simpleAuthRoutes);
    attachErrorHandlers(app);

    const res = await request(app).get('/api/simple-auth/ping');
    expect(res.status).toBe(200);
    expect(res.body).toEqual(
      expect.objectContaining({
        ok: true,
        service: 'simple-auth',
      })
    );
    expect(typeof res.body.time).toBe('string');
  });
});


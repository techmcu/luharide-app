/**
 * Test VPS Online API - Run: node test-online-api.js
 * Verifies database integration and auth flow
 */
const BASE = 'http://76.13.243.157:3000/api';

async function test(name, fn) {
  try {
    await fn();
    console.log('✅', name);
    return true;
  } catch (e) {
    console.log('❌', name, '-', e.message || e.response?.data?.message || String(e).slice(0, 80));
    return false;
  }
}

async function main() {
  console.log('\n🔍 Testing LuhaRide VPS API (76.13.243.157:3000)\n');

  await test('Health + DB', async () => {
    const r = await fetch('http://76.13.243.157:3000/health');
    const d = await r.json();
    if (d.status !== 'ok' || d.database !== 'connected') throw new Error('DB not connected');
  });

  let token;
  await test('Signup', async () => {
    const email = `test${Date.now()}@test.com`;
    const r = await fetch(BASE + '/simple-auth/signup', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password: 'test123', name: 'Test User', role: 'passenger' }),
    });
    const d = await r.json();
    if (!d.success || !d.data?.tokens?.accessToken) throw new Error(d.message || 'Signup failed');
    token = d.data.tokens.accessToken;
  });

  await test('Login', async () => {
    const r = await fetch(BASE + '/simple-auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'test@test.com', password: 'test123' }),
    });
    const d = await r.json();
    if (!d.success) throw new Error(d.message || 'Login failed');
    token = d.data?.tokens?.accessToken || token;
  });

  if (token) {
    await test('Auth /me', async () => {
      const r = await fetch(BASE + '/auth/me', {
        headers: { Authorization: `Bearer ${token}` },
      });
      const d = await r.json();
      if (!d.success) throw new Error(d.message || 'Auth me failed');
    });

    await test('Notifications', async () => {
      const r = await fetch(BASE + '/notifications', {
        headers: { Authorization: `Bearer ${token}` },
      });
      const d = await r.json();
      if (!d.success) throw new Error(d.message || 'Notifications failed');
    });
  }

  await test('Trips search', async () => {
    const r = await fetch(BASE + '/trips/search?from=Dehradun&to=Haridwar&date=2026-03-01');
    const d = await r.json();
    if (!d.success) {
      if (d.message?.includes('column') || d.message?.includes('bio')) {
        throw new Error('Run migrations on VPS: npm run migrate');
      }
      throw new Error(d.message || 'Trips search failed');
    }
  });

  console.log('\n✅ Done. If trips search failed, run on VPS: cd backend && npm run migrate && pm2 restart luharide-api\n');
}

main().catch(console.error);

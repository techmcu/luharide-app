const { apiVersionRewrite } = require('./apiVersionRewrite');

function mockReq(url) {
  return { url };
}

describe('apiVersionRewrite', () => {
  test('/api/v1/trips → /api/trips', () => {
    const req = mockReq('/api/v1/trips');
    apiVersionRewrite(req, {}, () => {});
    expect(req.url).toBe('/api/trips');
  });

  test('/api/v1/auth/login → /api/auth/login', () => {
    const req = mockReq('/api/v1/auth/login');
    apiVersionRewrite(req, {}, () => {});
    expect(req.url).toBe('/api/auth/login');
  });

  test('/api/v1 alone → /api', () => {
    const req = mockReq('/api/v1');
    apiVersionRewrite(req, {}, () => {});
    expect(req.url).toBe('/api');
  });

  test('/api/trips unchanged (backward compat)', () => {
    const req = mockReq('/api/trips');
    apiVersionRewrite(req, {}, () => {});
    expect(req.url).toBe('/api/trips');
  });

  test('/health unchanged', () => {
    const req = mockReq('/health');
    apiVersionRewrite(req, {}, () => {});
    expect(req.url).toBe('/health');
  });

  test('calls next()', () => {
    const next = jest.fn();
    apiVersionRewrite(mockReq('/api/v1/x'), {}, next);
    expect(next).toHaveBeenCalled();
  });
});

const { socketRateLimit } = require('./socketRateLimit');

jest.mock('../config/logger', () => ({
  warn: jest.fn(),
}));

function mockSocket(ip = '1.2.3.4') {
  return {
    handshake: {
      headers: {},
      address: `::ffff:${ip}`,
    },
  };
}

describe('socketRateLimit', () => {
  test('allows connections under limit', () => {
    const limiter = socketRateLimit({ max: 5, windowMs: 60000 });
    const next = jest.fn();
    limiter(mockSocket('10.0.0.1'), next);
    expect(next).toHaveBeenCalledWith();
  });

  test('rejects connections over limit', () => {
    const limiter = socketRateLimit({ max: 3, windowMs: 60000 });
    const next = jest.fn();
    const socket = mockSocket('10.0.0.2');

    limiter(socket, jest.fn());
    limiter(socket, jest.fn());
    limiter(socket, jest.fn());
    limiter(socket, next);

    expect(next).toHaveBeenCalledWith(expect.any(Error));
    expect(next.mock.calls[0][0].message).toMatch(/Too many connections/);
  });

  test('uses x-forwarded-for header when present', () => {
    const limiter = socketRateLimit({ max: 2, windowMs: 60000 });
    const socket = mockSocket('192.168.1.1');
    socket.handshake.headers['x-forwarded-for'] = '5.6.7.8, 10.0.0.1';

    const next = jest.fn();
    limiter(socket, next);
    limiter(socket, next);

    // 3rd should fail (ip 5.6.7.8 hit limit)
    limiter(socket, next);
    expect(next).toHaveBeenLastCalledWith(expect.any(Error));
  });

  test('different IPs have separate limits', () => {
    const limiter = socketRateLimit({ max: 1, windowMs: 60000 });
    const next1 = jest.fn();
    const next2 = jest.fn();

    limiter(mockSocket('10.0.0.10'), next1);
    limiter(mockSocket('10.0.0.11'), next2);

    expect(next1).toHaveBeenCalledWith();
    expect(next2).toHaveBeenCalledWith();
  });
});

const mockReqObj = { on: jest.fn(), write: jest.fn(), end: jest.fn() };
const mockRequest = jest.fn(() => mockReqObj);
jest.mock('https', () => ({ request: mockRequest }));
jest.mock('../config/logger', () => ({ warn: jest.fn() }));

const { sendTelegramAlert, formatErrorAlert, formatCrashAlert } = require('./telegramAlert');

beforeEach(() => {
  jest.clearAllMocks();
});

afterEach(() => {
  delete process.env.TELEGRAM_BOT_TOKEN;
  delete process.env.TELEGRAM_CHAT_ID;
});

describe('formatErrorAlert', () => {
  test('includes status, route, and message', () => {
    const text = formatErrorAlert(500, 'DB down', '/api/trips', 'GET', 'Error: DB down\n  at x.js:1');
    expect(text).toContain('500');
    expect(text).toContain('GET /api/trips');
    expect(text).toContain('DB down');
  });
});

describe('formatCrashAlert', () => {
  test('includes crash type and error', () => {
    const err = new Error('segfault');
    const text = formatCrashAlert('uncaughtException', err);
    expect(text).toContain('CRASH');
    expect(text).toContain('uncaughtException');
    expect(text).toContain('segfault');
  });

  test('handles non-Error reason', () => {
    const text = formatCrashAlert('unhandledRejection', 'string reason');
    expect(text).toContain('string reason');
  });
});

describe('sendTelegramAlert', () => {
  test('does nothing when env vars are missing', () => {
    sendTelegramAlert('hello');
    expect(mockRequest).not.toHaveBeenCalled();
  });

  test('sends request when env vars are set', () => {
    process.env.TELEGRAM_BOT_TOKEN = 'test-token';
    process.env.TELEGRAM_CHAT_ID = '12345';

    sendTelegramAlert('test message');

    expect(mockRequest).toHaveBeenCalledTimes(1);
    const [opts] = mockRequest.mock.calls[0];
    expect(opts.hostname).toBe('api.telegram.org');
    expect(opts.path).toBe('/bottest-token/sendMessage');
    expect(mockReqObj.write).toHaveBeenCalled();
    expect(mockReqObj.end).toHaveBeenCalled();
  });
});

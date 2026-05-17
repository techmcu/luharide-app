const ApiError = require('../utils/ApiError');

jest.mock('../config/logger', () => ({ warn: jest.fn(), error: jest.fn() }));
jest.mock('./corsLuha', () => ({ applyCorsHeadersOnError: jest.fn() }));
jest.mock('../utils/telegramAlert', () => ({
  sendTelegramAlert: jest.fn(),
  formatErrorAlert: jest.fn(() => 'alert-text'),
}));

const { errorConverter, errorHandler } = require('./errorHandler');
const { sendTelegramAlert } = require('../utils/telegramAlert');

function mockReqRes() {
  const req = { originalUrl: '/api/test', method: 'GET', ip: '127.0.0.1' };
  const res = {
    statusCode: 200,
    status(code) { this.statusCode = code; return this; },
    json: jest.fn(),
  };
  return { req, res };
}

describe('errorConverter', () => {
  test('wraps plain Error into ApiError with 500', () => {
    const err = new Error('boom');
    const next = jest.fn();
    errorConverter(err, {}, {}, next);
    expect(next).toHaveBeenCalledWith(expect.any(ApiError));
    expect(next.mock.calls[0][0].statusCode).toBe(500);
  });

  test('passes through ApiError unchanged', () => {
    const err = new ApiError(404, 'not found', true);
    const next = jest.fn();
    errorConverter(err, {}, {}, next);
    expect(next.mock.calls[0][0].statusCode).toBe(404);
  });
});

describe('errorHandler', () => {
  test('returns 500 and sends Telegram alert for server errors', () => {
    const { req, res } = mockReqRes();
    const err = new ApiError(500, 'Internal Server Error', false);
    errorHandler(err, req, res, jest.fn());
    expect(res.statusCode).toBe(500);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: false }));
    expect(sendTelegramAlert).toHaveBeenCalledWith('alert-text');
  });

  test('does not send Telegram alert for 4xx errors', () => {
    const { req, res } = mockReqRes();
    sendTelegramAlert.mockClear();
    const err = new ApiError(400, 'bad request', true);
    errorHandler(err, req, res, jest.fn());
    expect(res.statusCode).toBe(400);
    expect(sendTelegramAlert).not.toHaveBeenCalled();
  });

  test('maps JWT errors to 401', () => {
    const { req, res } = mockReqRes();
    const err = new ApiError(500, 'jwt malformed', false);
    err.name = 'JsonWebTokenError';
    errorHandler(err, req, res, jest.fn());
    expect(res.statusCode).toBe(401);
  });

  test('maps unique violation (23505) to 409', () => {
    const { req, res } = mockReqRes();
    const err = new ApiError(500, 'duplicate', false);
    err.code = '23505';
    errorHandler(err, req, res, jest.fn());
    expect(res.statusCode).toBe(409);
  });

  test('hides 5xx details in production', () => {
    const prev = process.env.NODE_ENV;
    process.env.NODE_ENV = 'production';
    const { req, res } = mockReqRes();
    const err = new ApiError(500, 'secret db info', false);
    errorHandler(err, req, res, jest.fn());
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ message: 'Something went wrong. Please try again later.' })
    );
    process.env.NODE_ENV = prev;
  });
});

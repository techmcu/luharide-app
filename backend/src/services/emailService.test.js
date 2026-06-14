/**
 * emailService unit tests — transporter singleton, email sending, OTP emails.
 * nodemailer is fully mocked.
 */

const mockSendMail = jest.fn();
const mockCreateTransport = jest.fn(() => ({ sendMail: mockSendMail }));

jest.mock('nodemailer', () => ({
  createTransport: mockCreateTransport,
}));
jest.mock('../config/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));

// Save original env and module reference
const origEnv = { ...process.env };

beforeEach(() => {
  jest.clearAllMocks();
  mockSendMail.mockResolvedValue({ messageId: 'test-msg-id-123' });

  // Reset the transporter singleton by clearing module cache
  jest.resetModules();

  // Reset env vars
  delete process.env.EMAIL_USER;
  delete process.env.EMAIL_APP_PASSWORD;
  delete process.env.SMTP_USER;
  delete process.env.SMTP_PASSWORD;
  delete process.env.SMTP_HOST;
  delete process.env.SMTP_PORT;
  delete process.env.SMTP_SECURE;
  delete process.env.EMAIL_FROM;
});

afterAll(() => {
  // Restore original env
  Object.assign(process.env, origEnv);
});

function loadService() {
  // Re-require to pick up fresh env and reset singleton
  return require('./emailService');
}

// ── isEmailConfigured ────────────────────────────────────────────────────────

describe('isEmailConfigured', () => {
  it('returns true when EMAIL_USER and EMAIL_APP_PASSWORD are set', () => {
    process.env.EMAIL_USER = 'user@gmail.com';
    process.env.EMAIL_APP_PASSWORD = 'app-password';
    const { isEmailConfigured } = loadService();

    expect(isEmailConfigured()).toBe(true);
  });

  it('returns true when SMTP_USER and SMTP_PASSWORD are set', () => {
    process.env.SMTP_USER = 'smtp-user';
    process.env.SMTP_PASSWORD = 'smtp-pass';
    const { isEmailConfigured } = loadService();

    expect(isEmailConfigured()).toBe(true);
  });

  it('returns false when no email credentials are set', () => {
    const { isEmailConfigured } = loadService();
    expect(isEmailConfigured()).toBe(false);
  });
});

// ── getTransporter ───────────────────────────────────────────────────────────

describe('getTransporter', () => {
  it('returns null when credentials are not set', () => {
    const { getTransporter } = loadService();
    expect(getTransporter()).toBeNull();
  });

  it('creates transporter with correct config when credentials exist', () => {
    process.env.EMAIL_USER = 'user@gmail.com';
    process.env.EMAIL_APP_PASSWORD = 'app-password';
    const { getTransporter } = loadService();

    const trans = getTransporter();
    expect(trans).toBeDefined();
    expect(trans).not.toBeNull();

    expect(mockCreateTransport).toHaveBeenCalledWith({
      host: 'smtp.gmail.com',
      port: 587,
      secure: false,
      auth: { user: 'user@gmail.com', pass: 'app-password' },
    });
  });

  it('returns same instance on second call (singleton)', () => {
    process.env.EMAIL_USER = 'user@gmail.com';
    process.env.EMAIL_APP_PASSWORD = 'app-password';
    const { getTransporter } = loadService();

    const first = getTransporter();
    const second = getTransporter();
    expect(first).toBe(second);
    expect(mockCreateTransport).toHaveBeenCalledTimes(1);
  });

  it('respects custom SMTP_HOST and SMTP_PORT', () => {
    process.env.EMAIL_USER = 'user@company.com';
    process.env.EMAIL_APP_PASSWORD = 'pass';
    process.env.SMTP_HOST = 'smtp.company.com';
    process.env.SMTP_PORT = '465';
    process.env.SMTP_SECURE = 'true';
    const { getTransporter } = loadService();

    getTransporter();

    expect(mockCreateTransport).toHaveBeenCalledWith(
      expect.objectContaining({
        host: 'smtp.company.com',
        port: 465,
        secure: true,
      })
    );
  });
});

// ── sendEmail ────────────────────────────────────────────────────────────────

describe('sendEmail', () => {
  it('sends email with correct parameters when configured', async () => {
    process.env.EMAIL_USER = 'sender@gmail.com';
    process.env.EMAIL_APP_PASSWORD = 'pass';
    const { sendEmail } = loadService();

    const result = await sendEmail('to@example.com', 'Test Subject', '<p>Hello</p>');

    expect(result.sent).toBe(true);
    expect(result.messageId).toBe('test-msg-id-123');
    expect(mockSendMail).toHaveBeenCalledWith(
      expect.objectContaining({
        to: 'to@example.com',
        subject: 'Test Subject',
        html: '<p>Hello</p>',
      })
    );
  });

  it('uses EMAIL_FROM when set', async () => {
    process.env.EMAIL_USER = 'sender@gmail.com';
    process.env.EMAIL_APP_PASSWORD = 'pass';
    process.env.EMAIL_FROM = 'LuhaRide <noreply@luharide.com>';
    const { sendEmail } = loadService();

    await sendEmail('to@example.com', 'Subject', '<p>Body</p>');

    expect(mockSendMail).toHaveBeenCalledWith(
      expect.objectContaining({
        from: 'LuhaRide <noreply@luharide.com>',
      })
    );
  });

  it('generates plain text fallback from HTML when text not provided', async () => {
    process.env.EMAIL_USER = 'sender@gmail.com';
    process.env.EMAIL_APP_PASSWORD = 'pass';
    const { sendEmail } = loadService();

    await sendEmail('to@example.com', 'Subject', '<p>Hello <strong>World</strong></p>');

    const mailOpts = mockSendMail.mock.calls[0][0];
    expect(mailOpts.text).toBe('Hello World');
  });

  it('uses provided plain text when given', async () => {
    process.env.EMAIL_USER = 'sender@gmail.com';
    process.env.EMAIL_APP_PASSWORD = 'pass';
    const { sendEmail } = loadService();

    await sendEmail('to@example.com', 'Subject', '<p>HTML</p>', 'Plain text');

    const mailOpts = mockSendMail.mock.calls[0][0];
    expect(mailOpts.text).toBe('Plain text');
  });

  it('returns dev fallback in development when not configured', async () => {
    const origNodeEnv = process.env.NODE_ENV;
    process.env.NODE_ENV = 'development';
    const { sendEmail } = loadService();

    const result = await sendEmail('to@example.com', 'Subject', '<p>Body</p>');

    expect(result.sent).toBe(false);
    expect(result.dev).toBe(true);
    expect(mockSendMail).not.toHaveBeenCalled();

    process.env.NODE_ENV = origNodeEnv;
  });

  it('throws ApiError when not configured in production', async () => {
    const origNodeEnv = process.env.NODE_ENV;
    process.env.NODE_ENV = 'production';
    const { sendEmail } = loadService();

    await expect(sendEmail('to@example.com', 'Subject', '<p>Body</p>')).rejects.toThrow(
      'Email service not configured'
    );

    process.env.NODE_ENV = origNodeEnv;
  });

  it('throws ApiError when sendMail fails', async () => {
    process.env.EMAIL_USER = 'sender@gmail.com';
    process.env.EMAIL_APP_PASSWORD = 'pass';
    mockSendMail.mockRejectedValueOnce(new Error('SMTP connection failed'));
    const { sendEmail } = loadService();

    await expect(sendEmail('to@example.com', 'Subject', '<p>Body</p>')).rejects.toThrow(
      'Failed to send email'
    );
  });
});

// ── sendOTPEmail ─────────────────────────────────────────────────────────────

describe('sendOTPEmail', () => {
  it('sends email with OTP in the body', async () => {
    process.env.EMAIL_USER = 'sender@gmail.com';
    process.env.EMAIL_APP_PASSWORD = 'pass';
    const { sendOTPEmail } = loadService();

    const result = await sendOTPEmail('user@example.com', '987654');

    expect(result.sent).toBe(true);
    expect(mockSendMail).toHaveBeenCalledTimes(1);

    const mailOpts = mockSendMail.mock.calls[0][0];
    expect(mailOpts.to).toBe('user@example.com');
    expect(mailOpts.subject).toContain('verification code');
    expect(mailOpts.html).toContain('987654');
    expect(mailOpts.html).toContain('10 minutes');
  });
});

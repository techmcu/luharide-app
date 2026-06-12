/**
 * Joi validation middleware + schemas — SOP SEC-007→008
 * No DB needed — pure unit tests.
 */

const { validate, schemas } = require('./validation');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}

describe('validate middleware', () => {
  const Joi = require('joi');
  const testSchema = Joi.object({
    name: Joi.string().min(2).required(),
    age: Joi.number().integer().positive(),
  });
  const middleware = validate(testSchema);

  it('passes valid body', () => {
    const req = { body: { name: 'Rahul', age: 25 } };
    const next = jest.fn();
    middleware(req, mockRes(), next);

    expect(next).toHaveBeenCalledWith();
    expect(req.body.name).toBe('Rahul');
  });

  it('strips unknown fields', () => {
    const req = { body: { name: 'Rahul', unknown_field: 'foo' } };
    const next = jest.fn();
    middleware(req, mockRes(), next);

    expect(next).toHaveBeenCalledWith();
    expect(req.body.unknown_field).toBeUndefined();
  });

  it('throws on missing required field', () => {
    const req = { body: {} };
    expect(() => middleware(req, mockRes(), jest.fn())).toThrow();
  });

  it('throws on invalid type', () => {
    const req = { body: { name: 'Rahul', age: 'not-a-number' } };
    expect(() => middleware(req, mockRes(), jest.fn())).toThrow();
  });
});

describe('schemas.phone', () => {
  it('accepts valid Indian phone', () => {
    const { error } = schemas.phone.validate('9876543210');
    expect(error).toBeUndefined();
  });

  it('rejects phone starting with 0-5', () => {
    const { error } = schemas.phone.validate('1234567890');
    expect(error).toBeDefined();
  });

  it('rejects short phone', () => {
    const { error } = schemas.phone.validate('98765');
    expect(error).toBeDefined();
  });

  it('rejects phone with letters', () => {
    const { error } = schemas.phone.validate('98765abcde');
    expect(error).toBeDefined();
  });
});

describe('schemas.otp', () => {
  it('accepts valid 6-digit OTP', () => {
    const { error } = schemas.otp.validate('123456');
    expect(error).toBeUndefined();
  });

  it('rejects 5-digit OTP', () => {
    const { error } = schemas.otp.validate('12345');
    expect(error).toBeDefined();
  });

  it('rejects OTP with letters', () => {
    const { error } = schemas.otp.validate('12345a');
    expect(error).toBeDefined();
  });
});

describe('schemas.name', () => {
  it('accepts valid name', () => {
    const { error } = schemas.name.validate('Rahul Panwar');
    expect(error).toBeUndefined();
  });

  it('rejects single character name', () => {
    const { error } = schemas.name.validate('R');
    expect(error).toBeDefined();
  });

  it('rejects name over 100 chars', () => {
    const { error } = schemas.name.validate('A'.repeat(101));
    expect(error).toBeDefined();
  });
});

describe('schemas.email', () => {
  it('accepts valid email', () => {
    const { error } = schemas.email.validate('test@example.com');
    expect(error).toBeUndefined();
  });

  it('accepts empty string (optional)', () => {
    const { error } = schemas.email.validate('');
    expect(error).toBeUndefined();
  });

  it('rejects invalid email', () => {
    const { error } = schemas.email.validate('not-an-email');
    expect(error).toBeDefined();
  });
});

describe('schemas.role', () => {
  it('accepts passenger', () => {
    const { error } = schemas.role.validate('passenger');
    expect(error).toBeUndefined();
  });

  it('accepts driver', () => {
    const { error } = schemas.role.validate('driver');
    expect(error).toBeUndefined();
  });

  it('rejects admin (not in allowed list)', () => {
    const { error } = schemas.role.validate('admin');
    expect(error).toBeDefined();
  });
});

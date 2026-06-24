/**
 * createSchedulesSchema — request validation for POST /union/schedules/bulk.
 * Pure Joi schema test (no DB/network).
 */

const { createSchedulesSchema } = require('./union');

const opts = { abortEarly: false, allowUnknown: true, stripUnknown: true };
const futureTime = () => new Date(Date.now() + 60 * 60 * 1000).toISOString();
const DRIVER = 'd0000000-0000-0000-0000-000000000001';

describe('createSchedulesSchema', () => {
  test('REGRESSION: accepts a schedules[] item with NULL coords (was "must be a number")', () => {
    const { error } = createSchedulesSchema.validate({
      schedules: [{
        union_driver_id: DRIVER, from_location: 'Dehradun', to_location: 'Purola',
        departure_time: futureTime(), from_lat: null, from_lng: null, to_lat: null, to_lng: null,
      }],
    }, opts);
    expect(error).toBeUndefined();
  });

  test('accepts a schedules[] item with real coords', () => {
    const { error } = createSchedulesSchema.validate({
      schedules: [{
        union_driver_id: DRIVER, from_location: 'Dehradun', to_location: 'Purola',
        departure_time: futureTime(), from_lat: 30.3, from_lng: 78.0,
      }],
    }, opts);
    expect(error).toBeUndefined();
  });

  test('accepts a multi-ride batch (different routes)', () => {
    const { error } = createSchedulesSchema.validate({
      schedules: [
        { union_driver_id: DRIVER, from_location: 'Dehradun', to_location: 'Purola', departure_time: futureTime() },
        { union_driver_id: 'd0000000-0000-0000-0000-000000000002', from_location: 'Purola', to_location: 'Dehradun', departure_time: futureTime() },
      ],
    }, opts);
    expect(error).toBeUndefined();
  });

  test('still accepts the LEGACY union_driver_ids shape', () => {
    const { error } = createSchedulesSchema.validate({
      union_driver_ids: [DRIVER], from_location: 'Dehradun', to_location: 'Purola', departure_time: futureTime(),
    }, opts);
    expect(error).toBeUndefined();
  });

  test('rejects when neither schedules[] nor union_driver_ids is present', () => {
    const { error } = createSchedulesSchema.validate({ from_location: 'A' }, opts);
    expect(error).toBeDefined();
  });

  test('rejects more than 50 rides in a batch', () => {
    const schedules = Array.from({ length: 51 }, (_, i) => ({
      union_driver_id: DRIVER, from_location: 'Dehradun', to_location: 'Purola', departure_time: futureTime(),
    }));
    const { error } = createSchedulesSchema.validate({ schedules }, opts);
    expect(error).toBeDefined();
  });
});

-- 066: Driver seat locks — an independent driver can reserve (lock) any of their
-- OWN ride's currently-unbooked seats so no passenger can book them (e.g. holding
-- a seat for a relative). Only the trip's own driver may lock/unlock. A lock
-- blocks booking exactly like a confirmed seat and is released when the driver
-- unlocks it or the trip is deleted (ON DELETE CASCADE).
--
-- SAFETY: brand-new table, CREATE IF NOT EXISTS, fully idempotent. No existing
-- table is altered, so the change is backward compatible — every read/write path
-- treats a missing table (pre-migration) as simply "no locks", never an error.

CREATE TABLE IF NOT EXISTS trip_seat_locks (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id     UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  seat_number INTEGER NOT NULL CHECK (seat_number >= 2),
  note        VARCHAR(80),
  created_by  UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE (trip_id, seat_number)
);

CREATE INDEX IF NOT EXISTS idx_trip_seat_locks_trip ON trip_seat_locks(trip_id);

COMMENT ON TABLE trip_seat_locks IS 'Driver-reserved (locked) seats on their own trip. Blocks passenger booking like a confirmed seat. seat_number uses API convention (1=driver, 2..N bookable); only 2..N can be locked.';

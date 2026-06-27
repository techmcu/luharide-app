-- 067: One-time correction of union_schedules.departure_time stored by the old app path.
--
-- BUG (pre-fix): the app sent a NAKED local datetime ("2026-06-27T10:00:00", no zone) into
-- the TIMESTAMPTZ column. On the UTC DB session that was read as 10:00 UTC = 15:30 IST, so a
-- ride the union created for 10:00 showed up at 15:30 in passenger search (and lingered 5h30m
-- past its real time). The code fix now attaches +05:30 to naked values at insert time, so
-- EVERY new ride is a correct instant. This migration corrects rides that were ALREADY stored
-- the wrong way — shifting them back by 5h30m so 10:00Z becomes the real 04:30Z (= 10:00 IST).
--
-- Scope: only still-upcoming, non-cancelled rides — past rides are already filtered out of
-- search/dashboard and ageing out, so we leave them untouched. Runs exactly once (migration
-- runner tracks applied files), so there is no double-shift risk.

UPDATE union_schedules
   SET departure_time = departure_time - INTERVAL '330 minutes'
 WHERE status = 'scheduled'
   AND departure_time > NOW();

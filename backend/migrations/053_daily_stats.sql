-- Rolling daily stats queue for admin dashboard (180-day window).
-- Cron job inserts one row per day; deletes rows older than 180 days.
CREATE TABLE IF NOT EXISTS daily_stats (
    stat_date     DATE PRIMARY KEY,
    new_users     INT DEFAULT 0,
    new_trips     INT DEFAULT 0,
    completed_trips INT DEFAULT 0,
    cancelled_trips INT DEFAULT 0,
    new_bookings  INT DEFAULT 0,
    confirmed_bookings INT DEFAULT 0,
    cancelled_bookings INT DEFAULT 0,
    upcoming_trips INT DEFAULT 0,
    active_drivers INT DEFAULT 0,
    created_at    TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_daily_stats_date ON daily_stats(stat_date DESC);

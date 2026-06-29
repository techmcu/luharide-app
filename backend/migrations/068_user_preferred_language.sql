-- Migration 068: per-user notification language preference.
-- Notifications (in-app + FCM push) are rendered server-side, so the server must
-- know each user's chosen language to send ONE clean message instead of cramming
-- English + Hindi together. The Flutter app pushes this on login and whenever the
-- user toggles language. Defaults to 'en' to match the app's own default language.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS preferred_language VARCHAR(5) NOT NULL DEFAULT 'en';

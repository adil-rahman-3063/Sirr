-- Schema for anonymous push notification subscriptions in Cloudflare D1
CREATE TABLE IF NOT EXISTS subscriptions (
  id TEXT PRIMARY KEY,
  endpoint TEXT NOT NULL UNIQUE,
  p256dh TEXT NOT NULL,
  auth TEXT NOT NULL,
  lat REAL NOT NULL,
  lng REAL NOT NULL,
  location_key TEXT NOT NULL, -- e.g. "10.52,76.21,3" (rounded coords + method)
  timezone TEXT NOT NULL DEFAULT 'UTC',
  city TEXT,
  method INTEGER DEFAULT 3,
  fajr INTEGER DEFAULT 1,
  dhuhr INTEGER DEFAULT 1,
  asr INTEGER DEFAULT 1,
  maghrib INTEGER DEFAULT 1,
  isha INTEGER DEFAULT 1,
  last_prayer TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Table to store cached daily prayer times fetched from Aladhan API
CREATE TABLE IF NOT EXISTS daily_prayer_times (
  location_key TEXT NOT NULL,
  date_str TEXT NOT NULL,     -- Format: "YYYY-MM-DD"
  lat REAL NOT NULL,
  lng REAL NOT NULL,
  method INTEGER NOT NULL,
  timezone TEXT NOT NULL,
  fajr TEXT NOT NULL,         -- "HH:MM"
  sunrise TEXT NOT NULL,      -- "HH:MM"
  dhuhr TEXT NOT NULL,        -- "HH:MM"
  asr TEXT NOT NULL,          -- "HH:MM"
  maghrib TEXT NOT NULL,      -- "HH:MM"
  isha TEXT NOT NULL,         -- "HH:MM"
  created_at INTEGER NOT NULL,
  PRIMARY KEY (location_key, date_str)
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_location ON subscriptions(location_key);
CREATE INDEX IF NOT EXISTS idx_subscriptions_updated ON subscriptions(updated_at);
CREATE INDEX IF NOT EXISTS idx_daily_times_date ON daily_prayer_times(date_str);

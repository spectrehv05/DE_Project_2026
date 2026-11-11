-- WhatsApp Messaging Database
-- CP3: Indexes for the 30-query workload (queries/workload_30.sql)
--
-- Run after 01_schema.sql and 02_load_data.sql:
--   psql -d wa_project -f sql/05_indexes.sql
-- Safe to re-run (every statement is IF NOT EXISTS).
--
-- Each index lists the queries it serves. Partial indexes are used where the
-- query filters on a rare value, so the index stays small and cheap to maintain.

SET search_path TO whatsapp;

-- ---------------------------------------------------------------------
-- messages
-- ---------------------------------------------------------------------

-- R01, R02, R13, R19, W02: latest message / messages of one chat, newest first.
CREATE INDEX IF NOT EXISTS idx_messages_chat_sent
    ON messages (chat_id, sent_at DESC);

-- R08, R10, R14, R17, R20: time-range filters and per-day / per-hour grouping.
-- INCLUDE lets these run as index-only scans without touching the table.
CREATE INDEX IF NOT EXISTS idx_messages_sent_at
    ON messages (sent_at) INCLUDE (chat_id, sender_id, message_type);

-- R12: only forwarded messages matter, grouped by sender and day.
CREATE INDEX IF NOT EXISTS idx_messages_forwarded
    ON messages (sender_id, sent_at) WHERE is_forwarded;

-- R13: "has anyone replied to this message?" lookup.
CREATE INDEX IF NOT EXISTS idx_messages_reply_to
    ON messages (reply_to_message_id) WHERE reply_to_message_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- message_receipts
-- ---------------------------------------------------------------------

-- R03, W02: unread receipts of one user. Only unread rows are indexed.
CREATE INDEX IF NOT EXISTS idx_receipts_unread
    ON message_receipts (user_id, message_id) WHERE read_at IS NULL;

-- R08: receipts that are still undelivered.
CREATE INDEX IF NOT EXISTS idx_receipts_undelivered
    ON message_receipts (message_id) WHERE delivered_at IS NULL;

-- ---------------------------------------------------------------------
-- chat_members, calls, users, devices, media
-- ---------------------------------------------------------------------

-- R01, R06, R11, R18, W05: find a user's chats. The primary key starts with chat_id,
-- so it cannot be used to look up by user_id.
CREATE INDEX IF NOT EXISTS idx_members_user
    ON chat_members (user_id) INCLUDE (chat_id, left_at);

-- R11: missed calls per chat, newest first.
CREATE INDEX IF NOT EXISTS idx_calls_missed
    ON calls (chat_id, started_at DESC) WHERE status = 'MISSED';

-- R18: users not seen since a date.
CREATE INDEX IF NOT EXISTS idx_users_last_seen
    ON users (last_seen_at);

-- R23: stale WEB / DESKTOP devices.
CREATE INDEX IF NOT EXISTS idx_devices_web_desktop_active
    ON devices (last_active_at) WHERE device_type IN ('WEB', 'DESKTOP');

-- Not indexed on purpose: R09, R20, R21, R24 aggregate the whole table, so a full scan is
-- already the cheapest plan and an index would only slow down writes.

-- Refresh statistics and the visibility map so the planner can use index-only scans.
VACUUM (ANALYZE) users;
VACUUM (ANALYZE) chats;
VACUUM (ANALYZE) chat_members;
VACUUM (ANALYZE) messages;
VACUUM (ANALYZE) message_receipts;
VACUUM (ANALYZE) calls;
VACUUM (ANALYZE) devices;
VACUUM (ANALYZE) media;
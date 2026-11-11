-- =====================================================================
-- WhatsApp DBMS Project: optimized versions of the 30 workload queries
--
-- Same ids and same questions as queries/workload_30.sql. Run with:
--   psql -d wa_project -f sql/05_indexes.sql          (indexes first)
--   ./benchmarks/run_benchmark.sh wa_project optimized 3 sql/06_optimized_queries.sql
--
-- Queries marked UNCHANGED already use the new indexes (or primary keys) as written.
-- Queries marked REWRITTEN needed a different formulation.
-- =====================================================================
SET search_path TO whatsapp;
BEGIN;

-- @R01
-- Chats screen: user 965's chats with the time and text of the latest message, newest first
-- UNCHANGED: idx_members_user finds the chats, idx_messages_chat_sent gives the latest message per chat
SELECT cm.chat_id, c.chat_type, c.group_name, last_msg.sent_at, last_msg.body
FROM chat_members cm
JOIN chats c ON c.chat_id = cm.chat_id
CROSS JOIN LATERAL (
    SELECT m.sent_at, m.body FROM messages m
    WHERE m.chat_id = cm.chat_id
    ORDER BY m.sent_at DESC
    LIMIT 1
) last_msg
WHERE cm.user_id = 965 AND cm.left_at IS NULL
ORDER BY last_msg.sent_at DESC;

-- @R02
-- Open a chat: the latest 50 messages of group 22556
-- UNCHANGED: idx_messages_chat_sent
SELECT message_id, sender_id, sent_at, message_type, body, reply_to_message_id
FROM messages
WHERE chat_id = 22556
ORDER BY sent_at DESC
LIMIT 50;

-- @R03
-- Badge counts: unread messages per chat for user 965
-- UNCHANGED: idx_receipts_unread
SELECT m.chat_id, count(*) AS unread
FROM message_receipts r
JOIN messages m ON m.message_id = r.message_id
WHERE r.user_id = 965 AND r.read_at IS NULL
GROUP BY m.chat_id
ORDER BY unread DESC;

-- @R04
-- Search: messages containing "meeting" in any chat user 965 belongs to
-- UNCHANGED: idx_messages_chat_sent and idx_members_user
SELECT m.chat_id, m.message_id, m.sent_at, m.body
FROM messages m
JOIN chat_members cm ON cm.chat_id = m.chat_id AND cm.user_id = 965
WHERE m.body ILIKE '%meeting%'
ORDER BY m.sent_at DESC
LIMIT 20;

-- @R05
-- Registration: is this phone number already on WhatsApp?
-- UNCHANGED: already a unique-index lookup
SELECT user_id, display_name, status
FROM users
WHERE phone_e164 = '+919000000965';

-- @R06
-- Contact info: "last seen" of everyone user 965 chats with directly
-- UNCHANGED: idx_members_user
SELECT u.user_id, u.display_name, u.last_seen_at
FROM chat_members me
JOIN chats c         ON c.chat_id = me.chat_id AND c.chat_type = 'DIRECT'
JOIN chat_members other ON other.chat_id = me.chat_id AND other.user_id <> me.user_id
JOIN users u         ON u.user_id = other.user_id
WHERE me.user_id = 965
ORDER BY u.last_seen_at DESC NULLS LAST;

-- @R07
-- Group info screen: current members of group 22556 with their role
-- UNCHANGED: already primary-key lookups
SELECT cm.user_id, u.display_name, cm.role, cm.joined_at
FROM chat_members cm
JOIN users u ON u.user_id = cm.user_id
WHERE cm.chat_id = 22556 AND cm.left_at IS NULL
ORDER BY cm.role, u.display_name;

-- @R08
-- Delivery service: receipts still not delivered for messages sent before 23:00 on 30 Jun 2026
-- UNCHANGED: idx_messages_sent_at (ordered) + idx_receipts_undelivered
SELECT r.message_id, r.user_id, m.sent_at
FROM message_receipts r
JOIN messages m ON m.message_id = r.message_id
WHERE r.delivered_at IS NULL
  AND m.sent_at < '2026-06-30 23:00:00+05:30'
ORDER BY m.sent_at
LIMIT 500;

-- @R09
-- Storage team: top 20 users by total media uploaded (GB)
-- UNCHANGED: whole-table aggregate, a full scan is already the cheapest plan
SELECT uploader_id, count(*) AS files, round(sum(size_bytes) / 1024.0 / 1024 / 1024, 3) AS gb
FROM media
GROUP BY uploader_id
ORDER BY sum(size_bytes) DESC
LIMIT 20;

-- @R10
-- Growth: daily active senders in June 2026
-- REWRITTEN: sent_at::date BETWEEN ... hid the column behind a cast; a plain range on sent_at can use idx_messages_sent_at
SELECT sent_at::date AS day, count(DISTINCT sender_id) AS active_senders, count(*) AS messages
FROM messages
WHERE sent_at >= '2026-06-01' AND sent_at < '2026-07-01'
GROUP BY 1
ORDER BY 1;

-- @R11
-- Calls tab: missed calls received by user 965 since 1 Jan 2025
-- REWRITTEN: EXTRACT(YEAR FROM started_at) >= 2025 became started_at >= '2025-01-01' so the index applies
SELECT c.call_id, c.caller_id, c.call_type, c.started_at
FROM calls c
JOIN chat_members cm ON cm.chat_id = c.chat_id AND cm.user_id = 965
WHERE c.status = 'MISSED'
  AND c.caller_id <> 965
  AND c.started_at >= '2025-01-01'
ORDER BY c.started_at DESC;

-- @R12
-- Spam detection: users who forwarded 2+ messages on the same day
-- UNCHANGED: idx_messages_forwarded
SELECT sender_id, sent_at::date AS day, count(*) AS forwarded
FROM messages
WHERE is_forwarded
GROUP BY sender_id, sent_at::date
HAVING count(*) >= 2
ORDER BY forwarded DESC, sender_id;

-- @R13
-- Group admins: questions asked in group 20501 that nobody has replied to
-- REWRITTEN: NOT IN returns no rows when the subquery contains a NULL (reply_to_message_id is NULL for most messages),
-- so the original always returned 0 rows. NOT EXISTS gives the intended answer and uses idx_messages_reply_to.
SELECT m.message_id, m.sender_id, m.sent_at, m.body
FROM messages m
WHERE m.chat_id = 20501
  AND m.body LIKE '%?%'
  AND NOT EXISTS (SELECT 1 FROM messages r WHERE r.reply_to_message_id = m.message_id);

-- @R14
-- Engagement: 10 groups with the most distinct senders in June 2026
-- UNCHANGED: idx_messages_sent_at (index-only)
SELECT m.chat_id, c.group_name, count(DISTINCT m.sender_id) AS active_members, count(*) AS messages
FROM messages m
JOIN chats c ON c.chat_id = m.chat_id AND c.chat_type = 'GROUP'
WHERE m.sent_at >= '2026-06-01' AND m.sent_at < '2026-07-01'
GROUP BY m.chat_id, c.group_name
ORDER BY active_members DESC, messages DESC
LIMIT 10;

-- @R15
-- Before delivering: has user 3064 blocked user 17793?
-- UNCHANGED: composite primary key
SELECT EXISTS (SELECT 1 FROM blocked_users WHERE blocker_id = 3064 AND blocked_id = 17793) AS is_blocked;

-- @R16
-- Message info screen: who has read message 119989 and when
-- UNCHANGED: primary keys
SELECT r.user_id, u.display_name, r.delivered_at, r.read_at
FROM message_receipts r
JOIN users u ON u.user_id = r.user_id
WHERE r.message_id = 119989
ORDER BY r.read_at NULLS LAST;

-- @R17
-- Product analytics: average minutes from sending to reading, per message type (June 2026)
-- UNCHANGED: idx_messages_sent_at finds June messages, receipts are joined by primary key
SELECT m.message_type,
       round(avg(EXTRACT(EPOCH FROM (r.read_at - m.sent_at)) / 60), 1) AS avg_minutes_to_read,
       count(*) AS reads
FROM message_receipts r
JOIN messages m ON m.message_id = r.message_id
WHERE r.read_at IS NOT NULL
  AND m.sent_at >= '2026-06-01' AND m.sent_at < '2026-07-01'
GROUP BY m.message_type
ORDER BY avg_minutes_to_read;

-- @R18
-- Clean-up: users not seen since April 2026 who are still in at least one group
-- UNCHANGED: idx_users_last_seen + idx_members_user
SELECT u.user_id, u.display_name, u.last_seen_at
FROM users u
WHERE u.last_seen_at < '2026-04-01'
  AND EXISTS (SELECT 1 FROM chat_members cm JOIN chats c ON c.chat_id = cm.chat_id
              WHERE cm.user_id = u.user_id AND c.chat_type = 'GROUP' AND cm.left_at IS NULL)
ORDER BY u.last_seen_at;

-- @R19
-- Group health report: for every group, the last message time and messages in June 2026
-- REWRITTEN: two correlated subqueries per group became one grouped pass over messages, joined to the groups.
-- coalesce keeps the original behaviour of 0 for groups with no messages.
SELECT c.chat_id, c.group_name,
       m.last_message_at,
       coalesce(m.june_messages, 0) AS june_messages
FROM chats c
LEFT JOIN (
    SELECT chat_id,
           max(sent_at) AS last_message_at,
           count(*) FILTER (WHERE sent_at >= '2026-06-01') AS june_messages
    FROM messages
    GROUP BY chat_id
) m ON m.chat_id = c.chat_id
WHERE c.chat_type = 'GROUP'
ORDER BY m.last_message_at DESC NULLS LAST;

-- @R20
-- Capacity planning: messages per hour of the day, by message type
-- UNCHANGED: idx_messages_sent_at covers sent_at and message_type (index-only scan)
SELECT EXTRACT(HOUR FROM sent_at) AS hour, message_type, count(*) AS messages
FROM messages
GROUP BY 1, 2
ORDER BY 1, 2;

-- @R21
-- Product analytics: share of messages edited or deleted, per message type
-- UNCHANGED: whole-table aggregate, a full scan is already the cheapest plan
SELECT message_type,
       count(*) AS messages,
       round(100.0 * count(*) FILTER (WHERE edited_at IS NOT NULL) / count(*), 2) AS edited_pct,
       round(100.0 * count(*) FILTER (WHERE is_deleted) / count(*), 2) AS deleted_pct
FROM messages
GROUP BY message_type
ORDER BY messages DESC;

-- @R22
-- Trust & safety console: all messages, newest first, page 4,001 (25 per page)
-- REWRITTEN: skip the first 100,000 rows using only the primary-key index, then fetch the 25 full rows
SELECT m.message_id, m.chat_id, m.sender_id, m.message_type, m.sent_at
FROM messages m
WHERE m.message_id IN (
    SELECT message_id
    FROM messages
    ORDER BY message_id DESC
    OFFSET 100000
    LIMIT 25
)
ORDER BY m.message_id DESC;

-- @R23
-- Security: linked WEB/DESKTOP devices unused since 1 June 2026 (to auto log out)
-- UNCHANGED: idx_devices_web_desktop_active
SELECT d.device_id, d.user_id, d.device_type, d.last_active_at
FROM devices d
WHERE d.device_type IN ('WEB', 'DESKTOP')
  AND d.last_active_at < '2026-06-01'
ORDER BY d.last_active_at;

-- @R24
-- Storage dedup: media files uploaded more than once (same SHA-256)
-- UNCHANGED: whole-table aggregate, a full scan is already the cheapest plan
SELECT sha256, count(*) AS copies, sum(size_bytes) AS total_bytes
FROM media
GROUP BY sha256
HAVING count(*) > 1
ORDER BY copies DESC;

-- @R25
-- Reply thread: walk up the chain of replies starting at message 119989
-- UNCHANGED: primary-key lookups
WITH RECURSIVE thread AS (
    SELECT message_id, reply_to_message_id, sender_id, body, 0 AS depth
    FROM messages WHERE message_id = 119989
    UNION ALL
    SELECT m.message_id, m.reply_to_message_id, m.sender_id, m.body, t.depth + 1
    FROM messages m JOIN thread t ON m.message_id = t.reply_to_message_id
)
SELECT * FROM thread ORDER BY depth DESC;

-- @W01
-- Send a text message in group 22556
-- UNCHANGED: now also maintains the new messages indexes
INSERT INTO messages (message_id, chat_id, sender_id, sent_at, message_type, body)
VALUES (90000001, 22556, 965, '2026-07-01 09:00:00+05:30', 'TEXT', 'Good morning everyone');

-- @W02
-- Open chat: mark all of user 965's unread messages in group 22556 as read
-- UNCHANGED: idx_receipts_unread finds the rows, idx_messages_chat_sent filters by chat
UPDATE message_receipts r
SET read_at = TIMESTAMPTZ '2026-07-01 09:05:00+05:30',
    delivered_at = coalesce(r.delivered_at, TIMESTAMPTZ '2026-07-01 09:05:00+05:30')
FROM messages m
WHERE m.message_id = r.message_id
  AND m.chat_id = 22556
  AND r.user_id = 965
  AND r.read_at IS NULL;

-- @W03
-- "Delete for everyone" on message 119989
-- UNCHANGED: primary-key update
UPDATE messages
SET is_deleted = TRUE, body = NULL, media_id = NULL
WHERE message_id = 119989;

-- @W04
-- Broadcast: create delivery receipts for 5,000 recipients of a business announcement
-- UNCHANGED: now also maintains the two partial receipt indexes
INSERT INTO message_receipts (message_id, user_id)
SELECT 1, g
FROM generate_series(2, 5001) AS g
ON CONFLICT (message_id, user_id) DO NOTHING;

-- @W05
-- User 965 leaves group 20898
-- UNCHANGED: primary-key update
UPDATE chat_members
SET left_at = TIMESTAMPTZ '2026-07-01 10:00:00+05:30'
WHERE chat_id = 20898 AND user_id = 965 AND left_at IS NULL;

-- @END
ROLLBACK;
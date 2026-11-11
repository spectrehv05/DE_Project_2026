# CP2 Baseline Timings

Baseline measured with PostgreSQL 18.6 (Postgres.app) on a MacBook Pro
(Mac16,1, Apple M4, 16 GB RAM, macOS 26.6).

Each run is the `Execution Time` from the corresponding raw plan. Averages are
from `benchmarks/results/baseline/summary.csv`. The total row sums the 30
individual run times and the 30 reported averages.

## 1. Timings

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Chats screen: user 965's chats with the time and text of the latest message, newest first | READ | 15.083 | 12.767 | 13.274 | 13.708 |
| R02: Open a chat: the latest 50 messages of group 22556 | READ | 3.532 | 3.373 | 3.133 | 3.346 |
| R03: Badge counts: unread messages per chat for user 965 | READ | 8.818 | 7.232 | 7.431 | 7.827 |
| R04: Search: messages containing "meeting" in any chat user 965 belongs to | READ | 19.990 | 20.352 | 19.717 | 20.020 |
| R05: Registration: is this phone number already on WhatsApp? | READ | 0.021 | 0.021 | 0.020 | 0.021 |
| R06: Contact info: "last seen" of everyone user 965 chats with directly | READ | 0.918 | 0.970 | 0.908 | 0.932 |
| R07: Group info screen: current members of group 22556 with their role | READ | 0.101 | 0.096 | 0.093 | 0.097 |
| R08: Delivery service: receipts still not delivered for messages sent before 23:00 on 30 Jun 2026 | READ | 13.709 | 13.401 | 14.577 | 13.896 |
| R09: Storage team: top 20 users by total media uploaded (GB) | READ | 8.752 | 8.023 | 8.182 | 8.319 |
| R10: Growth: daily active senders in June 2026 | READ | 8.098 | 7.796 | 7.783 | 7.892 |
| R11: Calls tab: missed calls received by user 965 since 1 Jan 2025 | READ | 3.297 | 2.977 | 3.198 | 3.157 |
| R12: Spam detection: users who forwarded 2+ messages on the same day | READ | 5.701 | 5.615 | 5.522 | 5.613 |
| R13: Group admins: questions asked in group 20501 that nobody has replied to | READ | 19.157 | 19.115 | 19.026 | 19.099 |
| R14: Engagement: 10 groups with the most distinct senders in June 2026 | READ | 5.762 | 5.978 | 6.195 | 5.978 |
| R15: Before delivering: has user 3064 blocked user 17793? | READ | 0.022 | 0.022 | 0.020 | 0.021 |
| R16: Message info screen: who has read message 119989 and when | READ | 0.059 | 0.057 | 0.086 | 0.067 |
| R17: Product analytics: average minutes from sending to reading, per message type (June 2026) | READ | 16.020 | 15.727 | 15.739 | 15.829 |
| R18: Clean-up: users not seen since April 2026 who are still in at least one group | READ | 14.820 | 15.019 | 14.630 | 14.823 |
| R19: Group health report: for every group, the last message time and messages in June 2026 | READ | 16928.357 | 15485.902 | 15519.869 | 15978.043 |
| R20: Capacity planning: messages per hour of the day, by message type | READ | 44.020 | 43.879 | 43.684 | 43.861 |
| R21: Product analytics: share of messages edited or deleted, per message type | READ | 12.281 | 12.053 | 12.134 | 12.156 |
| R22: Trust & safety console: all messages, newest first, page 4,001 (25 per page) | READ | 8.752 | 8.767 | 8.685 | 8.735 |
| R23: Security: linked WEB/DESKTOP devices unused since 1 June 2026 (to auto log out) | READ | 3.285 | 3.390 | 3.470 | 3.382 |
| R24: Storage dedup: media files uploaded more than once (same SHA-256) | READ | 6.845 | 6.453 | 7.033 | 6.777 |
| R25: Reply thread: walk up the chain of replies starting at message 119989 | READ | 0.052 | 0.052 | 0.070 | 0.058 |
| W01: Send a text message in group 22556 | WRITE | 0.606 | 0.438 | 0.443 | 0.496 |
| W02: Open chat: mark all of user 965's unread messages in group 22556 as read | WRITE | 3.430 | 3.407 | 3.294 | 3.377 |
| W03: "Delete for everyone" on message 119989 | WRITE | 0.119 | 0.127 | 0.115 | 0.120 |
| W04: Broadcast: create delivery receipts for 5,000 recipients of a business announcement | WRITE | 26.522 | 26.336 | 42.453 | 31.770 |
| W05: User 965 leaves group 20898 | WRITE | 0.166 | 0.129 | 0.151 | 0.149 |
| **Total (sum of all 30)** | | **17178.295** | **15729.474** | **15780.935** | **16229.569** |

## 2. Scan types and observations

Scan types below are taken from the raw plan files. Multiple scan nodes are
separated by semicolons.

| Query | Scan type | Why it is slow or fast |
|---|---|---|
| R01 | Index Scan using chat_members_pkey on chat_members; Index Scan using chats_pkey on chats; Seq Scan on messages | The lateral latest-message lookup repeatedly scans messages for each matching chat. |
| R02 | Seq Scan on messages | Scans the messages table to find the chat's rows, then selects the latest 50. |
| R03 | Seq Scan on message_receipts; Index Scan using messages_pkey on messages | Filters receipts by user and read status with a full receipt scan; message joins use the primary key. |
| R04 | Seq Scan on messages; Index Only Scan using chat_members_pkey on chat_members | The leading-wildcard text search requires checking message bodies; chat membership uses its primary key. |
| R05 | Index Scan using users_phone_e164_key on users | The unique phone-number lookup is selective and uses its index. |
| R06 | Index Only Scan using chat_members_pkey on chat_members; Index Scan using chats_pkey on chats; Index Scan using users_pkey on users | The relevant memberships, chats, and users are found through primary-key indexes. |
| R07 | Index Scan using chat_members_pkey on chat_members; Index Scan using users_pkey on users | The specific chat's memberships and corresponding users are looked up using indexes. |
| R08 | Seq Scan on messages; Seq Scan on message_receipts | Both relations are scanned to apply the time and undelivered-receipt filters. |
| R09 | Seq Scan on media | All media rows must be read and grouped to calculate per-uploader totals. |
| R10 | Seq Scan on messages | Scans messages and groups June activity by date and sender. |
| R11 | Index Only Scan using chat_members_pkey on chat_members; Seq Scan on calls | Finds the user's memberships by index but scans calls for missed-call and date conditions. |
| R12 | Seq Scan on messages | Reads messages to filter forwarded rows and group by sender and day. |
| R13 | Seq Scan on messages | Scans messages and the subquery's reply targets; `NOT IN` is null-sensitive, and the subquery contains NULL reply targets. |
| R14 | Seq Scan on messages; Seq Scan on chats | Scans messages and chats before filtering June activity and aggregating group senders. |
| R15 | Index Only Scan using blocked_users_pkey on blocked_users | The composite primary key efficiently checks this blocker/blocked pair. |
| R16 | Index Scan using message_receipts_pkey on message_receipts; Index Scan using users_pkey on users | The target message's receipts and recipient user rows are retrieved by indexes. |
| R17 | Seq Scan on message_receipts; Seq Scan on messages | Reads receipts and messages to find June reads and calculate per-type averages. |
| R18 | Seq Scan on chat_members; Seq Scan on chats; Seq Scan on users | Full scans support the group-membership existence test and last-seen filter. |
| R19 | Seq Scan on chats; Seq Scan on messages | Correlated aggregates repeatedly scan messages per group, making this the slowest query. |
| R20 | Seq Scan on messages | Every message is grouped by hour and type; the full-table aggregate dominates. |
| R21 | Seq Scan on messages | Reads all messages to calculate per-type totals and percentages. |
| R22 | Index Scan using messages_pkey on messages | The primary-key index supplies descending order, but OFFSET still skips 100,000 rows. |
| R23 | Seq Scan on devices | Scans devices to apply the type and last-active filters. |
| R24 | Seq Scan on media | Reads all media to group duplicate hashes and sum file sizes. |
| R25 | Index Scan using messages_pkey on messages | The thread's message-id lookups use the primary-key index. |
| W01 | No scan node | Inserts one message row; there is no source-table scan. |
| W02 | Seq Scan on messages; Index Scan using message_receipts_pkey on message_receipts | Finds matching messages by scanning messages, then updates matching receipts by primary-key lookup. |
| W03 | Index Scan using messages_pkey on messages | Updates one message selected by its primary key. |
| W04 | No scan node | Generates 5,000 recipient rows and inserts receipts; the plan has no table scan node. |
| W05 | Index Scan using chat_members_pkey on chat_members | Updates the user's membership row using the composite primary key. |

## 3. Baseline observations

- R19 is substantially slower than the other queries because its correlated
  aggregates scan messages repeatedly for each group.
- R13 returns **0 rows**. Its `NOT IN` subquery selects `reply_to_message_id`,
  which contains NULL values; SQL's NULL semantics make the `NOT IN` predicate
  unknown for candidate rows.
- Selective primary-key and unique-key lookups (for example R05, R15, and R16)
  are among the fastest reads; full-table filtering and aggregation are slower.
- W04 inserts many rows and has higher runtime variability than the single-row
  writes.

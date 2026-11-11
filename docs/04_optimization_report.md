# CP3 Optimization Report

Measured on the same setup as the CP2 baseline: PostgreSQL 18.6 (Postgres.app) on a MacBook Pro
(Mac16,1, Apple M4, 16 GB RAM, macOS 26.6), database `wa_project`, schema `whatsapp`.

- Baseline: `benchmarks/results/baseline/summary.csv` (unmodified `queries/workload_30.sql`, no indexes).
- Optimized: `benchmarks/results/optimized/summary.csv` (`sql/06_optimized_queries.sql` after `sql/05_indexes.sql`).
- Each figure is the average `Execution Time` of 3 runs of `EXPLAIN (ANALYZE, BUFFERS)`.
  Raw plans of every run are in the two `results/` folders.

## 1. Result in one line

The sum of the 30 average times fell from **16,229.6 ms to 161.4 ms**, about **100x faster**. Most of the
gain comes from R19, which went from 15,978 ms to 14.9 ms (about 1,075x). Without R19 the baseline total
is 251.5 ms, so the other 29 queries together (251.5 ms before, 146.6 ms after) are about 1.7x faster.

## 2. Timings

| Query | Type | Baseline avg (ms) | Optimized avg (ms) | Speedup | Change made |
|---|---|---:|---:|---:|---|
| R01 | READ | 13.708 | 0.069 | 199x | Index |
| R02 | READ | 3.346 | 0.092 | 36x | Index |
| R03 | READ | 7.827 | 0.132 | 59x | Index |
| R04 | READ | 20.020 | 0.153 | 131x | Index |
| R05 | READ | 0.021 | 0.023 | 1.0x | None (already a unique-key lookup) |
| R06 | READ | 0.932 | 0.112 | 8.3x | Index |
| R07 | READ | 0.097 | 0.121 | 0.8x | None (already primary-key lookups; difference is noise) |
| R08 | READ | 13.896 | 5.489 | 2.5x | Index |
| R09 | READ | 8.319 | 8.210 | 1.0x | None (whole-table aggregate) |
| R10 | READ | 7.892 | 1.442 | 5.5x | Query rewrite + index |
| R11 | READ | 3.157 | 0.045 | 70x | Query rewrite + index |
| R12 | READ | 5.613 | 1.111 | 5.1x | Index |
| R13 | READ | 19.099 | 0.089 | 215x | Query rewrite + index |
| R14 | READ | 5.978 | 2.566 | 2.3x | Index |
| R15 | READ | 0.021 | 0.022 | 1.0x | None (already a primary-key lookup) |
| R16 | READ | 0.067 | 0.056 | 1.2x | None (already primary-key lookups) |
| R17 | READ | 15.829 | 14.152 | 1.1x | Index (little effect) |
| R18 | READ | 14.823 | 13.767 | 1.1x | Index (little effect) |
| R19 | READ | 15978.043 | 14.852 | 1076x | Query rewrite |
| R20 | READ | 43.861 | 42.457 | 1.0x | None (whole-table aggregate) |
| R21 | READ | 12.156 | 11.853 | 1.0x | None (whole-table aggregate) |
| R22 | READ | 8.735 | 4.647 | 1.9x | Query rewrite |
| R23 | READ | 3.382 | 1.711 | 2.0x | Partial index |
| R24 | READ | 6.777 | 6.228 | 1.1x | None (whole-table aggregate) |
| R25 | READ | 0.058 | 0.056 | 1.0x | None (already primary-key lookups) |
| W01 | WRITE | 0.496 | 0.564 | 0.9x | None (slightly slower: index maintenance) |
| W02 | WRITE | 3.377 | 0.320 | 10.6x | Index |
| W03 | WRITE | 0.120 | 0.125 | 1.0x | None |
| W04 | WRITE | 31.770 | 30.815 | 1.0x | None |
| W05 | WRITE | 0.149 | 0.168 | 0.9x | None |
| **Total (sum of 30 averages)** | | **16,229.569** | **161.447** | **100.5x** | |

## 3. Indexes added (`sql/05_indexes.sql`)

| Index | Definition | Serves |
|---|---|---|
| `idx_messages_chat_sent` | `messages (chat_id, sent_at DESC)` | R01, R02, R04, R13, W02 |
| `idx_messages_sent_at` | `messages (sent_at) INCLUDE (chat_id, sender_id, message_type)` | R08, R10, R14, R17 |
| `idx_messages_forwarded` | `messages (sender_id, sent_at) WHERE is_forwarded` | R12 |
| `idx_messages_reply_to` | `messages (reply_to_message_id) WHERE reply_to_message_id IS NOT NULL` | R13 |
| `idx_receipts_unread` | `message_receipts (user_id, message_id) WHERE read_at IS NULL` | R03, W02 |
| `idx_receipts_undelivered` | `message_receipts (message_id) WHERE delivered_at IS NULL` | R08 |
| `idx_members_user` | `chat_members (user_id) INCLUDE (chat_id, left_at)` | R01, R04, R06, R11 |
| `idx_calls_missed` | `calls (chat_id, started_at DESC) WHERE status = 'MISSED'` | R11 |
| `idx_users_last_seen` | `users (last_seen_at)` | R18 |
| `idx_devices_web_desktop_active` | `devices (last_active_at) WHERE device_type IN ('WEB','DESKTOP')` | R23 |

Why these work:

- The primary keys of `chat_members` and `message_receipts` start with `chat_id` and `message_id`, so they
  cannot find rows by `user_id`. `idx_members_user` and `idx_receipts_unread` fix that.
- `messages` had no index on `chat_id`, so every "one chat" query (R01, R02, R13, W02) scanned the table.
- Partial indexes only store the rows a query needs (unread, undelivered, missed, forwarded), so they are
  small and cheap to keep up to date.
- `INCLUDE` columns let R10 and R14 run as index-only scans without reading the table.
- After creating the indexes the script runs `VACUUM (ANALYZE)` on every table, which refreshes statistics
  and the visibility map so the planner can use index-only scans.

## 4. Query rewrites (`sql/06_optimized_queries.sql`)

| Query | Problem in the original | Rewrite |
|---|---|---|
| R19 | Two correlated subqueries ran once per group, scanning `messages` each time (15.98 s) | One grouped pass over `messages` (`max(sent_at)` and a `FILTER` count), joined to `chats`; `coalesce` keeps the 0 for groups with no messages |
| R10 | `sent_at::date BETWEEN ...` hides the column behind a cast, so no index can be used | Plain range `sent_at >= '2026-06-01' AND sent_at < '2026-07-01'` |
| R11 | `EXTRACT(YEAR FROM started_at) >= 2025` also hides the column | `started_at >= '2025-01-01'` |
| R22 | `OFFSET 100000` reads 100,000 full rows before returning 25 | The subquery skips the 100,000 rows using only the primary-key index, then fetches the 25 full rows |
| R13 | `NOT IN` over a column containing NULLs returns no rows at all | `NOT EXISTS` |

The rewrites of R10, R11, R19 and R22 were compared with the original queries on a test copy of the
schema and return the same rows.

**R13 changes the result, on purpose.** The original returned 0 rows because `reply_to_message_id` contains
NULLs, and `x NOT IN (..., NULL)` is never true. The query was meant to find questions nobody replied to,
so `NOT EXISTS` returns that answer. This is a bug fix, not a pure speed-up, and the baseline report already
noted the 0-row result.

## 5. What did not improve, and why

- **R09, R20, R21, R24** aggregate every row of `media` or `messages`. A sequential scan is already the
  cheapest plan, so no index was added for them.
- **R17, R18** gain about 10%. R17 must read the receipts of every June message. R18 must check
  memberships of many users. Both read a large share of their tables either way.
- **R05, R07, R15, R16, R25** were already primary-key or unique-key lookups, taking under 0.13 ms.

## 6. Cost of the indexes on writes

Indexes make reads faster and writes slightly slower, because every insert or update must also update them.
W01 went from 0.496 to 0.564 ms and W05 from 0.149 to 0.168 ms, both well below a millisecond. W04
(5,000 receipt inserts) stayed at about 31 ms. W02 got 10x faster because it can now find the user's unread
receipts through `idx_receipts_unread`.

A GIN trigram index on `messages.body` (`pg_trgm`) was tried for R04's `ILIKE '%meeting%'`. After the
benchmark, `pg_stat_user_indexes` showed it had 0 scans, because R04 already runs in 0.15 ms using
`idx_members_user` and `idx_messages_chat_sent`, and it made W01, W03 and W04 slower (W03 rose from 0.12 to
0.55 ms). It was dropped, and the benchmark was run again to produce the final figures above.

## 7. How to reproduce

```
psql -d wa_project -f sql/05_indexes.sql
./benchmarks/run_benchmark.sh wa_project optimized 3 sql/06_optimized_queries.sql
```
# CP4 Scalability Report

> **Status:** sections 5 (architecture for 100×), 7 and 8 are complete. Sections 1 to 4 and 6 need the numbers
> from the large-dataset run. Every place that still needs your numbers is marked **TODO**. Remove this box and
> every TODO marker before the final commit. Do not type any timing by hand: generate the tables from the
> committed `summary.csv` files (section 8), so each number matches the raw plans.

## 0. Environment

- PostgreSQL 18.6 (Postgres.app), MacBook Pro Apple M4, 16 GB RAM (same machine as CP2 and CP3, see `team.json`)
- Seed database: `whatsapp_db` (120,000 messages). Large database: `whatsapp_large` (about 2,400,000 messages)
- Queries run: the **optimized** workload, `sql/06_optimized_queries.sql`, after `sql/05_indexes.sql` and `ANALYZE`
- Every value is the average Execution Time of 3 runs (`benchmarks/run_benchmark.sh`)
- Raw plans and `summary.csv`: `benchmarks/results/large/`; seed numbers: `benchmarks/results/optimized/`

Dataset sizes (from the project brief):

| Table | Seed rows | Large rows (about) | Factor |
|-------|----------:|-------------------:|-------:|
| messages | 120,000 | 2,400,000 | 20× |
| message_receipts | 501,590 | 10,032,000 | 20× |
| users | | 600,000 | 20× |
| chats | | 460,000 | 20× |

## 1. Results table

**TODO:** run `python3 benchmarks/make_scale_table.py` after the large benchmark and paste its output here.
For every row that says **No**, fill the last column with what you changed (see section 3).

## 2. Growth analysis

**TODO:** paste the "Growth groups" lines produced by `make_scale_table.py`, then keep, correct or delete each
explanation below so that it matches your real numbers. The first column is what the seed plans lead us to
expect (a hypothesis, to be confirmed or refuted by the large run).

| Group | Why it should happen | Queries expected here (from the seed plans) |
|-------|----------------------|---------------------------------------------|
| **Stayed about the same** | The query does a few primary-key or index lookups. An index lookup grows with log n: 20× the rows adds roughly one extra level of the B-tree. | R05, R07, R15, R16, R25, W03, W05 (primary-key or unique lookups); R02 and R22 (`LIMIT` bounds the work: R02 reads 50 index entries, R22 skips a fixed 100,000 rows) |
| **Grew about 20×** | The query reads a fixed *share* of a table, so 20× the rows means 20× the pages. | R09, R20, R21, R24 (full scans, see the "not indexed on purpose" note in `05_indexes.sql`); R10, R12, R14, R17, R19 (a month or all rows of `messages`); R18 (scan of `chat_members`) |
| **Grew more than 20×** | Usually a plan change: the planner stops using the plan that was good on small data (for example a sort that no longer fits `work_mem` and spills to disk, or a hash that is split into batches). | **TODO:** list whatever the data shows. Candidates to check first: R08, R17, R19, R18 |

Note on per-user queries (R01, R03, R04, R06, R11): the large data has 20× the users **and** 20× the chats, so one
user's own data should stay about the same size. Their time should grow far less than 20×. If one does, look at
the plan for the reason.

## 3. What broke at scale

**TODO:** for every query that missed its target (section 5.2 of the README), use this template. Show the plan
before and after the fix, copied from `benchmarks/results/large/<ID>.txt`, and quote the numbers from there.

```
### Rxx: <one line: what the query does>
- Target: <n> ms. Measured on large data: <n> ms (avg of 3, from benchmarks/results/large/summary.csv)
- Why (from the plan): <for example "Sort Method: external merge Disk: 48000kB", "Seq Scan replaced Index Scan", "Heap Fetches: 900000">
- Fix: <index / rewrite / setting, with the exact SQL>
- After: <n> ms, plan excerpt
```

Things worth checking in the large plans, because they only appear at scale:

1. **`Sort Method: external merge`** or hash `Batches: > 1`: the work no longer fits in `work_mem`. Try
   `SET work_mem = '64MB'` for that query and show the plan again.
2. **`Heap Fetches` high on an Index Only Scan** (R10, R14, R20): the visibility map is out of date. Run
   `VACUUM (ANALYZE) messages;` after the load. This is why `05_indexes.sql` ends with `VACUUM (ANALYZE)`.
3. **Parallel workers**: a plan with `Gather` may be faster than the seed plan. Report it, it is not a problem.
4. **R22 (keyset / offset)**: the optimized version keeps `OFFSET 100000`, so it still skips exactly 100,000 index
   entries on large data. If you changed to keyset pagination, state how the "last seen" `message_id` is chosen
   for the large data.
5. **W04** (5,000-row broadcast insert): it maintains two partial indexes and the primary key; check that the
   large data did not turn it into a slow `ON CONFLICT` check.

## 4. Storage

**TODO:** run this on both databases and fill the table.

```sql
SELECT pg_size_pretty(pg_database_size(current_database())) AS database_total;

SELECT relname AS table_name,
       pg_size_pretty(pg_table_size(oid))   AS table_only,
       pg_size_pretty(pg_indexes_size(oid)) AS indexes,
       pg_size_pretty(pg_total_relation_size(oid)) AS total
FROM pg_class
WHERE relkind = 'r' AND relnamespace = 'public'::regnamespace
ORDER BY pg_total_relation_size(oid) DESC;
```

| Table | Seed: table | Seed: indexes | Large: table | Large: indexes | Large ÷ seed |
|-------|------------:|--------------:|-------------:|---------------:|-------------:|
| message_receipts | | | | | |
| messages | | | | | |
| chat_members | | | | | |
| *(other tables)* | | | | | |
| **Database total** | | | | | |

Comment on: whether storage grew about 20× (it should, since it is proportional to the rows), which table
dominates (`message_receipts` has about 4 rows per message, so it is the biggest), and how much of the total
the indexes of `05_indexes.sql` take. The two `INCLUDE` / partial indexes on `messages` are the ones to look at.

## 5. Architecture for 100×

100× the seed is about **12 million messages** and **50 million receipts** (501,590 × 100), roughly 5× the large
dataset. The seed numbers below come from `benchmarks/results/optimized/summary.csv`. Anything marked
*(projection)* is simple arithmetic on those numbers, not a measurement, and the large run (section 1) should be
used to confirm or correct it.

### 5.1 Partitioning: `messages`, RANGE on `sent_at`, one partition per month

**Choice.** `messages` is partitioned `BY RANGE (sent_at)` with monthly partitions. DDL: `sql/08_partitioning.sql`
(creates `messages_partitioned` beside the original table so the CP2/CP3 results stay reproducible).

**Why `messages`, and why `sent_at`.**

- `messages` is the table most of the workload touches. Five queries filter on a time range (R08, R10, R14, R17, and
  R19 for its June count), and the time range is the natural way to cut the table. Others (R12, R20, R21) read all
  of it and gain nothing from pruning, which is stated honestly in section 5.1 below.
- At 100× a month holds about 12,000,000 / 18 ≈ **670,000 rows** (the seed has about 6,600 per month), so a one-month
  query reads one partition instead of the whole table.
- Archiving: `DETACH PARTITION` removes a whole month instantly. The alternative, `DELETE ... WHERE sent_at < ...`,
  on a table this size takes a long time and leaves dead rows that need VACUUM.
- Writes (W01) go to the newest partition only, so the hot part of the index stays small and stays in memory.

**Why not LIST or HASH.**

- LIST would need a fixed set of values; time has none, and a new month would mean redefining the list.
- HASH on `chat_id` would make R02 (one chat's history) a one-partition query, but it gives no pruning for any
  time-range query and no way to archive by age. It is the better choice only if the workload were dominated by R02.
  The workload is not: R02 is already 0.135 ms on seed data with the `(chat_id, sent_at DESC)` index.

**Pruning, shown with EXPLAIN** (from running `sql/08_partitioning.sql` on the seed data; `COSTS OFF`):

```
-- R10 shape, June 2026: only one partition is in the plan
GroupAggregate
  ->  Sort
        ->  Seq Scan on messages_p2026_06 messages_partitioned
              Filter: ((sent_at >= '2026-05-31 18:30:00+00') AND (sent_at < '2026-06-30 18:30:00+00'))

-- message_id AND sent_at known: one partition, one index probe
Index Scan using messages_p2026_06_pkey on messages_p2026_06 messages_partitioned
  Index Cond: ((message_id = 119989) AND (sent_at >= ...) AND (sent_at < ...))
```

For a query on `chat_id` alone (R02 shape) or on `message_id` alone (R16, R25, W03 shape) there is **no pruning**:
the plan has one index scan per partition (24 partitions plus the default one in the script). So partitioning is
a clear win for time-range queries and a small loss for single-row lookups, because each lookup now probes every
partition's index. This is the main trade-off, and the reason partitioning is proposed for the 100× design and
not applied to the benchmarked tables.

**TODO:** save your own run of the script as evidence and quote its timings:

```bash
psql -d whatsapp_large -f sql/08_partitioning.sql > benchmarks/results/large/partitioning_explain.txt 2>&1
```

Then add one small table (original vs partitioned, Execution Time of R10, R14 and R02 shapes, average of 3) taken
from that file. Do not use any other source for these numbers.

**The primary-key rule.** On a partitioned table every `PRIMARY KEY` or `UNIQUE` constraint must contain the
partition key. So `PRIMARY KEY (message_id)` becomes `PRIMARY KEY (message_id, sent_at)`. Consequences:

1. `message_receipts.message_id` and `messages.reply_to_message_id` can no longer be foreign keys to `messages`,
   because a foreign key needs a unique constraint on `message_id` alone. They stay as plain integer columns
   whose validity is checked by the application (or a trigger). This is a real loss of integrity and must be
   accepted knowingly.
2. `message_id` stays unique only because it comes from one identity sequence.
3. Lookups by `message_id` alone still use the primary-key index (it starts with `message_id`) but probe every
   partition. Callers that also know the message time (for example from the chat screen) should pass `sent_at`.

**Other table.** `message_receipts` (about 50 million rows at 100×, the biggest table) is a second candidate. Its
access paths are by `user_id` (R03, W02) and by `message_id` (R16). A HASH partitioning on `user_id` would help R03 and
W02. It is not written as DDL here, because the same primary-key rule applies (`PRIMARY KEY (message_id, user_id)`
already contains `user_id`, so it would work without changing the key).

### 5.2 Sharding

**Recommendation: shard `messages` by `chat_id`.** One conversation then lives on one shard.

| Query | Shard by `chat_id` | Shard by `sender_id` | Shard by recipient (`user_id`) |
|-------|--------------------|----------------------|--------------------------------|
| R02 open a chat (latest 50) | one shard | all shards (senders are mixed) | all shards (the chat's messages are spread over its members' shards) |
| R01 a user's chat list | scatter: the user's chats are on different shards | scatter | one shard if the chat-list rows live with the user |
| W01 send a message | one shard | one shard | one write per recipient shard (fan-out, expensive for groups) |
| R13 replies in one group | one shard | all shards | all shards |

Reasons: R02 and W01 are the most frequent operations in a messaging app and both are single-chat operations.
Sharding by sender breaks R02, since a chat's messages come from many senders. Sharding by recipient makes
R01 and R03 cheap, but every message in a group of N members would be written N times, and group chats are
a large part of this dataset.

**What becomes cross-shard, and the fix.**

- **R01 (chat list) and R06 (contacts' last seen):** keep a small per-user table `user_inbox(user_id, chat_id,
  last_message_at, last_body_preview, unread_count)`, sharded by `user_id` and updated when a message is sent
  (W01). R01 becomes one lookup on one shard instead of a fan-out over all of a user's chats. The cost: W01 now
  also updates the inbox row of each member (asynchronously through a queue is acceptable).
- **R03 (unread per chat), W02:** `message_receipts` joins `messages` only to find the chat. Copy `chat_id` into
  the receipt row and shard receipts by `user_id`. Then both queries are single-shard with no join.
- **R04 (search "meeting" across all of a user's chats):** scatter-gather across shards, or better, a separate
  full-text search index. `ILIKE '%meeting%'` cannot use a B-tree on any shard.
- **R15 (is X blocked by Y), R05 (phone lookup), `users`:** small and read often. Keep `blocked_users` as a
  *reference table copied to every shard*; keep `users` on its own `user_id` shard map with a phone-to-user lookup
  directory.
- **R09, R10, R12, R14, R17 to R21, R24 (analytics):** these touch all shards by nature. Run them on a
  replica or a warehouse copy, never on the shards that serve users (see 5.3).

### 5.3 Read replicas and caching

Writes (W01 to W05) always go to the primary. For reads, the question is whether slightly stale data is acceptable.

| Where | Queries | Why |
|-------|---------|-----|
| **Primary** | R05 (registration: two sign-ups must not both succeed), R08 (delivery service needs the current undelivered list), R15 (block check must be correct before delivering), R02 and R01 *right after the user sent a message* (read-your-writes) | Stale data gives a wrong result, not just an old one |
| **Replica** | R02 and R01 otherwise, R07, R13, R16, R25 (message info, thread), R11, R22 (trust and safety console), R23 | Reads of data that changes slowly or where a lag of a second does not matter |
| **Replica or warehouse only** | R09, R10, R12, R14, R17, R18, R19, R20, R21, R24 | Long scans (seed: R20 89.5 ms, R17 25.2 ms, R19 31.3 ms; about 20× longer on large data *(projection)*). They would compete with user traffic for I/O and cache on the primary |
| **Cache (Redis or similar)** | R03 badge counts (invalidate on W02 and on every new receipt), R06 last-seen (a few seconds old is fine), R07 group member list (invalidate on W05), R15 (cache, invalidate when a block changes) | Tiny, extremely frequent, tolerant of short staleness; the 5 ms target for these cannot depend on a disk read |

The 5 ms user-facing target is the reason for the cache column: R01, R03 and R06 are the most expensive of
the real-time group on the seed data (0.318, 0.191 and 0.217 ms), and they are the ones that grow if one user has
many chats.

### 5.4 Maintenance

- **Autovacuum on the big tables.** The default `autovacuum_vacuum_scale_factor` is 0.2, meaning VACUUM waits until
  20% of the rows are dead. On a 12-million-row table that is 2.4 million dead rows. Use per-table settings, for
  example `ALTER TABLE messages_partitioned SET (autovacuum_vacuum_scale_factor = 0.02, autovacuum_analyze_scale_factor = 0.01);`.
  `message_receipts` needs the same: W02 updates `read_at` on many rows.
- **Insert-triggered vacuum and the visibility map.** `messages` is mostly appended. Index-only scans (R10, R14, R20)
  are fast only when the visibility map is current, which autovacuum updates after inserts (the
  `autovacuum_vacuum_insert_*` settings). After each large load run `VACUUM (ANALYZE)`.
- **Old partitions are never updated again**, so after a month is closed run `VACUUM (FREEZE, ANALYZE)` on it once.
  Autovacuum then has nothing to do on 17 of the 18 partitions.
- **Archiving.** Keep the last N months (for example 12) in the live database. `DETACH PARTITION` an older month,
  dump it to cold storage, `DROP` it. Instant, no bloat. Check the DEFAULT partition is empty each month.
- **Creating partitions.** Create next month's partition ahead of time (a monthly scheduled job, snippet in
  `08_partitioning.sql`). Create only a few months ahead: with the 6 empty future partitions of the script,
  a `chat_id`-only query already plans 24 index scans, and each empty partition still costs planning time.
- **Summary tables.** R10 (daily active senders), R20 (messages per hour and type) and R21 (edited/deleted share) read
  the whole table or a month of it each time. Keep a rollup `daily_message_stats(day, message_type, hour, messages,
  active_senders)` as a materialized view refreshed hourly (`REFRESH MATERIALIZED VIEW CONCURRENTLY`, which needs a
  unique index) and point the dashboards at it. R20 is the largest seed number (89.5 ms) and would be about
  9 s at 100× *(projection)*, above its 5 s target. A rollup makes it constant.
- **Statistics.** After partitioning, run `ANALYZE` on the parent as well as the partitions; autovacuum does not
  analyze the parent table of a partitioned table.

## 6. Conclusion

**TODO:** write this last, from your real results. Suggested structure:

1. How many of the 30 queries met their target on the large data (from section 1), and which ones did not and why.
2. Is the database ready for 20× growth: yes if the real-time group is under 5 ms, and the report queries under 5 s.
3. Remaining risks, based on section 5: (a) full-table reports (R20, R21, R24) grow linearly and will cross the
   5 s target before 100× unless a summary table is added; (b) single-row lookups by `message_id` get more
   expensive with partitioning, and two foreign keys are lost; (c) `message_receipts` is the biggest table and is
   not yet partitioned; (d) everything above was measured on one laptop, not on a production server.

## 7. Files for this checkpoint

| File | Purpose |
|------|---------|
| `docs/05_scalability_report.md` | this report |
| `sql/08_partitioning.sql` | partitioned `messages_partitioned`, pruning demos, maintenance snippets |
| `benchmarks/results/large/summary.csv` and `*.txt` | raw plans and averages of the 30 optimized queries on large data |
| `benchmarks/make_scale_table.py` | builds the results and growth tables from the two `summary.csv` files |

## 8. How to reproduce

```bash
# 1. large database (do not commit large_data/, it is in .gitignore)
createdb whatsapp_large
psql -d whatsapp_large -f sql/01_schema.sql
psql -d whatsapp_large -f sql/02_load_data.sql        # edit only the folder name: seed_data -> large_data
psql -d whatsapp_large -f sql/05_indexes.sql          # ends with VACUUM (ANALYZE)

# 2. the 30 optimized queries, 3 runs each (do NOT run the original 30 on large data)
./benchmarks/run_benchmark.sh whatsapp_large large 3 sql/06_optimized_queries.sql

# 3. tables for the report
python3 benchmarks/make_scale_table.py

# 4. partitioning evidence
psql -d whatsapp_large -f sql/08_partitioning.sql > benchmarks/results/large/partitioning_explain.txt 2>&1
```

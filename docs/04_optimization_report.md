# CP3 Optimization Report

## Environment

- PostgreSQL 18.6, Postgres.app, MacBook Pro Apple M4, 16 GB RAM
- Database: `whatsapp_db`; schema: `public`
- Baseline: original `queries/workload_30.sql`, without tuning indexes
- Optimized: `sql/05_indexes.sql` + `sql/06_optimized_queries.sql`
- Each value is average Execution Time across 3 benchmark runs

## 1. Overall result

- Baseline total: **440.373 ms**
- Optimized total: **336.755 ms**
- Aggregate reduction: **23.5%**
- These totals are sums of query averages, not end-to-end workload latency.

## 2. Query-wise comparison

| Query | Baseline (ms) | Optimized (ms) | Change |
|---|---:|---:|---:|
| R01 | 3.915 | 0.318 | +91.9% |
| R02 | 0.161 | 0.135 | +16.1% |
| R03 | 1.236 | 0.191 | +84.5% |
| R04 | 2.137 | 0.289 | +86.5% |
| R05 | 0.044 | 0.042 | +4.5% |
| R06 | 2.078 | 0.217 | +89.6% |
| R07 | 0.479 | 0.212 | +55.7% |
| R08 | 26.678 | 11.007 | +58.7% |
| R09 | 17.360 | 16.489 | +5.0% |
| R10 | 15.556 | 3.589 | +76.9% |
| R11 | 2.408 | 0.264 | +89.0% |
| R12 | 11.114 | 2.535 | +77.2% |
| R13 | 21.690 | 0.446 | +97.9% |
| R14 | 11.317 | 4.897 | +56.7% |
| R15 | 0.204 | 0.045 | +77.9% |
| R16 | 0.248 | 0.112 | +54.8% |
| R17 | 27.356 | 25.244 | +7.7% |
| R18 | 29.149 | 28.884 | +0.9% |
| R19 | 18.380 | 31.304 | -70.3% |
| R20 | 87.759 | 89.517 | -2.0% |
| R21 | 24.846 | 23.437 | +5.7% |
| R22 | 17.670 | 9.548 | +46.0% |
| R23 | 6.797 | 3.932 | +42.2% |
| R24 | 13.869 | 13.341 | +3.8% |
| R25 | 0.111 | 0.108 | +2.7% |
| W01 | 1.539 | 1.074 | +30.2% |
| W02 | 3.721 | 0.612 | +83.6% |
| W03 | 0.226 | 0.228 | -0.9% |
| W04 | 92.007 | 68.428 | +25.6% |
| W05 | 0.318 | 0.310 | +2.5% |
| **Total** | **440.373** | **336.755** | **+23.5%** |

## 3. Index strategy

Indexes include message chat/time, message sent_at with INCLUDE columns, forwarded-message partial index, reply reference partial index, unread and undelivered receipt indexes, membership-by-user index, missed-call partial index, last-seen index, and active WEB/DESKTOP device partial index. See `sql/05_indexes.sql` for exact definitions.

## 4. Query rewrites

- R10: replaced date cast with timestamp range predicates.
- R11: replaced EXTRACT on timestamp with a range predicate.
- R13: replaced NULL-sensitive NOT IN with NOT EXISTS; this corrects the original query's semantics.
- R19: replaced repeated correlated aggregates with a grouped messages pass. The original June filter has no upper date bound, and that behavior was preserved.
- R22: uses the primary-key index for the large offset subquery.

## 5. Interpretation

- Most selective read queries improved substantially after indexing or rewriting.
- R19 regressed by 70.3%; R20 regressed by 2.0% in this run. These should be discussed honestly rather than presented as universal improvements.
- Whole-table aggregates such as R09, R20, R21, and R24 still need to process large portions of their tables; indexes may not help.
- Indexes add write-maintenance cost, although write timings should be interpreted query by query.
- Results are specific to this dataset, machine, PostgreSQL version, and three-run sample.

## 6. Reproduction

```bash
psql -d whatsapp_db -f sql/05_indexes.sql
./benchmarks/run_benchmark.sh whatsapp_db baseline 3
./benchmarks/run_benchmark.sh whatsapp_db optimized 3 sql/06_optimized_queries.sql
```

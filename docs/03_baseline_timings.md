# CP2: Baseline Timings
Each workload query was executed three times using EXPLAIN ANALYZE.
Timings represent PostgreSQL Execution Time in milliseconds.
| Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Scan Nodes |
|---|---|---:|---:|---:|---:|---|
| R01 | READ | 7.168 | 2.320 | 2.258 | 3.915 | Index Scan using chat_members_pkey on chat_members \| Index Scan using chats_pkey on chats \| Index Scan using idx_messages_chat_sent on messages |
| R02 | READ | 0.205 | 0.139 | 0.138 | 0.161 | Bitmap Heap Scan on messages \| Bitmap Index Scan on idx_messages_chat_sent |
| R03 | READ | 3.170 | 0.279 | 0.259 | 1.236 | Bitmap Heap Scan on message_receipts \| Bitmap Index Scan on idx_receipts_user \| Index Scan using messages_pkey on messages |
| R04 | READ | 2.181 | 2.115 | 2.116 | 2.137 | Index Only Scan using chat_members_pkey on chat_members \| Bitmap Heap Scan on messages \| Bitmap Index Scan on idx_messages_chat_sent |
| R05 | READ | 0.050 | 0.040 | 0.042 | 0.044 | Index Scan using users_phone_e164_key on users |
| R06 | READ | 2.079 | 1.999 | 2.157 | 2.078 | Index Only Scan using chat_members_pkey on chat_members \| Index Scan using chats_pkey on chats \| Index Scan using users_pkey on users |
| R07 | READ | 1.010 | 0.215 | 0.212 | 0.479 | Index Scan using chat_members_pkey on chat_members \| Index Scan using users_pkey on users |
| R08 | READ | 30.669 | 24.787 | 24.577 | 26.678 | Seq Scan on messages \| Seq Scan on message_receipts |
| R09 | READ | 17.965 | 17.275 | 16.840 | 17.360 | Seq Scan on media |
| R10 | READ | 15.504 | 15.698 | 15.465 | 15.556 | Seq Scan on messages |
| R11 | READ | 3.052 | 2.096 | 2.076 | 2.408 | Index Only Scan using chat_members_pkey on chat_members \| Bitmap Heap Scan on calls \| Bitmap Index Scan on idx_calls_chat |
| R12 | READ | 11.039 | 11.086 | 11.217 | 11.114 | Seq Scan on messages |
| R13 | READ | 21.767 | 21.994 | 21.310 | 21.690 | Bitmap Heap Scan on messages \| Bitmap Index Scan on idx_messages_chat_sent \| Seq Scan on messages |
| R14 | READ | 11.369 | 11.355 | 11.227 | 11.317 | Seq Scan on messages \| Seq Scan on chats |
| R15 | READ | 0.527 | 0.042 | 0.042 | 0.204 | Index Only Scan using blocked_users_pkey on blocked_users |
| R16 | READ | 0.525 | 0.102 | 0.116 | 0.248 | Index Scan using message_receipts_pkey on message_receipts \| Index Scan using users_pkey on users |
| R17 | READ | 28.087 | 26.598 | 27.382 | 27.356 | Seq Scan on message_receipts \| Seq Scan on messages |
| R18 | READ | 29.312 | 29.308 | 28.828 | 29.149 | Seq Scan on chat_members \| Seq Scan on chats \| Seq Scan on users |
| R19 | READ | 28.414 | 13.451 | 13.274 | 18.380 | Seq Scan on chats \| Index Only Scan using idx_messages_chat_sent on messages |
| R20 | READ | 87.898 | 87.645 | 87.733 | 87.759 | Seq Scan on messages |
| R21 | READ | 24.896 | 25.239 | 24.403 | 24.846 | Seq Scan on messages |
| R22 | READ | 17.966 | 17.297 | 17.748 | 17.670 | Index Scan using messages_pkey on messages |
| R23 | READ | 7.075 | 6.312 | 7.003 | 6.797 | Seq Scan on devices |
| R24 | READ | 13.698 | 14.033 | 13.875 | 13.869 | Seq Scan on media |
| R25 | READ | 0.110 | 0.110 | 0.114 | 0.111 | Index Scan using messages_pkey on messages |
| W01 | WRITE | 2.373 | 0.862 | 1.381 | 1.539 | (no scan) |
| W02 | WRITE | 9.599 | 0.899 | 0.666 | 3.721 | Bitmap Heap Scan on messages \| Bitmap Index Scan on idx_messages_chat_sent \| Index Scan using message_receipts_pkey on message_receipts |
| W03 | WRITE | 0.229 | 0.227 | 0.221 | 0.226 | Index Scan using messages_pkey on messages |
| W04 | WRITE | 80.643 | 60.853 | 134.525 | 92.007 | (no scan) |
| W05 | WRITE | 0.425 | 0.233 | 0.295 | 0.318 | Index Scan using chat_members_pkey on chat_members |

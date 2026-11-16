
# Schema Design – WhatsApp Messaging Database

## 1. Overview

The database is designed in PostgreSQL using nine tables: users, chats, chat_members, messages, message_receipts, media, calls, devices and blocked_users. The design separates user profiles, conversations, messages, media metadata and operational records to maintain integrity and reduce redundancy.

## 2. Relational Schema

### 2.1 Users

| Column | Data Type | Constraints |
|---|---|---|
| user_id | INTEGER | Primary Key |
| phone_e164 | VARCHAR(20) | NOT NULL, UNIQUE |
| display_name | VARCHAR(100) | NOT NULL |
| about | TEXT | NULL |
| is_business | BOOLEAN | NOT NULL |
| joined_on | DATE | NOT NULL |
| last_seen_at | TIMESTAMPTZ | NULL |
| status | VARCHAR(20) | NOT NULL |

### 2.2 Chats

| Column | Data Type | Constraints |
|---|---|---|
| chat_id | INTEGER | Primary Key |
| chat_type | VARCHAR(20) | NOT NULL |
| group_name | VARCHAR(100) | NULL |
| created_by | INTEGER | NOT NULL, FK → users.user_id |
| created_at | TIMESTAMPTZ | NOT NULL |

### 2.3 Chat Members

| Column | Data Type | Constraints |
|---|---|---|
| chat_id | INTEGER | PK, FK → chats.chat_id |
| user_id | INTEGER | PK, FK → users.user_id |
| role | VARCHAR(20) | NOT NULL |
| joined_at | TIMESTAMPTZ | NOT NULL |
| left_at | TIMESTAMPTZ | NULL |
| is_muted | BOOLEAN | NOT NULL |

Primary Key: (chat_id, user_id)

### 2.4 Messages

| Column | Data Type | Constraints |
|---|---|---|
| message_id | INTEGER | Primary Key |
| chat_id | INTEGER | NOT NULL, FK → chats.chat_id |
| sender_id | INTEGER | NOT NULL, FK → users.user_id |
| sent_at | TIMESTAMPTZ | NOT NULL |
| message_type | VARCHAR(20) | NOT NULL |
| body | TEXT | NULL |
| media_id | INTEGER | NULL, FK → media.media_id |
| reply_to_message_id | INTEGER | NULL, self-referencing FK |
| is_forwarded | BOOLEAN | NOT NULL |
| is_deleted | BOOLEAN | NOT NULL |
| edited_at | TIMESTAMPTZ | NULL |

### 2.5 Message Receipts

| Column | Data Type | Constraints |
|---|---|---|
| message_id | INTEGER | PK, FK → messages.message_id |
| user_id | INTEGER | PK, FK → users.user_id |
| delivered_at | TIMESTAMPTZ | NULL |
| read_at | TIMESTAMPTZ | NULL |

Primary Key: (message_id, user_id)

### 2.6 Media

| Column | Data Type | Constraints |
|---|---|---|
| media_id | INTEGER | Primary Key |
| uploader_id | INTEGER | NOT NULL, FK → users.user_id |
| media_type | VARCHAR(30) | NOT NULL |
| mime_type | VARCHAR(100) | NULL |
| size_bytes | BIGINT | NOT NULL |
| sha256 | CHAR(64) | NULL |
| uploaded_at | TIMESTAMPTZ | NOT NULL |

### 2.7 Calls

| Column | Data Type | Constraints |
|---|---|---|
| call_id | INTEGER | Primary Key |
| chat_id | INTEGER | NOT NULL, FK → chats.chat_id |
| caller_id | INTEGER | NOT NULL, FK → users.user_id |
| call_type | VARCHAR(20) | NOT NULL |
| started_at | TIMESTAMPTZ | NOT NULL |
| answered_at | TIMESTAMPTZ | NULL |
| ended_at | TIMESTAMPTZ | NULL |
| status | VARCHAR(20) | NOT NULL |

### 2.8 Devices

| Column | Data Type | Constraints |
|---|---|---|
| device_id | INTEGER | Primary Key |
| user_id | INTEGER | NOT NULL, FK → users.user_id |
| device_type | VARCHAR(20) | NOT NULL |
| app_version | VARCHAR(30) | NULL |
| registered_at | TIMESTAMPTZ | NOT NULL |
| last_active_at | TIMESTAMPTZ | NULL |

### 2.9 Blocked Users

| Column | Data Type | Constraints |
|---|---|---|
| blocker_id | INTEGER | PK, FK → users.user_id |
| blocked_id | INTEGER | PK, FK → users.user_id |
| blocked_at | TIMESTAMPTZ | NOT NULL |

Primary Key: (blocker_id, blocked_id)

## 3. Relationships and Cardinality

- Users to Chats: 1:N (creator relationship).
- Users to Chat Members: 1:N.
- Chats to Chat Members: 1:N.
- Users to Chats: M:N through chat_members.
- Chats to Messages: 1:N.
- Users to Messages: 1:N (sender relationship).
- Messages to Message Receipts: 1:N.
- Users to Message Receipts: 1:N.
- Users to Media: 1:N (uploader relationship).
- Media to Messages: 1:N (optional association).
- Messages to Messages: 1:N (reply relationship).
- Chats to Calls: 1:N.
- Users to Calls: 1:N (caller relationship).
- Users to Devices: 1:N.
- Users to Blocked Users: 1:N as blocker and 1:N as blocked user.

## 4. NULL and NOT NULL Decisions

- Required identifiers, timestamps and relationship columns are NOT NULL.
- Optional profile description and last-seen timestamp may be NULL.
- group_name is NULL for direct chats and populated for groups.
- left_at is NULL while membership is active.
- body may be NULL for media-only messages.
- media_id is NULL for text-only messages.
- reply_to_message_id is NULL for messages without replies.
- delivered_at and read_at remain NULL until delivery/read events occur.
- answered_at and ended_at may be NULL for unanswered or ongoing calls.
- edited_at is NULL until a message is edited.
- last_active_at and app_version may be unavailable for some devices.
- sha256 and mime_type may be unavailable in media metadata.

## 5. Referential Integrity and ON DELETE Policies

| Relationship | ON DELETE | Reason |
|---|---|---|
| chats.created_by → users | RESTRICT | Prevent deletion of a user who created a chat |
| chat_members.chat_id → chats | CASCADE | Remove memberships when a chat is deleted |
| chat_members.user_id → users | RESTRICT | Preserve users referenced by membership |
| messages.chat_id → chats | CASCADE | Remove messages belonging to a deleted chat |
| messages.sender_id → users | RESTRICT | Preserve sender references |
| messages.media_id → media | SET NULL | Preserve messages if media metadata is deleted |
| messages.reply_to_message_id → messages | SET NULL | Preserve replies if the referenced message is deleted |
| message_receipts.message_id → messages | CASCADE | Remove receipts with their message |
| message_receipts.user_id → users | RESTRICT | Preserve receipt recipient references |
| media.uploader_id → users | RESTRICT | Preserve uploader references |
| calls.chat_id → chats | CASCADE | Remove calls belonging to a deleted chat |
| calls.caller_id → users | RESTRICT | Preserve caller references |
| devices.user_id → users | CASCADE | Remove devices when an account is deleted |
| blocked_users.blocker_id → users | CASCADE | Remove blocking records when blocker is deleted |
| blocked_users.blocked_id → users | CASCADE | Remove blocking records when blocked account is deleted |

## 6. Integrity Constraints

The database uses primary keys, foreign keys, unique constraints, NOT NULL constraints and CHECK constraints.

Planned CHECK constraints include:

1. Phone numbers follow E.164 format.
2. User status belongs to an allowed set.
3. Chat type is DIRECT or GROUP.
4. Direct chats have no group name.
5. Group chats have a group name.
6. Member role belongs to an allowed set.
7. Membership end time is after join time.
8. Message type belongs to an allowed set.
9. Text messages contain a body.
10. Edited time is not earlier than message time.
11. Media size is non-negative.
12. SHA-256 hashes contain 64 hexadecimal characters.
13. Read time is not earlier than delivery time.
14. Call type is VOICE or VIDEO.
15. Call answer time is not earlier than start time.
16. Call end time is not earlier than start time.
17. Device type belongs to an allowed set.
18. A user cannot block themselves.

Allowed values for enum-like fields will be confirmed against the supplied CSV data before implementation.

## 7. Normalization

### First Normal Form (1NF)

All attributes contain atomic values. Repeating groups such as chat participants and receipts are stored in separate relations.

### Second Normal Form (2NF)

Tables with composite keys contain attributes dependent on the complete key. In chat_members, role, joined_at, left_at and is_muted depend on (chat_id, user_id). In message_receipts, delivery and read timestamps depend on (message_id, user_id).

### Third Normal Form (3NF)

Non-key attributes depend on their table's primary key and not on other non-key attributes. User profile data is stored separately from chat and message records.

### Functional Dependencies

- user_id → phone_e164, display_name, about, is_business, joined_on, last_seen_at, status
- chat_id → chat_type, group_name, created_by, created_at
- (chat_id, user_id) → role, joined_at, left_at, is_muted
- message_id → chat_id, sender_id, sent_at, message_type, body, media_id, reply_to_message_id, is_forwarded, is_deleted, edited_at
- (message_id, user_id) → delivered_at, read_at
- media_id → uploader_id, media_type, mime_type, size_bytes, sha256, uploaded_at
- call_id → chat_id, caller_id, call_type, started_at, answered_at, ended_at, status
- device_id → user_id, device_type, app_version, registered_at, last_active_at
- (blocker_id, blocked_id) → blocked_at

The schema is designed to avoid storing derived values such as unread counts, group member counts and call duration when they can be calculated from base records.

## 8. ER Diagram

The ER diagram will represent all nine tables, their primary/foreign keys and relationship cardinalities.

Mermaid source and the rendered ER diagram image are maintained under the diagrams/ directory.

## 9. Data Dictionary

| Table | Description |
|---|---|
| users | User profile, registration and account status |
| chats | Direct and group conversation metadata |
| chat_members | User participation and membership history |
| messages | Message content, metadata and reply relationships |
| message_receipts | Per-user message delivery and read status |
| media | Uploaded media metadata and integrity information |
| calls | Voice/video call lifecycle records |
| devices | Registered user devices and activity |
| blocked_users | Directed user blocking relationships |

Primary Key: (chat_id, user_id)

### Messages
Stores messages sent within chats.

- message_id – Primary Key
- chat_id – Foreign Key referencing Chats
- sender_id – Foreign Key referencing Users
- sent_at – Message timestamp
- message_type – Type of message
- body – Message text
- media_id – Optional Foreign Key referencing Media
- reply_to_message_id – Optional self-referencing Foreign Key
- is_forwarded – Forwarded message indicator
- is_deleted – Deletion indicator
- edited_at – Optional editing timestamp

### Message Receipts
Stores message delivery and read information.

- message_id – Foreign Key referencing Messages
- user_id – Foreign Key referencing Users
- delivered_at – Delivery timestamp
- read_at – Read timestamp

Primary Key: (message_id, user_id)

### Media
Stores metadata for uploaded media.

- media_id – Primary Key
- uploader_id – Foreign Key referencing Users
- media_type – Media category
- mime_type – MIME type
- size_bytes – File size
- sha256 – File hash
- uploaded_at – Upload timestamp

### Calls
Stores voice and video call information.

- call_id – Primary Key
- chat_id – Foreign Key referencing Chats
- caller_id – Foreign Key referencing Users
- call_type – Voice or video
- started_at – Start timestamp
- answered_at – Optional answer timestamp
- ended_at – End timestamp
- status – Call status

### Devices
Stores devices registered by users.

- device_id – Primary Key
- user_id – Foreign Key referencing Users
- device_type – Device category
- app_version – Application version
- registered_at – Registration timestamp
- last_active_at – Last activity timestamp

### Blocked Users
Stores user blocking relationships.

- blocker_id – Foreign Key referencing Users
- blocked_id – Foreign Key referencing Users
- blocked_at – Blocking timestamp

Primary Key: (blocker_id, blocked_id)





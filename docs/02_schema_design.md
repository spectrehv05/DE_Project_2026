# Schema Design – WhatsApp Messaging Database

## 1. Overview

The database consists of nine relational tables designed to represent the core functionality of a WhatsApp-like messaging system.

## 2. Tables and Attributes

### Users
Stores user profile and account information.

- user_id – Primary Key
- phone_e164 – Phone number in international format
- display_name – Display name
- about – Profile description
- is_business – Business account indicator
- joined_on – Account creation date
- last_seen_at – Last activity timestamp
- status – Account status

### Chats
Stores direct and group conversations.

- chat_id – Primary Key
- chat_type – Type of chat
- group_name – Group name
- created_by – Foreign Key referencing Users
- created_at – Creation timestamp

### Chat Members
Stores membership information for conversations.

- chat_id – Foreign Key referencing Chats
- user_id – Foreign Key referencing Users
- role – Member role
- joined_at – Membership start timestamp
- left_at – Membership end timestamp
- is_muted – Indicates whether the chat is muted

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

## 3. Relationships

- One user can create multiple chats.
- One chat can have multiple members.
- One user can participate in multiple chats.
- One chat can contain multiple messages.
- One user can send multiple messages.
- One message can have multiple receipts.
- One user can receive multiple message receipts.
- One user can upload multiple media files.
- One message can optionally reference media.
- One message can optionally reply to another message.
- One chat can have multiple calls.
- One user can make multiple calls.
- One user can register multiple devices.
- One user can block multiple users and be blocked by multiple users.

## 4. Integrity Constraints

- Primary keys uniquely identify records.
- Foreign keys maintain referential integrity.
- Composite primary keys prevent duplicate membership, receipt, and blocking relationships.
- Optional attributes may contain NULL values.
- Boolean attributes represent binary states.
- Timestamps use TIMESTAMPTZ to preserve timezone information.

## 5. Data Dictionary
| Table | Description |
|---|---|
| users | User profile and account data |
| chats | Conversation metadata |
| chat_members | Chat participation and membership details |
| messages | Messages exchanged in chats |
| message_receipts | Delivery and read status |
| media | Uploaded media metadata |
| calls | Voice and video call records |
| devices | Registered devices |
| blocked_users | Blocking relationships |


## 6. Detailed Integrity Constraints

### 6.1 Primary Keys and Unique Constraints
| Table | Constraint | Columns | Purpose |
|---|---|---|---|
| users | PRIMARY KEY | user_id | Uniquely identifies each user |
| users | UNIQUE | phone_e164 | Prevents duplicate phone numbers |
| chats | PRIMARY KEY | chat_id | Uniquely identifies each chat |
| media | PRIMARY KEY | media_id | Uniquely identifies media |
| chat_members | PRIMARY KEY | (chat_id, user_id) | Prevents duplicate membership |
| messages | PRIMARY KEY | message_id | Uniquely identifies messages |
| message_receipts | PRIMARY KEY | (message_id, user_id) | One receipt per user per message |
| calls | PRIMARY KEY | call_id | Uniquely identifies calls |
| devices | PRIMARY KEY | device_id | Uniquely identifies devices |
| blocked_users | PRIMARY KEY | (blocker_id, blocked_id) | Prevents duplicate blocking relationships |

### 6.2 Foreign Key Constraints
| Table | Column | References | Purpose |
|---|---|---|---|
| chats | created_by | users(user_id) | Chat creator must exist |
| media | uploader_id | users(user_id) | Media uploader must exist |
| chat_members | chat_id | chats(chat_id) | Membership must belong to an existing chat |
| chat_members | user_id | users(user_id) | Member must be an existing user |
| messages | chat_id | chats(chat_id) | Message must belong to an existing chat |
| messages | sender_id | users(user_id) | Sender must exist |
| messages | media_id | media(media_id) | Referenced media must exist |
| messages | reply_to_message_id | messages(message_id) | Replied message must exist |
| message_receipts | message_id | messages(message_id) | Receipt must belong to an existing message |
| message_receipts | user_id | users(user_id) | Receipt user must exist |
| calls | chat_id | chats(chat_id) | Call must belong to an existing chat |
| calls | caller_id | users(user_id) | Caller must exist |
| devices | user_id | users(user_id) | Device owner must exist |
| blocked_users | blocker_id | users(user_id) | Blocker must exist |
| blocked_users | blocked_id | users(user_id) | Blocked user must exist |

### 6.3 CHECK Constraints
| Constraint | Table | Rule |
|---|---|---|
| ck_users_phone | users | Phone number follows international E.164-style format |
| ck_users_status | users | Status is ACTIVE, BANNED, or DELETED |
| ck_chats_type | chats | Chat type is DIRECT or GROUP |
| ck_chats_group_name | chats | GROUP chats have a group name; DIRECT chats do not |
| size_bytes CHECK | media | File size cannot be negative |
| ck_media_type | media | Media type is IMAGE, VIDEO, AUDIO, or DOCUMENT |
| ck_media_sha256 | media | SHA-256 is NULL or 64 lowercase hexadecimal characters |
| ck_members_role | chat_members | Role is ADMIN or MEMBER |
| ck_members_time | chat_members | left_at cannot precede joined_at |
| ck_messages_type | messages | Message type is TEXT, IMAGE, VIDEO, AUDIO, DOCUMENT, or LOCATION |
| ck_messages_media | messages | TEXT and LOCATION messages cannot reference media |
| ck_messages_edit | messages | edited_at cannot precede sent_at |
| ck_messages_noself | messages | A message cannot reply to itself |
| ck_messages_deleted | messages | Deleted messages cannot retain body text |
| ck_receipts_order | message_receipts | Read time requires delivery time and cannot precede it |
| ck_calls_type | calls | Call type is VOICE or VIDEO |
| ck_calls_status | calls | Status is COMPLETED, MISSED, REJECTED, or FAILED |
| ck_calls_time | calls | Answer time cannot precede start; end time cannot precede answer |
| ck_devices_type | devices | Device type is ANDROID, IOS, WEB, or DESKTOP |
| ck_devices_version | devices | App version is NULL or follows major.minor.patch format |
| CHECK | blocked_users | A user cannot block themselves |


## 7. Column-Level Data Dictionary

Notation: PK = Primary Key, FK = Foreign Key, UQ = Unique, NN = NOT NULL.

### 7.1 Users
| Column | Data Type | Null | Key / Default |
|---|---|---|---|
| user_id | INTEGER | NN | PK, Identity |
| phone_e164 | VARCHAR(20) | NN | UQ |
| display_name | VARCHAR(100) | NN | |
| about | TEXT | Yes | |
| is_business | BOOLEAN | NN | DEFAULT FALSE |
| joined_on | DATE | NN | |
| last_seen_at | TIMESTAMPTZ | Yes | |
| status | VARCHAR(20) | NN | |

### 7.2 Chats
| Column | Data Type | Null | Key / Default |
|---|---|---|---|
| chat_id | INTEGER | NN | PK, Identity |
| chat_type | VARCHAR(20) | NN | |
| group_name | VARCHAR(100) | Yes | |
| created_by | INTEGER | NN | FK → users(user_id) |
| created_at | TIMESTAMPTZ | NN | |

### 7.3 Media
| Column | Data Type | Null | Key / Default |
|---|---|---|---|
| media_id | INTEGER | NN | PK, Identity |
| uploader_id | INTEGER | NN | FK → users(user_id) |
| media_type | VARCHAR(30) | NN | |
| mime_type | VARCHAR(100) | Yes | |
| size_bytes | BIGINT | NN | CHECK >= 0 |
| sha256 | CHAR(64) | Yes | |
| uploaded_at | TIMESTAMPTZ | NN | |

### 7.4 Chat Members
| Column | Data Type | Null | Key / Default |
|---|---|---|---|
| chat_id | INTEGER | NN | PK, FK → chats(chat_id) |
| user_id | INTEGER | NN | PK, FK → users(user_id) |
| role | VARCHAR(20) | NN | |
| joined_at | TIMESTAMPTZ | NN | |
| left_at | TIMESTAMPTZ | Yes | |
| is_muted | BOOLEAN | NN | DEFAULT FALSE |

### 7.5 Messages
| Column | Data Type | Null | Key / Default |
|---|---|---|---|
| message_id | INTEGER | NN | PK, Identity |
| chat_id | INTEGER | NN | FK → chats(chat_id) |
| sender_id | INTEGER | NN | FK → users(user_id) |
| sent_at | TIMESTAMPTZ | NN | |
| message_type | VARCHAR(20) | NN | |
| body | TEXT | Yes | |
| media_id | INTEGER | Yes | FK → media(media_id) |
| reply_to_message_id | INTEGER | Yes | FK → messages(message_id) |
| is_forwarded | BOOLEAN | NN | DEFAULT FALSE |
| is_deleted | BOOLEAN | NN | DEFAULT FALSE |
| edited_at | TIMESTAMPTZ | Yes | |

### 7.6 Message Receipts
| Column | Data Type | Null | Key / Default |
|---|---|---|---|
| message_id | INTEGER | NN | PK, FK → messages(message_id) |
| user_id | INTEGER | NN | PK, FK → users(user_id) |
| delivered_at | TIMESTAMPTZ | Yes | |
| read_at | TIMESTAMPTZ | Yes | |

### 7.7 Calls
| Column | Data Type | Null | Key / Default |
|---|---|---|---|
| call_id | INTEGER | NN | PK, Identity |
| chat_id | INTEGER | NN | FK → chats(chat_id) |
| caller_id | INTEGER | NN | FK → users(user_id) |
| call_type | VARCHAR(20) | NN | |
| started_at | TIMESTAMPTZ | NN | |
| answered_at | TIMESTAMPTZ | Yes | |
| ended_at | TIMESTAMPTZ | Yes | |
| status | VARCHAR(20) | NN | |

### 7.8 Devices
| Column | Data Type | Null | Key / Default |
|---|---|---|---|
| device_id | INTEGER | NN | PK, Identity |
| user_id | INTEGER | NN | FK → users(user_id) |
| device_type | VARCHAR(20) | NN | |
| app_version | VARCHAR(30) | Yes | |
| registered_at | TIMESTAMPTZ | NN | |
| last_active_at | TIMESTAMPTZ | Yes | |

### 7.9 Blocked Users
| Column | Data Type | Null | Key / Default |
|---|---|---|---|
| blocker_id | INTEGER | NN | PK, FK → users(user_id) |
| blocked_id | INTEGER | NN | PK, FK → users(user_id) |
| blocked_at | TIMESTAMPTZ | NN | |


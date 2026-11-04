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


# Problem Understanding – WhatsApp Messaging Database

<<<<<<< HEAD
## 1. Introduction

WhatsApp is a messaging platform that allows users to communicate through individual chats and group conversations. Users can send text messages, share media, make voice or video calls, manage devices, receive message delivery and read receipts, and block other users.

This project aims to design a relational database that represents the core messaging functionality of WhatsApp.

## 2. Problem Statement

The objective is to develop a structured relational database capable of storing and managing WhatsApp-like messaging data while maintaining data integrity, minimizing redundancy, and supporting efficient retrieval of information.

## 3. Objectives

- Store user profiles and account information.
- Maintain direct and group chat information.
- Track chat participants, roles, and membership status.
- Store messages, including text, media, forwarded, deleted, and edited messages.
- Maintain message delivery and read receipts.
- Store uploaded media metadata.
- Record voice and video call information.
- Maintain registered user devices.
- Manage user blocking relationships.
- Enforce relationships using primary keys and foreign keys.

## 4. Scope

The database covers the following entities:

1. Users
2. Chats
3. Chat Members
4. Messages
5. Message Receipts
6. Media
7. Calls
8. Devices
9. Blocked Users

The database stores media metadata rather than the actual media files.

## 5. Assumptions

- Every user is uniquely identified by a user ID.
- A chat may be direct or group-based.
- A user can participate in multiple chats.
- A chat can contain multiple messages.
- Messages may optionally reference media or another message as a reply.
- Message receipts represent delivery and read information for individual users.
- A user can register multiple devices.
- Blocking is represented as a relationship between two users.
- Timestamps are stored with timezone information wherever applicable.

## 6. Expected Outcome

A relational database implemented in PostgreSQL that supports the storage and management of messaging data, maintains referential integrity, and enables future querying and performance analysis.
=======
## Context and Objective
WhatsApp's messaging database supports user accounts, linked devices, direct/group chats, messages, media, replies, forwarding, editing, deletion, receipts, calls and blocking. The project reconstructs a relational schema from CSV exports, enforces data integrity and supports efficient real-time operations and analytics.

## Business Problems and Stakeholders

| ID | Business Need | Stakeholder | Classification |
|---|---|---|---|
| P1 | Retrieve latest message and unread count for each chat quickly. | Users / Mobile app | Customer-facing / Real-time |
| P2 | Fetch group history efficiently while opening and scrolling busy groups. | Users / Mobile app | Customer-facing / Real-time |
| P3 | Enable fast message search and read-information lookup. | Users / Mobile app | Customer-facing / Real-time |
| P4 | Quickly validate phone registration, last seen and blocking status. | Identity / Privacy | Customer-facing / Real-time |
| P5 | Process pending delivery receipts and read updates efficiently. | Delivery service | Customer-facing / Real-time |
| P6 | Generate accurate unanswered-question reports for group admins. | Group administrators | Reporting / Analytics |
| P7 | Investigate spam and forwarding activity efficiently. | Trust & Safety | Reporting / Analytics |
| P8 | Identify heavy uploaders and duplicate media to reduce storage costs. | Storage team | Reporting / Analytics |
| P9 | Analyse DAU, read times, edits/deletes, group health and hourly load at 20× message volume. | Product analytics | Reporting / Analytics |
| P10 | Identify stale devices, inactive users, missed calls and users who left groups for cleanup. | Security / Platform | Customer-facing / Real-time |

## Scope
The database covers nine entities: Users, Devices, Chats, Chat Members, Messages, Message Receipts, Media, Calls and Blocked Users. It stores media metadata rather than media files.

## Assumptions
- CSV exports are the authoritative source for schema reconstruction.
- Phone numbers are unique registration identifiers.
- Direct chats have two participants; groups can have multiple participants.
- Message content may include text, media or both.
- Delivery/read timestamps may remain NULL until the respective event occurs.
- Membership history is represented through joined and left timestamps.
- Media files are stored externally.
- Performance changes must preserve workload query results.
- The schema must accommodate future message-volume growth.

## Expected Outcome
A PostgreSQL relational database with documented relationships, integrity constraints and efficient support for operational and analytical workloads.
>>>>>>> 06e3b43 (Complete CP1 schema constraints and database validation)

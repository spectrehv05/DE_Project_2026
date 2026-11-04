# Problem Understanding – WhatsApp Messaging Database

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
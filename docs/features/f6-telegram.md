# F6: Telegram

## Description

A per-Space Telegram bot that lets linked users chat with Meddie, upload medical documents, and check biomarker results — all from Telegram. Each Space has its own bot (configured by the Space admin). The bot reuses the same AI context building, conversation storage, person resolution, and memory auto-population as F5 Ask Meddie.

## Bot Setup & Configuration

### One bot per Space

Each Space admin creates a Telegram bot via [@BotFather](https://t.me/BotFather) and enters the token in **Space Settings → Telegram tab**. This allows different Spaces (e.g., families, clinics) to have their own isolated bot.

- Bot token stored on `spaces` table: `telegram_bot_token` (string, nullable, encrypted at rest)
- When an admin saves a bot token, the system starts polling for that bot
- When an admin removes the token, polling stops

### Polling architecture

The bot uses **long polling** (not webhooks) to receive updates from Telegram. Elixir's concurrency model makes this natural and efficient.

```
Application
  └── Meddie.Telegram.Supervisor (DynamicSupervisor)
        ├── Meddie.Telegram.Poller (Space A — bot token abc123)
        ├── Meddie.Telegram.Poller (Space B — bot token def456)
        └── ...
```

- `Meddie.Telegram.Supervisor` — DynamicSupervisor that manages one Poller per active Space
- `Meddie.Telegram.Poller` — GenServer per Space. Long-polls Telegram's `getUpdates` API, dispatches each update to `Meddie.Telegram.Handler`
- On application start, all Spaces with a `telegram_bot_token` get a Poller started
- When a Space admin saves/removes a bot token, the corresponding Poller is started/stopped dynamically
- Polling disabled in test environment

### Poller lifecycle

```
1. Application boots → Telegram.Supervisor starts
2. Supervisor queries all Spaces with telegram_bot_token
3. For each → starts a Poller GenServer with {space_id, bot_token}
4. Poller calls getUpdates(offset: last_update_id + 1, timeout: 30)
5. For each update → spawns Task via Telegram.Handler.handle(update, space)
6. Loop back to step 4
```

## User Linking & Access Control

### Telegram Links

Telegram identities are stored in a dedicated `telegram_links` table (not on the `users` table). Each link maps a Telegram user ID to a Space, with optional User and Person associations. This allows Telegram users to interact with the bot **without needing a Meddie account**.

### Linking flow

1. Space admin goes to **Space Settings → Telegram integration tab**
2. Below the bot token field, a "Telegram Links" section shows existing links
3. Admin adds a new link by entering:
   - **Telegram ID** (required — the Telegram user's numeric ID)
   - **Person** (optional dropdown — links directly to a Person record)
   - **User** (optional dropdown — links to a Meddie user account)
4. Users can find their Telegram ID by using [@userinfobot](https://t.me/userinfobot) on Telegram

### Access control

- **Only Telegram IDs with a link in the Space can interact** with the bot
- When an unknown Telegram ID sends a message, the bot replies:
  > "I don't recognize your Telegram account. Please ask your Space admin to link your Telegram ID in Settings."
- The bot also shows their Telegram ID in this message so they can share it with their admin

### Scope resolution

When a message arrives on a bot:
1. Bot token → identifies the Space
2. Telegram user ID → look up `telegram_links` (by telegram_id + space_id) → identifies the Link
3. If link has `user_id` → build full Scope: `Scope.for_user(user) |> Scope.put_space(space)`
4. If link has no `user_id` → build space-only Scope: `Scope.for_space(space)`. Person is pre-resolved from `link.person_id` if set.

## Conversation Flow

### Reusing F5 infrastructure

Telegram conversations use the same `Meddie.Conversations` context module — same tables, same functions.

- `conversations.source` — new field: `"web"` (default) or `"telegram"` to distinguish origin
- Telegram conversations appear in the web UI's Ask Meddie sidebar (and vice versa) — they share the same data
- Each user has **one active Telegram conversation** per Space. New messages continue the active conversation.
- `/new` command starts a fresh conversation

### Person resolution

Same strategy as F5 — fully automatic, no manual selection needed:

1. **Single person in Space** → auto-select, no AI call
2. **Multiple people** → AI resolves from the message content via `Meddie.AI.resolve_person/2`
3. **Ambiguous** → bot asks: "Who are you asking about — Anna or Tomek?"
4. **Resolved** → person stored on conversation record, reused for subsequent messages

## Bot Commands

| Command | Description |
|---------|-------------|
| `/start` | Welcome message. If not linked, shows the user's Telegram ID so admin can add it. If linked, shows greeting with Space name. |
| `/new` | Starts a new conversation. The previous conversation remains accessible in the web UI. |
| `/help` | Lists available commands. |

All other text messages are treated as chat messages and forwarded to the AI.

## Document Upload

Users can send photos or PDF files to the bot for analysis.

### Flow

```
1. User sends photo/PDF
2. Bot asks: "Save to documents?" (inline keyboard: Yes / No)
3a. If Yes:
    - Person must be known
    - If auto-resolved → proceed
    - If ambiguous → ask "Who is this for?" (inline keyboard with person names)
    - Download file from Telegram → upload to Tigris → create Document record
    - Trigger Oban parsing job (reuses F3 pipeline)
    - Bot sends: "Document uploaded. Parsing..." → "Done! Found 12 biomarkers."
3b. If No:
    - Send image to AI vision model within the current conversation context
    - Return analysis as a chat message
    - File is not stored — one-time analysis only
```

### Reuse

- Document upload and parsing reuse the F3 pipeline entirely (`Meddie.Documents.create_document/3`, Oban worker)
- Inline analysis uses the same AI vision model as F3 but returns results as chat text instead of structured biomarkers

## AI Integration

### Context building

Reuses `Meddie.AI.Prompts` — same system prompt, person context (profile, biomarkers, health notes, medications, supplements, document summaries).

### Non-streaming responses

Telegram doesn't support streaming text updates well. The bot collects the full AI response before sending:

1. User sends message → saved to conversation
2. Bot sends "typing..." indicator via Telegram `sendChatAction`
3. AI generates full response (using `chat_stream/3` with an internal collector, or a new `chat/2` non-streaming callback)
4. Response saved as assistant message
5. Bot sends the complete response as a Telegram message

### Memory auto-population

Same as F5 — the AI detects health-relevant information and auto-saves it to the person's profile:

- Works identically: AI appends `memory_updates` JSON block, system parses and applies
- No undo button (Telegram doesn't have interactive buttons for this). Instead, the bot sends a follow-up message: "Saved to Health Notes: Hypothyroidism diagnosed 2023"
- Users can undo from the web UI (F5) if needed

### Conversation titles

Auto-generated same as F5 — after the first exchange, a fast model generates a 3–6 word title.

## Data Model

### New table: telegram_links

| Column | Type | Constraints |
|--------|------|------------|
| id | `binary_id` | PK |
| telegram_id | `bigint` | NOT NULL |
| space_id | `binary_id` | FK → spaces, NOT NULL |
| user_id | `binary_id` | FK → users, nullable |
| person_id | `binary_id` | FK → people, nullable |
| timestamps | | |

Indexes: `unique_index([:telegram_id, :space_id])`

### Changes to existing tables

**spaces** — add field:

| Column | Type | Constraints |
|--------|------|------------|
| telegram_bot_token | `string` | nullable |

**conversations** — add fields:

| Column | Type | Constraints |
|--------|------|------------|
| source | `string` | NOT NULL, default: `"web"`, values: `"web"`, `"telegram"` |
| telegram_link_id | `binary_id` | FK → telegram_links, nullable |

`user_id` is nullable on conversations (to support telegram-only links without a Meddie user).

## Settings UI — Telegram Tab

New tab in **Space Settings** (visible to admins only):

```
┌──────────────────────────────────────────────────────────────────┐
│ Space Settings                                                   │
│ [General] [Members] [Telegram]                                   │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ Bot Token                                                        │
│ ┌─────────────────────────────┐                                  │
│ │ 123456:ABC-DEF1234...       │ [Save]                           │
│ └─────────────────────────────┘                                  │
│                                                                  │
│ Telegram Links                                                   │
│                                                                  │
│ Telegram ID   Person          User            Action              │
│ ────────────────────────────────────────────────────────────────  │
│ 12345678      Anna Kowalska   anna@...        [x]                │
│ 87654321      Tomek Kowalski  —               [x]                │
│                                                                  │
│ Add Telegram Link                                                │
│ ┌──────────┐ ┌──────────────┐ ┌──────────────┐                  │
│ │ Tg ID    │ │ Person ▼     │ │ User ▼       │                  │
│ └──────────┘ └──────────────┘ └──────────────┘                  │
│                                                        [Add]     │
└──────────────────────────────────────────────────────────────────┘
```

- **Telegram ID**: required — the Telegram user's numeric ID
- **Person**: optional dropdown — links directly to a Person record (pre-resolves person for all conversations)
- **User**: optional dropdown — links to a Meddie user account (enables full Scope with user context)
- Links without a User allow Telegram-only access (no Meddie account needed)

## Rate Limiting

- Same 200 messages/day limit as F5 (already space-scoped via `Conversations.count_messages_today/1`)
- When limit reached, bot replies: "You've reached the daily message limit. Try again tomorrow."

## Edge Cases

- **Unknown Telegram ID**: bot replies with rejection message + shows user's Telegram ID for admin to add
- **User not a member of Space**: even if `telegram_id` matches a user, verify Space membership. Reject if not a member.
- **Long AI response**: split into multiple Telegram messages at 4096 character boundary (split on paragraph breaks when possible)
- **Concurrent messages while AI processing**: queue the message and process after current response completes, or reply "Please wait, I'm still thinking..."
- **Bot token removed by admin**: Poller stops. Messages sent to the bot get no response (Telegram shows "bot is not responding").
- **Bot token changed**: old Poller stops, new Poller starts with new token
- **Telegram API errors**: log error, retry once with exponential backoff, then inform user: "Something went wrong. Please try again."
- **File too large**: Telegram limits file downloads to 20MB. Reject with a message if file exceeds this.
- **Person deleted mid-conversation**: conversation continues but without person context. Bot mentions: "The person profile is no longer available."
- **Space deleted**: Poller stops, all conversations remain in DB but are inaccessible
- **Multiple Spaces with same user**: each Space has its own bot, so there's no ambiguity — the bot token identifies the Space

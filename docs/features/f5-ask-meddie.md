# F5: Ask Meddie

## Description

A conversational AI interface where users ask questions about their health data. The AI uses the person's biomarkers, health notes, supplements, medications, and document summaries as context. Conversations are private to the user who created them.

Ask Meddie is accessible from the sidebar as a full-page view, and from Person#show via an "Ask Meddie" button that pre-selects the person.

## Navigation & Entry Points

1. **Sidebar**: "Ask Meddie" nav item → `/ask-meddie` — conversation list + chat view.
2. **Person#show**: "Ask Meddie" button in the person header → `/ask-meddie/new?person_id=:id` — new conversation with person pre-selected.

## UI Layout

```
┌──────────────────────┬────────────────────────────────────┐
│ Conversations        │  [Person picker ▼]                 │
│                      │                                    │
│ • Latest results...  │  ℹ️ Disclaimer banner              │
│ • Thyroid check      │                                    │
│ • General question   │  [Message bubbles]                 │
│                      │                                    │
│                      │  [Quick question chips]             │
│                      │                                    │
│ [+ New chat]         │  [Input field]          [Send]     │
└──────────────────────┴────────────────────────────────────┘
```

### Left panel — Conversation list
- Reverse chronological, grouped by person (person name as group header, "General" for no-person conversations).
- Each row: conversation title, date, message count.
- Filter by person (dropdown or tabs).
- "New chat" button at bottom.
- **Mobile**: hidden by default, accessible via toggle button.

### Right panel — Active conversation
- **Person picker**: dropdown at top, listing all people in the current space. Optional — can be left empty for general Q&A.
- **Disclaimer banner**: persistent, subtle: "Meddie provides informational responses only. This is not medical advice."
- **Messages**: user messages (right-aligned), assistant messages (left-aligned). Markdown rendered.
- **Quick question chips**: shown when conversation is empty and a person is selected: "Summarize my latest results", "What should I watch out for?", "Explain my out-of-range values".
- **Input**: text field with Send button. Disabled while AI is streaming.
- **Streaming indicator**: typing animation while AI is responding.

## Person Picker & Intelligent Resolution

### Person picker behavior
- Dropdown at top of chat panel. Lists all people in current space.
- **Optional** — user can chat without selecting a person.
- Person is set per conversation (stored on record). Can only be changed when starting a new conversation or if no messages yet.
- When navigating from Person#show → person pre-selected via query param.

### Linked user auto-detection
- If the user has a linked person in the current space, that person is auto-suggested as default for new conversations.
- When person is linked to the current user, system prompt includes "(this is you)" — enabling first-person language.

### Intelligent Person Resolution
When no person is explicitly picked (web app without selection, or Telegram), the system auto-resolves the person from natural language.

**Resolution strategy:**
1. **Single person in space** → always that person, no AI call needed.
2. **Multiple people** → call a fast model (e.g., `gpt-4o-mini` or `claude-haiku`) to resolve. Always use the model even for first-person language — "my" could mean "my mom's results".

**Resolution prompt:**
```
Given these people in the space:
1. Anna Kowalska (female, age 41) — THIS IS THE CURRENT USER
2. Tomek Kowalski (male, age 12)
3. Maria Kowalska (female, age 68)

User message: "My son has been feeling tired lately. His last blood work showed low iron."

Which person is this about? Return JSON: {"person_number": 2} or {"person_number": null} if unclear.
```

The people list includes name, sex, age, and "THIS IS THE CURRENT USER" for the linked person.

**Caching**: once resolved for a conversation, the person is stored on the conversation record. Re-resolution can happen if the user switches topic mid-conversation.

**Web app**: person picker is pre-filled with resolved person (user can override). If resolution fails → picker left empty, AI asks "Who are you asking about?"

**Telegram**: resolution runs on first message. Resolved person mentioned in response. If ambiguous: "Who are you asking about — Anna or Tomek?"

### AI Provider callback
```elixir
@callback resolve_person(message :: String.t(), people_context :: String.t()) ::
            {:ok, String.t() | nil} | {:error, String.t()}
```
Uses a fast, cheap model. Returns person ID or nil. Non-streaming, simple JSON response.

## Context Building

### System prompt
```
You are Meddie, a friendly health assistant. You help users understand their
medical test results. You speak in the same language as the user.

Guidelines:
- Reference specific values and ranges when answering
- Explain medical terms in plain language
- If a value is out of range, explain what it might indicate
- Always recommend consulting a healthcare provider for medical decisions
- Do not diagnose conditions — explain what results might suggest
- If you don't have enough data, say so clearly

{person_context — only if person selected}
```

### Person context format
Assembled by `Meddie.AI.Prompts.chat_context/2` (scope, person):

```
## Person: Anna Kowalska (this is you)
Sex: female | DOB: 1985-03-15 (age 41) | Height: 165 cm | Weight: 62 kg

## Health Notes
Type 2 diabetes diagnosed 2020. Family history of cardiovascular disease.

## Supplements
- Vitamin D 2000 IU daily
- Omega-3 1000mg daily

## Medications
- Metformin 500mg twice daily

## Latest Biomarker Results
### Morfologia krwi (from 2025-01-15)
- Hemoglobin: 13.2 g/dL [12.0-16.0] ✓ normal
- WBC: 11.5 10^3/µL [4.0-10.0] ⚠ HIGH (↑ trend from 3 measurements)
- RBC: 4.5 10^6/µL [3.8-5.1] ✓ normal

### Lipidogram (from 2025-01-15)
- LDL Cholesterol: 145 mg/dL [0-100] ⚠ HIGH (↑ trend)
- HDL Cholesterol: 55 mg/dL [40-60] ✓ normal
- Triglycerides: 180 mg/dL [0-150] ⚠ HIGH (stable)

## Document Summaries
- 2025-01-15: Lab results — Complete blood count and lipid panel. Elevated WBC and LDL.
- 2024-09-10: Medical report — Annual checkup. Blood pressure normal. HbA1c improved.
```

### Context layers (in order)
1. **Person profile** — name, sex, DOB (with calculated age), height, weight, linked user flag.
2. **Memory fields** — health_notes, supplements, medications (as-is, markdown).
3. **Biomarkers** — latest value per biomarker, grouped by category, with status, reference range, and trend direction (↑ increasing, ↓ decreasing, → stable). Only biomarkers from last 2 years.
4. **Document summaries** — last 10 documents with date, type, and summary text.

### Token budget
- If context exceeds ~4000 tokens, truncate document summaries first, then older biomarkers.
- Conversation history: last 20 messages sent to AI. Older messages displayed in UI but not included in AI context.

### No person selected
The AI acts as a general health assistant — no personal data in context.

## Memory & Auto-population

During conversations, the AI detects health-relevant information worth persisting to the person's profile fields.

### Approach: Optimistic save with undo

The AI auto-saves detected information and tells the user, with an option to revert. No confirmation before saving — keeps conversation flow natural.

**Flow:**

1. The system prompt instructs the AI to watch for health-relevant info and return structured updates alongside its text response (JSON block appended to response).
2. When the AI detects something worth saving, the system:
   - Immediately updates the person's field via `People.update_person/3`.
   - Stores the previous field value for undo.
   - Shows a system message in the chat: "Saved to Health Notes: *Hypothyroidism diagnosed 2023*" with an **Undo** button.
3. If the user clicks **Undo**:
   - The field is reverted to the previous value.
   - The system message updates to "Reverted".

**Examples:**
- "I was diagnosed with hypothyroidism" → auto-save to health_notes
- "I started taking Vitamin D 2000 IU daily" → auto-save to supplements (append to Current)
- "I stopped metformin last week" → auto-save to medications (move from Current to Previous)

**AI structured output format** (appended to response):
```json
{"memory_updates": [
  {"field": "health_notes", "action": "append", "text": "Hypothyroidism diagnosed 2023"},
  {"field": "supplements", "action": "append", "text": "Vitamin D 2000 IU daily"},
  {"field": "medications", "action": "remove", "text": "Metformin"}
]}
```

Actions:
- `append` — add to "Current" section of the field.
- `remove` — move from "Current" to "Previous" section.

**Constraints:**
- Only works when a person is selected.
- Only saves to: health_notes, supplements, medications.
- Undo available until a new message is sent.
- The `memory_updates` JSON block is stripped from the displayed assistant message.

## Streaming Implementation

### Architecture: LiveView + JS Hook hybrid

LiveView manages all state (conversations, messages, person, persistence, auth). A JS hook handles the fast part — rendering streaming tokens directly in the DOM. This matches existing patterns (TrendChart hook for Chart.js, MarkdownEditor hook for Milkdown).

**Why not pure LiveView?** Each token would trigger a WebSocket DOM diff. At 50+ tokens/sec that's sluggish.

**Why not pure client-side?** Would need a separate endpoint duplicating auth/scope, breaks LiveView pattern.

### Streaming flow

```
1. User types message → handle_event("send_message")
2. LiveView saves user message to DB
3. LiveView spawns async Task:
   - Builds context (person profile + biomarkers + memory fields + history)
   - Calls chat_provider.chat_stream(messages, system_prompt, callback)
   - Callback sends {:chat_token, chunk} to LiveView process
4. LiveView handle_info({:chat_token, chunk}):
   - push_event(socket, "chat:token", %{text: chunk})
5. JS ChatStream hook receives "chat:token":
   - Appends text to DOM directly (fast, no server round-trip)
   - Auto-scrolls to bottom
6. Task completes → sends {:chat_complete, full_text}
7. LiveView handle_info({:chat_complete, full_text}):
   - Parses and strips memory_updates JSON block (if any)
   - Applies memory updates to person fields
   - Saves assistant message to DB (without JSON block)
   - Updates assigns (source of truth)
   - push_event(socket, "chat:complete", %{})
8. JS hook receives "chat:complete":
   - Final markdown render of complete message
   - Re-enable input
```

### Error handling
- Task crash → `handle_info({:chat_error, reason})` → show error message + retry button.
- Network disconnect → LiveView reconnects, loads conversation from DB.
- Input disabled while streaming (one request at a time).

## Data Model

**conversations**

| Column | Type | Constraints |
|--------|------|------------|
| id | `uuid` | PK |
| space_id | `uuid` | FK → spaces, NOT NULL, indexed |
| person_id | `uuid` | FK → people, nullable, indexed |
| user_id | `uuid` | FK → users, NOT NULL, indexed |
| title | `string` | nullable, AI-generated after first exchange |
| inserted_at | `utc_datetime` | NOT NULL |
| updated_at | `utc_datetime` | NOT NULL |

- `space_id` — multi-tenancy scoping.
- `person_id` — nullable (can chat without a person).
- `user_id` — who created the conversation. Conversations are **private** — only visible to the user who created them.

**messages**

| Column | Type | Constraints |
|--------|------|------------|
| id | `uuid` | PK |
| conversation_id | `uuid` | FK → conversations, NOT NULL, indexed |
| role | `string` | NOT NULL, values: `user`, `assistant`, `system` |
| content | `text` | NOT NULL |
| inserted_at | `utc_datetime` | NOT NULL |

Messages are immutable — no `updated_at`. The `system` role is used for memory update notifications.

**memory_updates** (for undo tracking)

| Column | Type | Constraints |
|--------|------|------------|
| id | `uuid` | PK |
| message_id | `uuid` | FK → messages, NOT NULL |
| person_id | `uuid` | FK → people, NOT NULL |
| field | `string` | NOT NULL, values: `health_notes`, `supplements`, `medications` |
| action | `string` | NOT NULL, values: `append`, `remove` |
| text | `text` | NOT NULL, the text that was added/removed |
| previous_value | `text` | nullable, full field value before the update (for undo) |
| reverted | `boolean` | NOT NULL, default: false |
| inserted_at | `utc_datetime` | NOT NULL |

### Indexes
- `conversations.space_id`
- `conversations.person_id`
- `conversations.(user_id, space_id)` — find user's conversations in a space
- `messages.conversation_id`

## Routes

```elixir
live "/ask-meddie", AskMeddieLive.Index, :index
live "/ask-meddie/new", AskMeddieLive.Show, :new
live "/ask-meddie/:id", AskMeddieLive.Show, :show
```

`/ask-meddie/new?person_id=:id` — pre-selects person from query param.

## Conversation Titles

Auto-generated via AI after the first assistant response completes. Async — a lightweight model call: "Generate a 3-6 word title for this conversation" with the first user message + first assistant response. Until generated, show first ~60 chars of first message as placeholder.

## Rate Limiting

200 messages per day per user. Tracked via DB count query on messages where `role = "user"`, inserted today, scoped to user. No remaining count shown in UI — just a friendly block message when the limit is reached.

## Edge Cases

- **No person selected, no biomarker data**: AI acts as general health assistant. No personal context sent.
- **No documents for selected person**: AI mentions that no documents have been uploaded yet and suggests uploading.
- **AI API failure**: show error message with retry button.
- **Very long conversations**: last 20 messages sent to AI. Older messages displayed in UI but excluded from AI context.
- **Rate limit reached**: input disabled with message: "You've reached the daily message limit. Try again tomorrow."
- **Person deleted mid-conversation**: conversation remains accessible but person context is no longer available. Show notice.
- **Sensitive questions**: AI does not provide diagnoses or treatment recommendations. System prompt enforces this, disclaimer reminds users.
- **Memory update on deleted/changed person**: if person was deleted between message send and response, skip memory updates gracefully.

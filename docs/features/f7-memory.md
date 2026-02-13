# F7: Memory

## Description

A per-user semantic memory system that persists facts across conversations. The main AI model saves memorable facts in real-time during conversations via a `memory_saves` JSON block appended to its responses (same pattern as `profile_updates` for person profile fields). Facts are stored in PostgreSQL with vector embeddings (pgvector). Before each AI response, relevant memories are retrieved via hybrid search (vector cosine similarity + full-text keyword) and injected into the system prompt.

Memory is invisible to users — it works in the background with no management UI.

## Architecture

```
User sends message
    │
    ▼
┌─────────────────────────┐
│ Search memories          │ ← hybrid search using user's message as query
│ (vector + keyword)       │
└───────────┬─────────────┘
            ▼
┌─────────────────────────┐
│ Build system prompt      │ ← inject "Remembered Facts" section
│ + person context         │
└───────────┬─────────────┘
            ▼
┌─────────────────────────┐
│ AI generates response    │ ← may include memory_saves JSON block
└───────────┬─────────────┘
            ▼
┌─────────────────────────┐
│ Parse response           │ ← extract memory_saves + profile_updates
│ Save facts to DB         │ ← deduplicate + embed + store
└─────────────────────────┘
```

## Memory Scoping

- **Per User + Space** (not per Person). A user discusses multiple people — memory captures the user's knowledge across all conversations.
- A user in multiple spaces has separate memory stores.
- Telegram links without a `user_id` skip memory (memory requires a user).

## Relationship to Profile Updates

The `profile_updates` system (F5) handles structured person profile data — supplements, medications, health_notes fields on the Person schema. `memory_saves` (F7) handles broader conversational facts (preferences, family history, lifestyle, goals). Both are output by the AI in the same JSON block at the end of its response:

```json
{
  "profile_updates": [{"field": "health_notes", "action": "append", "text": "Hypothyroidism"}],
  "memory_saves": ["User prefers natural supplements", "User's mother has type 2 diabetes"]
}
```

## Model-Driven Saving

Inspired by OpenClaw's approach, Meddie uses **model-driven memory** — the main AI model decides what to save during the conversation, rather than a separate extraction model reviewing conversations after the fact.

The system prompt instructs the AI to append a `memory_saves` JSON array when the user states durable facts. Key rules:
- ONLY save facts the **user stated or confirmed** — never save medical knowledge the AI provided
- Each fact: concise, self-contained sentence (max 200 chars)
- Write in the user's language
- Do NOT save biomarker values or supplement/medication lists (handled separately)

**Advantages over post-hoc extraction:**
- Higher quality — the main model understands conversational context and knows what the user said vs what it said
- No misattribution — no risk of saving AI-provided medical knowledge as user facts
- Real-time — facts are saved immediately, not after a delay
- No separate API cost for extraction

## Hybrid Search

Inspired by OpenClaw's hybrid search approach, combining vector similarity and keyword matching:

| Parameter | Value |
|-----------|-------|
| Vector weight | 0.70 |
| Keyword weight | 0.30 |
| Min score threshold | 0.35 |
| Max results | 6 |
| Embedding model | OpenAI text-embedding-3-small (1536 dims) |
| Semantic dedup threshold | 0.92 cosine similarity |
| Vector index | HNSW (m=16, ef_construction=64) |
| Keyword index | PostgreSQL GIN + tsvector (simple config) |

**Merge algorithm**: For each candidate memory, `score = 0.7 * vectorScore + 0.3 * normalizedKeywordScore`. Results filtered by min score, sorted descending, limited to max results.

### What Gets Saved

**Saves:**
- Health conditions, diagnoses, allergies
- Preferences (diet, lifestyle, treatment)
- Family medical history
- Key dates (surgeries, appointments)
- Doctor names, specialists
- Reactions to treatments

**Does NOT save:**
- Biomarker values (stored separately in Documents)
- Temporary states ("feeling tired today")
- Medical knowledge the AI provided
- Supplement/medication lists (handled by profile_updates)

## Deduplication

Two-tier:
1. **Exact**: SHA256 hash of normalized (trimmed, lowercased) content → unique DB constraint on `(content_hash, user_id, space_id)`
2. **Semantic**: If cosine similarity > 0.92 with any existing active memory → skip insert

## Prompt Injection

Retrieved memories are added to the system prompt as a "Remembered Facts" section:

```
## Remembered Facts
Things you know about this user from previous conversations:
- User is allergic to ibuprofen
- User's mother has type 2 diabetes
- User prefers natural supplements over synthetic
```

This section appears after person context and before memory detection instructions.

## Data Model

**memories**

| Column | Type | Constraints |
|--------|------|-------------|
| id | `uuid` | PK |
| user_id | `uuid` | FK → users, NOT NULL |
| space_id | `uuid` | FK → spaces, NOT NULL |
| content | `text` | NOT NULL, max 500 chars |
| content_hash | `string` | NOT NULL, SHA256 |
| embedding | `vector(1536)` | NOT NULL |
| source | `string` | NOT NULL, values: `chat`, `manual` |
| source_message_id | `uuid` | FK → messages, nullable |
| active | `boolean` | NOT NULL, default: true |
| content_tsv | `tsvector` | GENERATED, for full-text search |
| inserted_at | `utc_datetime` | NOT NULL |
| updated_at | `utc_datetime` | NOT NULL |

### Indexes

- `(user_id, space_id)` — primary query filter
- `(content_hash, user_id, space_id)` — unique, deduplication
- HNSW on `embedding vector_cosine_ops` — vector similarity
- GIN on `content_tsv` — full-text keyword search

## Integration Points

### Web (AskMeddieLive.Show)
1. **Before AI call**: `Meddie.Memory.search_for_prompt(scope, content)` → pass to `Chat.build_system_prompt/3`
2. **After response**: `Chat.parse_response_metadata/1` returns `{display_text, updates, saves}` → `Chat.apply_memory_saves(scope, saves)` saves facts

### Telegram (Handler)
1. **Before AI call**: Same `search_for_prompt` call
2. **After response**: Same `parse_response_metadata` + `apply_memory_saves` flow (skipped if no `scope.user`)

### Prompts
`Prompts.chat_system_prompt/2` accepts optional `memory_facts` list and injects the "Remembered Facts" section. `memory_detection_instructions/0` includes both `profile_updates` and `memory_saves` instructions.

## Conversation Lifecycle

| Channel | Conversation ends when... |
|---------|--------------------------|
| **Web** | User clicks "New conversation" or navigates to `/ask-meddie/new` |
| **Telegram** | User sends `/new` **OR** conversation is idle for >8 hours (auto-close) |

Telegram conversations auto-close after 8 hours of inactivity (`@telegram_idle_timeout_hours` in `Conversations`). When a new message arrives and the last activity was >8h ago, a fresh conversation is created automatically. The last 30 messages from the previous conversation are carried forward into the AI context for continuity.

## Edge Cases

- **No user (anonymous Telegram link)**: Memory search and saving are skipped.
- **Embeddings API failure**: Search returns empty list, chat continues without memory context. Fact saving fails silently (dedup check uses embeddings).
- **AI doesn't include memory_saves**: Facts are simply not saved for that response. No fallback extraction.
- **Duplicate facts**: Two-tier deduplication (exact hash + semantic similarity) prevents storing the same fact twice.

## Comparison with OpenClaw Memory

Meddie's F7 Memory was inspired by OpenClaw's memory system. Both use hybrid search (vector + keyword) and model-driven saving.

| Aspect | Meddie | OpenClaw |
|--------|--------|----------|
| **Storage** | PostgreSQL rows with pgvector embeddings | Markdown files (`MEMORY.md` + `memory/YYYY-MM-DD.md`) indexed into SQLite |
| **Source of truth** | Database rows | Markdown files (human-editable, git-friendly); SQLite index is derived/ephemeral |
| **Scoping** | Per User + Space | Per Agent (each agent has its own workspace) |
| **Saving trigger** | Model-driven — AI includes `memory_saves` in response JSON | Model-driven — model uses `write`/`edit` file tools to save facts |
| **Saving method** | AI appends `memory_saves` JSON block, system parses and stores | Model writes facts directly to markdown files via tool calls |
| **Retrieval** | Automatic — injected into system prompt before each AI response | On-demand — model decides when to search via tool calls |
| **Prompt injection** | "Remembered Facts" section prepended to system prompt | Model receives search results as tool responses; decides what to cite |
| **Hybrid search** | PostgreSQL: pgvector HNSW + GIN tsvector | SQLite: sqlite-vec (or in-process cosine) + FTS5 BM25 |
| **Search weights** | 0.7 vector / 0.3 keyword (same defaults) | 0.7 vector / 0.3 keyword (same defaults) |
| **Min score / max results** | 0.35 / 6 (same defaults) | 0.35 / 6 (same defaults) |
| **Embedding model** | OpenAI text-embedding-3-small (1536 dims) | Configurable: OpenAI, Gemini, Voyage AI, or local (default: text-embedding-3-small) |
| **Deduplication** | Two-tier: SHA256 content hash (exact) + cosine > 0.92 (semantic) | File-level hash + chunk-level replacement + embedding cache |
| **Memory management UI** | None (invisible to users) | CLI tools (`openclaw memory status/index/search`); users edit markdown files directly |
| **Chunking** | One fact = one row (max 500 chars) | Markdown split into ~400-token chunks with 80-token overlap |
| **Indexing** | Immediate on insert (embedding computed at create time) | Lazy — on session start, on search, or via file watcher (debounced 1.5s) |
| **Multi-provider** | Always OpenAI for embeddings | Auto-selects: local > OpenAI > Gemini > Voyage |
| **Safety net** | None — relies on model to save facts | Pre-compaction flush — reminds model to save before context window compacts |

### Key Differences

**Both model-driven.** Both Meddie and OpenClaw let the main model decide what to remember. Meddie uses a structured JSON block in the response, while OpenClaw uses standard file write tools. The result is the same: the model has full conversational context and naturally saves user-stated facts.

**Database vs. files.** Meddie stores atomic facts as database rows with vector embeddings. OpenClaw stores rich markdown documents and chunks them for indexing. OpenClaw's approach is more transparent (users can read/edit files), while Meddie's is more structured (each fact is a discrete, deduplicated unit).

**Automatic vs. on-demand retrieval.** Meddie always searches and injects relevant memories into the system prompt. OpenClaw's model decides when to search via tool calls. Meddie uses slightly more prompt tokens but ensures the AI never "forgets" to check.

## Key Files

| File | Purpose |
|------|---------|
| `lib/meddie/memory.ex` | Context module — CRUD, hybrid search |
| `lib/meddie/memory/fact.ex` | Ecto schema for `memories` table |
| `lib/meddie/memory/embeddings.ex` | OpenAI text-embedding-3-small client |
| `lib/meddie/postgrex_types.ex` | Custom Postgrex types (pgvector support) |
| `lib/meddie/conversations/chat.ex` | `parse_response_metadata/1`, `apply_profile_updates/5`, `apply_memory_saves/2`, `build_system_prompt/3` |
| `lib/meddie/ai/prompts.ex` | `chat_system_prompt/2` with Remembered Facts + memory detection instructions |

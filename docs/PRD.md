# Meddie — Product Requirements Document

## 1. Project Overview

**Meddie** is an open-source web application that uses AI vision models to parse medical documents. Users upload blood tests, lab reports, or prescriptions in any format — Meddie extracts every biomarker, value, and reference range automatically. Users can track their health over time, spot trends through charts, and ask AI-powered questions about their results.

### Problem

Medical test results come in inconsistent formats — scanned PDFs, photographed lab printouts, digital reports with varying layouts. Manually tracking biomarkers across multiple tests over time is tedious and error-prone. Most people file their results away and never look at them again.

### Target Users

- Health-conscious individuals who want to track their lab results over time
- Patients managing chronic conditions who need to monitor specific biomarkers
- Anyone who wants to understand their medical test results better

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Elixir + Phoenix |
| Frontend | Phoenix LiveView + TypeScript JS hooks (charts, PDF.js) |
| Authentication | phx.gen.auth (email/password, magic link) |
| Background Jobs | Oban (PostgreSQL-backed) |
| Document Parsing | Vision model (OpenAI or Anthropic) |
| AI Chat | Language model (OpenAI or Anthropic) |
| Database | PostgreSQL |
| File Storage | Tigris (S3-compatible) |
| Deployment | Fly.io |

### License

MIT

---

## 2. Features

| # | Feature | Description | Spec |
|---|---------|-------------|------|
| F1 | [Authentication & Multi-tenancy](features/authentication-multitenancy.md) | Email/password registration & login via Pow, data isolation per Space | [→](features/authentication-multitenancy.md) |
| F2 | [People](features/people.md) | Health profiles per Space — basic info, health notes, supplements, medications | [→](features/people.md) |
| F3 | [Documents](features/documents.md) | Upload, AI parsing (lab results + medical reports), document preview and management | [→](features/documents.md) |
| F4 | [Biomarker Dashboard](features/biomarker-dashboard.md) | Structured view of parsed results | [→](features/biomarker-dashboard.md) |
| F5 | [Trend Tracking](features/trend-tracking.md) | Chart biomarker values over time | [→](features/trend-tracking.md) |
| F6 | [AI Q&A](features/ai-qa.md) | Ask questions about your results | [→](features/ai-qa.md) |
| F7 | [Telegram](features/telegram.md) | Telegram bot for chatting with AI about health data | [→](features/telegram.md) |

**UI Architecture**: [ui-architecture.md](ui-architecture.md) — layout, navigation, screen flow, responsive behavior, component patterns.

---

## 3. Data Model

### Entity Relationship Overview

```
users
  ├── has_many → memberships → belongs_to → spaces
  ├── has_many → invitations (as inviter)
  ├── has_one → person (optional link, per Space)
  │
  └── (all data below is scoped to a Space, then to a Person)
        spaces
          └── has_many → people
                          ├── has_ma  ny → documents
                          │                 └── has_many → biomarkers
                          └── has_many → conversations
                                            └── has_many → messages
```

### Full Schema Summary

| Table | Key Fields | Relationships |
|-------|-----------|---------------|
| **users** | id, name, email, password_hash, platform_admin, locale | has_many: memberships, invitations; has_one: person (optional, per Space) |
| **spaces** | id, name | has_many: memberships, people |
| **memberships** | id, user_id, space_id, role | belongs_to: user, space |
| **invitations** | id, email, space_id (nullable), invited_by_id, token, accepted_at, expires_at | belongs_to: space (optional), invited_by (user) |
| **people** | id, space_id, user_id (nullable), name, date_of_birth, sex, height_cm, weight_kg, health_notes, supplements, medications | belongs_to: space, user (optional); has_many: documents, conversations |
| **documents** | id, space_id, person_id, filename, content_type, file_size, storage_path, status, document_type, summary, page_count, document_date, error_message | belongs_to: space, person; has_many: biomarkers |
| **biomarkers** | id, document_id, space_id, person_id, name, value, numeric_value, unit, reference_range_low, reference_range_high, reference_range_text, status, page_number, category | belongs_to: document, space, person |
| **conversations** | id, space_id, person_id, user_id, title | belongs_to: space, person, user; has_many: messages |
| **messages** | id, conversation_id, role, content | belongs_to: conversation |

### Key Indexes

- `users.email` — unique index
- `memberships.(user_id, space_id)` — unique composite index
- `invitations.token` — unique index
- `people.space_id` — find all people in a Space
- `people.(user_id, space_id)` — unique partial index where `user_id IS NOT NULL`
- `documents.space_id` — find all documents for a Space
- `documents.person_id` — find all documents for a person
- `biomarkers.document_id` — find all biomarkers for a document
- `biomarkers.(person_id, name)` — composite index for per-person trend queries
- `conversations.space_id` — find all conversations for a Space
- `conversations.person_id` — find all conversations for a person
- `messages.conversation_id` — find all messages in a conversation

---

## 4. AI Provider Abstraction

### Design

Use an Elixir behaviour (interface) to abstract AI providers. This allows swapping between OpenAI and Anthropic without changing application code.

```elixir
defmodule Meddie.AI.Provider do
  @doc "Parse a medical document image and return structured biomarker data"
  @callback parse_document(image_data :: binary(), content_type :: String.t()) ::
              {:ok, map()} | {:error, String.t()}

  @doc "Stream a chat response given messages and context"
  @callback chat_stream(messages :: list(map()), system_prompt :: String.t(), callback :: function()) ::
              :ok | {:error, String.t()}
end
```

### Provider Implementations

```elixir
defmodule Meddie.AI.Providers.OpenAI do
  @behaviour Meddie.AI.Provider
  # Uses OpenAI API with gpt-4o for vision and chat
end

defmodule Meddie.AI.Providers.Anthropic do
  @behaviour Meddie.AI.Provider
  # Uses Anthropic API with Claude for vision and chat
end
```

### Configuration

```elixir
# config/runtime.exs
config :meddie, :ai,
  parsing_provider: Meddie.AI.Providers.OpenAI,   # or Anthropic
  chat_provider: Meddie.AI.Providers.Anthropic,    # or OpenAI
  openai_api_key: System.get_env("OPENAI_API_KEY"),
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY")
```

Users can configure which provider handles parsing vs. Q&A independently. This allows using OpenAI for vision parsing and Anthropic for chat, or vice versa.

### HTTP Client

Use `Req` for HTTP requests to AI APIs. Each provider module handles its own request/response formatting.

---

## 5. Internationalization (i18n)

- **Default locale**: Polish (`pl`)
- **Supported locales**: `pl`, `en`
- **Library**: Phoenix Gettext (built-in)
- **Translation files**: `priv/gettext/pl/LC_MESSAGES/*.po`, `priv/gettext/en/LC_MESSAGES/*.po`
- **Locale storage**: `locale` column on the `users` table (default: `"pl"`). Read on each request, changeable via language picker.
- **Language picker**: Compact switcher in the navigation (PL / EN). Updates the user's `locale` field.

### What's translated

All user-facing text via Gettext: UI labels, buttons, navigation, form labels/placeholders/hints, flash messages, validation errors, email templates (invitations, password reset), AI disclaimer text.

### What's NOT translated

- User-generated content (Space names, conversation messages)
- AI-generated responses (depend on source document language and model output)
- Biomarker names and values (extracted as-is from documents)

### Configuration

```elixir
# config/config.exs
config :meddie, MeddieWeb.Gettext,
  default_locale: "pl",
  locales: ~w(pl en)
```

A plug (for regular requests) and `on_mount` hook (for LiveView) reads the locale from the current user's `locale` field and calls `Gettext.put_locale/2`. For unauthenticated pages (login, registration), the default locale (`pl`) is used.

### Email locale

Invitation and password reset emails use the inviter's current locale, since the recipient hasn't set a preference yet.

---

## 6. Infrastructure & Deployment

### Fly.io

- **App name**: `meddie`
- **Region**: Start with a single region, scale later
- **Machine size**: `shared-cpu-1x` with 512MB RAM for MVP (scale up for production)
- **Secrets**: API keys stored via `fly secrets set`

### PostgreSQL

- **Provisioning**: `fly postgres create` — Fly.io managed PostgreSQL
- **Connection**: Via `DATABASE_URL` environment variable
- **Migrations**: Run via `fly ssh console` or release command in `fly.toml`

### Tigris (File Storage)

- **Bucket**: `meddie-documents`
- **Provisioning**: Created via Fly.io Tigris integration (`fly storage create`)
- **Access**: Via S3-compatible API using `ex_aws_s3`
- **Credentials**: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ENDPOINT_URL_S3` set as Fly secrets
- **Lifecycle policy**: No auto-deletion. Users manually delete their documents.

### Environment Variables

| Variable | Description |
|----------|------------|
| `DATABASE_URL` | PostgreSQL connection string |
| `SECRET_KEY_BASE` | Phoenix secret key |
| `PHX_HOST` | Application hostname |
| `OPENAI_API_KEY` | OpenAI API key |
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `AWS_ACCESS_KEY_ID` | Tigris access key |
| `AWS_SECRET_ACCESS_KEY` | Tigris secret key |
| `AWS_ENDPOINT_URL_S3` | Tigris endpoint |
| `BUCKET_NAME` | Tigris bucket name |

---

## 7. Future Considerations (Out of MVP Scope)

- **OAuth providers**: Add Google/GitHub login via Ueberauth or custom OAuth integration
- **FHIR/HL7 import**: Parse structured electronic health record formats
- **Export**: Download parsed results as CSV or PDF reports
- **Doctor sharing**: Generate shareable links for healthcare providers to view specific results
- **Biomarker aliasing**: Map different names for the same biomarker (e.g., "Hgb" → "Hemoglobin")
- **Notifications**: Alert users when new results show out-of-range values or significant trend changes

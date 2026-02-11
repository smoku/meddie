# Meddie

Open-source web app that uses AI vision models to parse medical documents. Upload blood tests, lab reports, or prescriptions in any format — Meddie extracts every biomarker, value, and reference range automatically. Track health over time, spot trends through charts, and ask AI-powered questions about results.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Elixir + Phoenix 1.8 |
| Frontend | Phoenix LiveView + TypeScript JS hooks |
| Auth | phx.gen.auth (email/password) |
| Background Jobs | Oban |
| AI | OpenAI + Anthropic (swappable via behaviour) |
| Database | PostgreSQL |
| File Storage | Tigris (S3-compatible) |
| Styling | Tailwind v4 + DaisyUI |
| Deployment | Fly.io |

## Features

| # | Feature | Description | Status |
|---|---------|-------------|--------|
| F1 | [Authentication & Multi-tenancy](docs/features/f1-authentication-multitenancy.md) | Email/password login, invitation-only registration, Spaces with role-based access | Done |
| F2 | [People](docs/features/f2-people.md) | Health profiles for yourself or family — age, sex, conditions, supplements, medications | Done |
| F3 | [Documents](docs/features/f3-documents.md) | Upload medical PDFs/photos, AI vision parsing extracts biomarkers and report summaries | Done |
| F4 | [Biomarker Dashboard & Trends](docs/features/f4-biomarker-dashboard.md) | Lab results grouped by category, inline sparklines, interactive Chart.js trend graphs | Done |
| F5 | [Ask Meddie](docs/features/f5-ask-meddie.md) | Chat with AI about your health data — references biomarkers, medications, and documents | Done |
| F6 | [Telegram Bot](docs/features/f6-telegram.md) | Telegram integration for uploading documents and querying results on the go | Planned |

See [docs/PRD.md](docs/PRD.md) for the full product requirements document.

## Getting Started

### Prerequisites

- Elixir ~> 1.15
- PostgreSQL

### Setup

```bash
mix setup          # install deps, create DB, run migrations, seed
mix phx.server     # start the server
```

Visit [localhost:4000](http://localhost:4000).

### Running Tests

```bash
mix test
```

## License

MIT

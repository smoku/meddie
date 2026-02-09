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

| # | Feature | Status |
|---|---------|--------|
| F1 | Authentication & Multi-tenancy | Done |
| F2 | People (health profiles) | Planned |
| F3 | Documents (upload & AI parsing) | Planned |
| F4 | Biomarker Dashboard | Planned |
| F5 | Trend Tracking (charts) | Planned |
| F6 | AI Q&A | Planned |
| F7 | Telegram Bot | Planned |

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

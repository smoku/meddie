# UI Architecture

## App Shell

All authenticated pages share a persistent layout: a left sidebar, a top bar, and a content area.

```
┌──────┬──────────────────────────────────────────┐
│      │  [Space ▼]                    [User ▼]   │
│      ├──────────────────────────────────────────┤
│People│                                          │
│      │                                          │
│ Chat │             Content area                 │
│      │                                          │
│Telegr│                                          │
│      │                                          │
│Settin│                                          │
│      │                                          │
│  [<] │                                          │
└──────┴──────────────────────────────────────────┘
```

### Top Bar

| Position | Element | Description |
|----------|---------|-------------|
| Left | Space switcher | Dropdown showing current Space name. Lists all Spaces the user belongs to. "Create new Space" option at the bottom. |
| Right | Platform link | "Platform" — only visible to `platform_admin` users. Links to `/platform`. |
| Right | User menu | User name with dropdown: "Sign out". |

No language switcher in the top bar — language setting lives in Settings.

### Left Sidebar

Primary navigation for the app. Contains 4 items:

| Item | Icon | Route | Description |
|------|------|-------|-------------|
| People | users icon | `/people` | People list. Landing page after login. |
| Chat | message icon | `/chat` | AI Q&A conversations across all people. |
| Telegram | telegram icon | `/telegram` | Telegram bot setup and status. |
| Settings | gear icon | `/settings` | Space settings (members, invites) + user settings (language). |

**Active state**: The current section is highlighted in the sidebar.

**Collapsible**: A toggle button at the bottom of the sidebar switches between expanded (~200px, icon + label) and collapsed (~56px, icon only with tooltip on hover). The user's preference is stored in `localStorage` and persisted across sessions.

**Mobile**: The sidebar is hidden by default. A hamburger menu button in the top bar opens the sidebar as a slide-out overlay.

## Screen Flow

### Unauthenticated

```
Login (/session/new)
  ├── Forgot Password (/reset-password/new)
  │     └── Reset Password (/reset-password/:token/edit)
  └── [no registration link — invitation only]

Invitation (/invitations/:token/accept)
  └── Registration form → [if platform invite] Create First Space → People List
                         → [if space invite] People List
```

### Authenticated — Sidebar Sections

```
People (/people)                                 ← sidebar item, landing page
  ├── People List                                ← card grid
  ├── Person Detail (/people/:id)                ← tabbed layout
  │     ├── Overview tab                         ← health notes, supplements, medications
  │     ├── Documents tab                        ← document list + upload
  │     │     └── Document Detail (/people/:person_id/documents/:id)
  │     │           ├── Parsed results (biomarkers or summary)
  │     │           └── Original document (PDF.js / image)
  │     ├── [Biomarkers tab]                     ← F4, future
  │     └── [Trends tab]                         ← F5, future
  ├── New Person (/people/new)
  └── Edit Person (/people/:id/edit)

Chat (/chat)                                     ← sidebar item
  ├── Conversation List                          ← all conversations, grouped by person
  └── Conversation Detail (/chat/:id)            ← F6: AI Q&A

Telegram (/telegram)                             ← sidebar item
  └── [F7: TBD]

Settings (/settings)                             ← sidebar item
  ├── Space Settings                             ← members, invites (admin only)
  └── User Settings                              ← language (PL/EN)

Platform Admin (/platform)                       ← top bar link, platform_admin only
  ├── Invite new user
  └── List all Spaces
```

## Key Screens

### People List

The landing page after login. Shows all people in the current Space.

- **Layout**: Card grid (2-3 columns on desktop, 1 column on mobile)
- **Each card**: Person name, age (from DOB), sex icon, document count, last upload date
- **Actions**: Click card → Person Detail. "Add person" button at the top.
- **Empty state**: "No people yet. Add your first person to start tracking health data." with an "Add person" button.

### Person Detail

Tabbed layout showing all data for one person.

- **Header** (persistent across tabs): Person name, age, sex, height, weight. "Edit" button to modify basic info.
- **Tabs**: Overview | Documents | (future: Biomarkers | Trends)

#### Overview Tab

The person's health profile — three Markdown sections.

- **Health Notes**: Editable Markdown textarea. Click "Edit" to enter edit mode, "Save" / "Cancel" to commit or discard.
- **Supplements**: Same pattern. Organized with `## Current` / `## Previous` convention.
- **Medications**: Same pattern.
- **Recent documents**: A compact list of the last 3-5 documents with date, filename, and status. "View all" links to the Documents tab.

#### Documents Tab

Upload zone and document list for this person.

- **Upload zone**: Drag-and-drop area at the top with "Browse files" button. Accepts `.jpg`, `.jpeg`, `.png`, `.pdf`. Shows progress bars during upload.
- **Document list**: Reverse chronological table below the upload zone.
  - Columns: Date, Filename, Type (lab/report/other icon), Status badge, Biomarker count or summary excerpt
  - Click row → Document Detail
  - Actions per row: Retry (if failed), Delete
- **Empty state**: "No documents yet. Upload a medical document to get started."
- **Pagination**: 20 per page, "Load more" button.

### Document Detail

Split view showing the original document alongside parsed results.

- **Desktop**: Side-by-side. Left panel: original document (PDF.js or image). Right panel: parsed results.
- **Mobile**: Tabbed — "Results" / "Original" tabs.

**Left panel (Original)**:
- PDF.js viewer for PDFs (scrollable, zoomable)
- `<img>` tag for images
- Loaded via signed Tigris URL

**Right panel (Results)**:
- **For lab results** (`document_type: lab_results`):
  - Document info: date, filename, page count
  - Summary (AI-generated, 2-4 sentences)
  - Biomarker table grouped by category (e.g., "Morfologia krwi", "Lipidogram")
  - Each row: name, value, unit, reference range, status badge (normal/low/high)
  - Out-of-range values highlighted (red for high, blue for low)
- **For medical reports** (`document_type: medical_report`):
  - Document info: date, filename, page count
  - AI-generated summary (formatted text)
- **Actions**: Retry parsing, Delete document, Back to document list

### Chat (Conversation List)

Top-level chat view — accessible from the sidebar. Shows all AI Q&A conversations across people.

- **List**: Reverse chronological. Each row: conversation title, person name, last message preview, date.
- **Filter**: Filter by person (dropdown or tabs).
- **New conversation**: "New chat" button — prompts to select a person, then opens a new conversation.
- **Click row** → Conversation Detail (F6).

This provides a quick entry point for chat without navigating through People → Person → Chat tab.

### Parsing State (live updates)

While a document is being parsed:
- The document row in the list shows a spinning indicator and "Parsing page 2 of 5..." text
- Updates in real-time via LiveView (PubSub broadcast from Oban worker)
- On completion: row transitions to show results (biomarker count or summary excerpt)
- On failure: red "Failed" badge with error message and "Retry" button

### Settings

Accessible from the sidebar. Two sections:

**Space Settings** (admin only for member management):
- **Member list**: Table of all Space members. Columns: Name, Email, Role (admin/member), Actions.
- **Invite form**: Email input + "Send invitation" button. Admin only.
- **Remove member**: "Remove" button per member row. Confirmation modal. Admin only.

**User Settings**:
- **Language**: PL / EN selector. Updates the user's `locale` field.

### Platform Admin

Separate area at `/platform`. Only accessible to `platform_admin` users. Linked from the top bar.

- **Invite user**: Email input to invite a new user to the platform.
- **Spaces overview**: Table of all Spaces with name, member count, document count.

## Single-Person Optimization

Many users will have a Space with just one person (themselves). The UI adapts:

- **People list is skipped**: If the Space has exactly one person, navigating to the Space auto-redirects to that person's detail view.
- **No person selection for uploads**: The single person is auto-selected.
- **Back navigation**: "Back to People" link is hidden when there's only one person.
- **Chat auto-selects person**: New conversations auto-select the single person.
- **The app feels like a personal health tracker**, not a multi-person system — until the user adds a second person.

## Responsive Behavior

| Breakpoint | Layout |
|-----------|--------|
| Desktop (≥1024px) | Sidebar expanded (icon + label). People as card grid (2-3 cols). Document detail as side-by-side split view. |
| Tablet (768-1023px) | Sidebar collapsed (icon only). People as card grid (2 cols). Document detail as split view (narrower panels). |
| Mobile (<768px) | Sidebar hidden (hamburger menu). People as single column cards. Document detail as tabbed view (Results / Original). |

### Mobile-specific adaptations

- Sidebar becomes a slide-out overlay triggered by hamburger button in top bar
- Tables become card lists on small screens
- Upload zone is a simple button (no drag-and-drop)
- Split views become tabs
- Modals become full-screen sheets

## Component Patterns

| Pattern | Used for | Description |
|---------|----------|-------------|
| **Sidebar** | App navigation | Left sidebar with icon + label items. Collapsible to icon-only. Active item highlighted. |
| **Card** | People list | Visual, scannable. Shows key info at a glance. |
| **Table** | Documents, biomarkers, members | Data-dense, sortable columns. Collapses to cards on mobile. |
| **Split view** | Document detail | Side-by-side panels. Becomes tabs on mobile. |
| **Tabs** | Person detail | Horizontal tab bar below the person header. Active tab highlighted. |
| **Inline edit** | Markdown fields | Click "Edit" → textarea appears → "Save" / "Cancel". No separate edit page. |
| **Status badge** | Document status, biomarker status | Colored pill: green (parsed/normal), yellow (parsing), gray (pending), red (failed/high), blue (low). |
| **Upload zone** | Document upload | Dashed border area. Drag-and-drop + "Browse" button. Progress bars during upload. |
| **Modal** | Confirmations | Centered overlay for delete confirmations and destructive actions. |
| **Empty state** | Lists with no items | Centered text + primary action button. Friendly, not blank. |

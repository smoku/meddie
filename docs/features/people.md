# F2: People

## Description

People are the core entities within a Space. Every health-related record — documents, biomarkers, conversations — belongs to a specific person. A Space can contain multiple people (e.g., a family: yourself, a spouse, children) or just one (personal use).

Each person has basic health profile information and three Markdown-based "memory" fields: health notes, supplements, and medications. These fields serve as living context that is always sent to AI models during document parsing and Q&A conversations. They can be edited manually or auto-populated from AI chat suggestions.

A person can optionally be linked to a user account (`user_id`), which tells the AI "this person is the current user" — enabling first-person language in responses and resolving references like "my results."

## Behavior

### Creating a Person

1. User navigates to the People list or clicks "Add person" from the Space dashboard.
2. A form is presented with the following fields:
   - **Name** (required)
   - **Biological sex** (required, select: `male` / `female`)
   - **Date of birth** (optional)
   - **Height** in cm (optional)
   - **Weight** in kg (optional)
   - **Linked user** (optional select — links this person to a space member's account)
3. On submit, the person is created with empty Markdown fields (health notes, supplements, medications).
4. The user is redirected to the person's detail view where they can fill in the Markdown fields.

### Editing a Person

1. User navigates to a person's detail view and clicks "Edit."
2. All fields are editable, including the three Markdown text areas.
3. The Markdown fields use Milkdown — a WYSIWYG markdown editor (ProseMirror-based). Users type naturally without seeing markdown syntax. Content is stored as markdown and rendered as HTML on the detail view via Earmark.
4. Changes are saved on form submit.

### Linking a Person to a User Account

- When creating or editing a person, a user can link the person to their own account.
- A user can only be linked to one person per Space (enforced by unique index).
- The link is optional — children or family members who don't use the app won't have a linked user.
- The link can be removed at any time via the edit form.
- When linked, the AI context includes "(this is you)" next to the person's name, so the LLM knows to use first-person language.

### Deleting a Person

1. User clicks "Delete" on a person's detail view.
2. A confirmation modal appears: "This will permanently delete this person and all their documents, biomarkers, and conversations. This action cannot be undone."
3. On confirm, the person and all associated data are cascade-deleted.

### Person Context for LLMs

When the AI processes a document or handles a Q&A conversation for a person, the system assembles a context bundle that is prepended to the LLM call:

```
## Person: {name} {if linked to current user: "(this is you)"}
Sex: {sex} | DOB: {date_of_birth or "not set"} | Height: {height_cm or "not set"} cm | Weight: {weight_kg or "not set"} kg

## Health Notes
{health_notes or "No health notes yet."}

## Supplements
{supplements or "No supplements recorded."}

## Medications
{medications or "No medications recorded."}
```

This context helps the AI:
- Interpret biomarker reference ranges based on sex and age
- Consider existing conditions, medications, and supplements when answering questions
- Avoid asking for information the system already knows

### Supplement & Medication History

The Markdown fields naturally support tracking current vs. previous items. The recommended convention (guided by AI auto-population) is:

```markdown
## Current
- Vitamin D 2000 IU daily
- Omega-3 1000mg daily

## Previous
- Iron supplements (Jan–Jun 2024)
- Probiotics (stopped Mar 2025)
```

Users can restructure freely. The AI auto-population adds new items to "Current" by default. When a user mentions stopping something (e.g., "I stopped taking iron"), the AI suggests moving it from "Current" to "Previous."

### Auto-population from AI Q&A

The AI Q&A feature (F6) can suggest updates to a person's Markdown fields. The mechanism:

1. During a Q&A conversation scoped to a person, the AI detects health-relevant information in the user's messages (e.g., "I am diabetic", "I started taking Vitamin D 2000 IU daily", "I stopped taking metformin").
2. The AI proposes an update — specifying the target field (health notes, supplements, or medications) and the text to add, modify, or move.
3. The user sees the suggestion in the chat interface and can confirm or dismiss it.
4. On confirm, the system updates the relevant Markdown field.

The detection and suggestion logic is defined in F6: AI Q&A. This section defines the data model and the fact that these fields are programmatically updatable.

## Data Model

**people**

| Column | Type | Constraints |
|--------|------|------------|
| id | `uuid` | PK |
| space_id | `uuid` | FK → spaces, NOT NULL, indexed |
| user_id | `uuid` | FK → users, nullable, unique per space |
| name | `string` | NOT NULL |
| date_of_birth | `date` | nullable |
| sex | `string` | NOT NULL, values: `male`, `female` |
| height_cm | `integer` | nullable |
| weight_kg | `float` | nullable |
| health_notes | `text` | nullable, Markdown format |
| supplements | `text` | nullable, Markdown format |
| medications | `text` | nullable, Markdown format |
| inserted_at | `utc_datetime` | NOT NULL |
| updated_at | `utc_datetime` | NOT NULL |

**Indexes:**
- `people.space_id` — find all people in a Space
- `people.(user_id, space_id)` — unique partial index where `user_id IS NOT NULL` — prevents a user from being linked to multiple people in the same Space

## UI Description

Minimal for now — will be refined in later iterations.

### People List

- Displayed within the Space dashboard or via a "People" link in navigation.
- Each person shown as a card with: name, sex, age (calculated from DOB), document count.
- "Add person" button.
- **Empty state**: "No people yet. Add your first person to start tracking health data."

### Person Detail View

- Basic info section: name, sex, date of birth, height, weight. "Edit" button.
- Three Markdown text areas below: Health Notes, Supplements, Medications. Each with its own heading and edit/save controls.
- List of recent documents for this person (links to F3).

### Person Create / Edit Form

- Form with fields as described in "Creating a Person."
- The three Markdown fields are editable in the edit form (not in the create form — they start empty).

## Edge Cases

- **Deleting a person with data**: Cascade-deletes all documents, biomarkers, and conversations. Confirmation modal warns about data loss.
- **Space with no people**: Empty state with prompt to add the first person.
- **Markdown field size limits**: Reasonable cap of 50,000 characters per field. Validation error if exceeded.
- **Person name uniqueness**: Not enforced — two children could theoretically share a name.
- **User linked to multiple people in same Space**: Prevented by unique partial index on `(user_id, space_id)` where `user_id IS NOT NULL`.
- **Deleting a user who is linked to a person**: The `user_id` on the person is set to `NULL` (on delete: nilify). The person record and all their data remain intact.
- **Linking to a user who is already linked**: Show error: "This user is already linked to another person in this Space."

## Cross-feature Impact

Adding the Person concept requires `person_id` on data in other features. These will be updated in their respective specs:

- **F3: Documents** — `documents` table gains `person_id` FK. Upload flow requires person selection.
- **F4: Biomarker Dashboard** — Scoped to a person.
- **F5: Trend Tracking** — Per-person trend charts.
- **F6: AI Q&A** — `conversations` table gains `person_id` FK. Person context bundle sent with every LLM call. Auto-population suggestion mechanism.

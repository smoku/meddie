# F3: Documents

## Description

Users upload medical documents (PDFs or photos) for a specific person, which are automatically parsed by an AI vision model. Lab results get biomarkers extracted; other medical documents (MRI descriptions, glucose monitor reports, prescriptions) get an AI-generated summary. Documents are stored in Tigris (S3-compatible) and managed through a chronological list with live status updates.

This feature covers the full document lifecycle: upload, AI parsing, document management (list, view, retry, delete), and original document preview.

## Behavior

### Upload

1. **Person context**: User must be viewing a specific person (or selects one during upload). If the Space has only one person, they are auto-selected.
2. **Upload trigger**: User clicks "Upload document" on the person's page or navigates to the upload area. A file picker opens.
3. **File selection**: User selects one or more files. LiveView validates file type and size client-side before upload begins.
4. **Upload progress**: LiveView streams the upload with a progress bar per file. The upload uses Phoenix LiveView's `allow_upload/3` with chunked uploads.
5. **Server processing**: On upload completion, the server:
   - Computes a SHA-256 hash of the file content
   - Checks for an existing document with the same hash for this person — if found, skips the upload and shows an info flash ("This document has already been uploaded.")
   - Generates a UUID for the document
   - Uploads the file to Tigris under the path `documents/{space_id}/{person_id}/{document_id}/{original_filename}`
   - Creates a `documents` record with status `pending`, the selected `person_id`, and the `content_hash`
   - Enqueues an Oban job for parsing
6. **Confirmation**: The user sees the document appear in the document list with a "Parsing..." status indicator.

### Parsing

1. **Job processing**: An Oban worker (`Meddie.Workers.ParseDocument`) picks up the job from the `document_parsing` queue.
2. **Document status**: Updated to `parsing`. The LiveView UI reflects this change in real-time via PubSub broadcast.
3. **Image preparation**:
   - For images (JPG/PNG): The file is fetched from Tigris and sent directly to the vision model as a base64-encoded image.
   - For PDFs: Each page is rendered to an image using `poppler-utils` (`pdftoppm`). Each page image is sent to the vision model individually.
4. **Person context**: The person's health profile (from F2) is included in the AI prompt as additional context for better interpretation.
5. **AI vision call**: The image is sent to the configured vision model (OpenAI or Anthropic) with the parsing prompt (see AI Integration below).
6. **Response parsing**: The AI returns structured JSON. The system:
   - Sets `document_type` based on AI classification (`lab_results`, `medical_report`, or `other`)
   - Stores the `summary` for all document types
   - For `lab_results`: validates the structure and creates `biomarkers` records for each extracted data point
   - For `medical_report` / `other`: stores only the summary, no biomarker records
7. **Completion**: Document status is updated to `parsed`. The LiveView UI updates in real-time.
8. **Failure handling**: If the AI call fails or returns unparseable output, the document status is set to `failed` with an error message. The user can retry parsing.

### Document List

1. **Navigation**: Documents are listed on the person's detail page, grouped by person. Also accessible via a "Documents" link in the navigation.
2. **List display**: Documents are shown in reverse chronological order (newest first).
3. **Document type indicators**: Each document shows its type — lab results (with biomarker count), medical report (with summary excerpt), or other.
4. **Status indicators**: Each document row shows its current status — `pending`, `parsing`, `parsed`, or `failed` — with appropriate visual indicators.
5. **Live updates**: When a document transitions from `parsing` to `parsed`, the LiveView updates the row in real-time without a page refresh.
6. **Click to view**: Clicking a parsed document navigates to its detail view (biomarker results for lab results, summary for medical reports).
7. **Retry failed**: Failed documents have a "Retry" button that re-enqueues the Oban parsing job.
8. **Delete**: Each document has a delete action (with confirmation) that removes the document record, associated biomarkers, and the file from Tigris.

### Document Preview

- **PDFs**: Embedded PDF.js viewer loaded via a LiveView JS hook. The file is accessed via a signed Tigris URL.
- **Images**: Displayed with an `<img>` tag via signed URL.
- **Layout**: The document detail view shows original document and parsed results side by side (or as "Results" / "Original" tabs on smaller screens).
- **Signed URLs**: Generated server-side with a 15-minute expiry. Refreshed on page load.

## Data Model

**documents**

| Column | Type | Constraints |
|--------|------|------------|
| id | `uuid` | PK |
| space_id | `uuid` | FK → spaces, NOT NULL, indexed |
| person_id | `uuid` | FK → people, NOT NULL, indexed |
| filename | `string` | NOT NULL |
| content_type | `string` | NOT NULL |
| file_size | `integer` | NOT NULL |
| storage_path | `string` | NOT NULL |
| status | `string` | NOT NULL, default: `"pending"`, values: `pending`, `parsing`, `parsed`, `failed` |
| document_type | `string` | NOT NULL, default: `"lab_results"`, values: `lab_results`, `medical_report`, `other` |
| summary | `text` | nullable, AI-generated summary of document contents |
| page_count | `integer` | nullable, for PDFs |
| document_date | `date` | nullable, extracted during parsing or set by user |
| error_message | `string` | nullable, populated on failure |
| content_hash | `string` | nullable, SHA-256 hash of file content for deduplication |
| inserted_at | `utc_datetime` | NOT NULL |
| updated_at | `utc_datetime` | NOT NULL |

**biomarkers**

| Column | Type | Constraints |
|--------|------|------------|
| id | `uuid` | PK |
| document_id | `uuid` | FK → documents, NOT NULL, indexed |
| space_id | `uuid` | FK → spaces, NOT NULL, indexed |
| person_id | `uuid` | FK → people, NOT NULL, indexed |
| name | `string` | NOT NULL, indexed — kept in original document language |
| value | `string` | NOT NULL — as shown on the document (e.g., "5,96") |
| numeric_value | `float` | nullable, decimals normalized to dots (e.g., 5.96) |
| unit | `string` | nullable |
| reference_range_low | `float` | nullable |
| reference_range_high | `float` | nullable |
| reference_range_text | `string` | nullable, raw range text as shown on the document |
| status | `string` | NOT NULL, values: `normal`, `low`, `high`, `unknown` |
| page_number | `integer` | nullable, which page this was found on |
| category | `string` | nullable, in original document language (e.g., "Morfologia krwi", "Lipidogram") |
| inserted_at | `utc_datetime` | NOT NULL |
| updated_at | `utc_datetime` | NOT NULL |

**Indexes:**
- `documents.person_id` — find all documents for a person
- `documents.(person_id, content_hash)` — unique index for duplicate detection
- `biomarkers.document_id` — find all biomarkers for a document
- `biomarkers.(person_id, name)` — composite index for per-person trend queries

## Background Jobs (Oban)

Oban is used for document parsing jobs. It stores jobs in PostgreSQL — no Redis required, works on Fly.io.

**Configuration:**
```elixir
config :meddie, Oban,
  repo: Meddie.Repo,
  queues: [default: 10, document_parsing: 3]
```

**Worker: `Meddie.Workers.ParseDocument`**
```elixir
use Oban.Worker,
  queue: :document_parsing,
  max_attempts: 3
```

**Retry strategy**: Exponential backoff — 5s, 30s, 180s. After 3 failed attempts, document status is set to `failed` with the last error message.

**Job flow:**
1. Job is enqueued with `%{document_id: uuid}` after upload completes
2. Worker fetches document record, downloads file from Tigris
3. For PDFs: renders pages to images via `poppler-utils`
4. Sends each page to AI vision model with person context
5. Aggregates results, deduplicates biomarkers across pages
6. Creates biomarker records (for lab results) or stores summary
7. Updates document status to `parsed`
8. Broadcasts update via Phoenix PubSub for LiveView real-time refresh

**On failure**: Worker returns `{:error, reason}`, Oban retries with backoff. On final failure, an `after_error` callback updates the document status to `failed`.

## File Storage (Tigris)

- **Bucket**: `meddie-documents`
- **Path format**: `documents/{space_id}/{person_id}/{document_id}/{filename}`
- **Access**: Private. Files are accessed via signed URLs generated server-side with 15-minute expiry.
- **Library**: Use `ex_aws_s3` configured with Tigris endpoint.
- **Cleanup**: When a document is deleted, the file is also removed from Tigris.

## AI Integration

**Model**: Vision model (e.g., `gpt-4o` or `claude-sonnet-4-5-20250929`)

**Prompt strategy**: System prompt instructs the model to analyze a medical document, classify it, generate a summary, and extract biomarkers when applicable. Person context is included for better interpretation.

**System prompt**:
```
You are a medical document parser. Analyze the provided medical document image.

First, classify the document:
- "lab_results": Laboratory test results, blood work, urine analysis — contains tabular biomarker data with values and reference ranges
- "medical_report": Medical reports (MRI, CT, ultrasound descriptions, specialist consultations, discharge summaries) — narrative text with findings
- "other": Prescriptions, referrals, or other medical documents

Then, for ALL document types:
- Extract the document date if visible
- Write a brief summary (2-4 sentences) of the document contents and key findings. Write the summary in the same language as the document.

Additionally, for lab_results ONLY, extract every biomarker/test result:
- name: The biomarker or test name exactly as written on the document (keep original language, do NOT translate)
- value: The measured value as a string, exactly as shown (e.g., "5,96" with comma if that's how it appears)
- numeric_value: The numeric value normalized to use dots as decimal separators (e.g., 5.96). For values like ">60" or "<1,0", use the number (60 or 1.0)
- unit: The unit of measurement as shown on the document
- reference_range_low: Lower bound of reference range as a number (null if not available)
- reference_range_high: Upper bound of reference range as a number (null if not available)
- reference_range_text: Raw reference range text as shown on the document (e.g., "4,23 - 9,07")
- status: "normal" if within range, "low" if below, "high" if above, "unknown" if range not available
- category: The panel or section name as shown on the document (e.g., "Morfologia krwi", "Lipidogram")

Skip pages that contain only lab metadata, sample information, or administrative details — no biomarkers to extract there.

Return ONLY valid JSON in this format:
{
  "document_type": "lab_results | medical_report | other",
  "document_date": "YYYY-MM-DD or null",
  "summary": "Brief summary of document contents and key findings",
  "biomarkers": [
    {
      "name": "string",
      "value": "string",
      "numeric_value": number or null,
      "unit": "string or null",
      "reference_range_low": number or null,
      "reference_range_high": number or null,
      "reference_range_text": "string or null",
      "status": "normal|low|high|unknown",
      "category": "string or null"
    }
  ]
}

For medical_report and other document types, return an empty biomarkers array.
```

**Person context**: Before the system prompt, include the person's health profile (from F2) so the AI can interpret results in context:
```
## Context: This document belongs to {person_name}
Sex: {sex} | DOB: {date_of_birth} | Height: {height_cm} cm | Weight: {weight_kg} kg
```

**Multi-page handling**: For PDFs with multiple pages, each page is sent as a separate API call. Results are aggregated:
- `document_type` is determined from the first page that contains medical data
- `summary` is merged across pages into a coherent overall summary
- Biomarkers from all pages are combined. Duplicates (same name, same value) are deduplicated — keep the instance with the most complete data
- Pages with only metadata (sample info, lab details) are skipped by the AI

## UI Description

### Upload Area

- A drag-and-drop zone with a "Browse files" button. Accepts `.jpg`, `.jpeg`, `.png`, `.pdf`.
- Person selector above the upload zone (pre-selected if navigating from a person's page).
- Each file shows a progress bar during upload. On completion, the bar is replaced with a checkmark and the parsing status.
- Validation errors displayed inline — "File too large (max 20 MB)" or "Unsupported format".

### Document List

- Listed on a person's page, showing their documents in reverse chronological order.
- Each document shows: date, filename, document type icon (lab/report/other), status badge, biomarker count (for lab results) or summary excerpt (for reports).
- **Status badges**: Green "Parsed" / Yellow "Parsing..." (animated) / Gray "Pending" / Red "Failed".
- **Empty state**: "No documents yet. Upload a medical document to get started."
- **Pagination**: Load 20 documents per page. "Load more" button for additional pages.

### Document Detail View

- **Split layout**: Original document on the left (PDF.js viewer or image), parsed results on the right. Tabbed on mobile ("Results" / "Original").
- **For lab results**: Parsed biomarkers displayed as a structured table grouped by category. Out-of-range values highlighted.
- **For medical reports**: AI-generated summary displayed as formatted text.
- **Document info**: Date, filename, type, page count, upload date.
- **Actions**: Retry parsing, delete document.

### Parsing State

- While parsing, the document card shows a spinning indicator and "Parsing page 2 of 5..." text that updates in real-time via LiveView.
- On completion, the card transitions to show results.
- On failure, the card shows a red "Parsing failed" badge with the error message and a "Retry" button.

## Edge Cases

### Upload
- **File too large**: Max 20 MB per file. Rejected client-side by LiveView's `allow_upload` configuration. Server-side validation as backup.
- **Unsupported format**: Rejected with clear error message. Only `.jpg`, `.jpeg`, `.png`, `.pdf` accepted.
- **Upload interrupted**: LiveView handles disconnection gracefully. Partial uploads are discarded. User can retry.
- **PDF with many pages**: PDFs over 20 pages show a warning. Each page is processed individually during parsing.
- **Concurrent uploads**: Multiple files can be uploaded simultaneously. Each gets its own progress bar and document record.
- **No person selected**: Upload is blocked until a person is selected. If Space has no people, prompt to create one first.
- **Duplicate document**: If the same file (by SHA-256 content hash) has already been uploaded for this person, the upload is skipped with an info message. The same file can still be uploaded for a different person (e.g., shared lab report).

### Parsing
- **Illegible document**: If the AI cannot read the document at all, status is set to `failed` with message "Could not read this document. Please upload a clearer image."
- **Non-biomarker document**: No longer treated as failure. AI classifies it as `medical_report` or `other` and provides a summary.
- **Rate limiting**: If the AI API returns a rate limit error, Oban retries with exponential backoff.
- **Timeout**: AI calls have a 180-second timeout. On timeout, Oban retries the job.
- **Duplicate biomarkers**: If the same biomarker appears multiple times in a document (e.g., repeated across pages), keep only the instance with the most complete data.
- **Polish decimal notation**: The AI converts decimal commas to dots in `numeric_value` (e.g., "5,96" → 5.96). The `value` field preserves the original notation.
- **Ambiguous values**: Values like ">60" or "<1,0" are stored as strings in `value`. `numeric_value` is set to the parsed number (60 or 1.0).
- **Metadata-only pages**: AI skips pages that contain only lab/sample information and no actual results.

### Document Management
- **Many documents**: Paginated with 20 per page.
- **Delete confirmation**: A modal confirms deletion: "This will permanently delete this document and all extracted data. This action cannot be undone."
- **Concurrent parsing**: Multiple documents can be in `parsing` state simultaneously. Each updates independently via separate Oban jobs.
- **Signed URL expiry**: If a user stays on the preview page longer than 15 minutes, the signed URL expires. The page refreshes the URL on focus or interaction.

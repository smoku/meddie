# F4: Biomarker Dashboard & Trends

## Description

A per-person biomarker dashboard that aggregates all parsed lab results into a single view. Biomarkers are grouped by category, with inline SVG sparklines for quick trend visualization and expandable Chart.js charts for detailed trend analysis. Stale results (>6 months old) are visually dimmed. Sparklines also appear on the document show page for historical context.

This feature combines the original F4 (Biomarker Dashboard) and F5 (Trend Tracking) into one cohesive experience.

## Location

The dashboard lives as a **"Biomarkers" tab** on the person show page (`/people/:id?tab=biomarkers`), alongside Overview and Documents tabs. There is no separate trends page — trend expansion happens inline.

## Behavior

### Biomarkers Tab

1. **Tab badge**: The "Biomarkers" tab shows a count badge with the total number of unique biomarkers.
2. **Summary stats**: At the top, a one-line summary: "32 biomarkers — 28 normal, 3 high, 1 low".
3. **Categorized cards**: Biomarkers are grouped by category (e.g., "CBC", "Liver", "Lipid Panel"). Each category renders as a card with a table inside.
4. **Table columns**: Biomarker name (with data point count) | Sparkline | Latest Value | Unit | Reference Range | Status Badge | Date.
5. **Sparklines**: Pure server-side SVG `<polyline>` — no JavaScript. Rendered when a biomarker has 2+ numeric data points. Color follows the latest status (green=normal, red=high, blue=low).
6. **Staleness**: Rows where the latest measurement is older than 180 days are rendered with `opacity-50`.
7. **Row click → Trend expansion**: Clicking a biomarker row toggles an inline expansion below it containing:
   - A Chart.js line chart with time on the x-axis, value on the y-axis, and the reference range as a shaded annotation band.
   - A data table listing each historical measurement: Date, Value, Unit, and a link to the source document.
8. **Empty state**: When no biomarkers exist, shows an icon with "No biomarkers yet. Upload lab results to start tracking biomarkers."
9. **Lazy loading**: Biomarker data is only fetched when the Biomarkers tab is selected (not on mount). Aggregate counts for the badge are fetched cheaply on mount.
10. **Real-time updates**: When a document is parsed (via PubSub), the biomarker counts refresh and the cached biomarker groups are invalidated.

### Document Show Sparklines

On the document show page (`/people/:person_id/documents/:id`), the biomarker table for lab results includes a "Trend" column with sparklines. These sparklines show the biomarker's history across all of the person's documents, providing historical context while viewing a single document.

## Components

### `MeddieWeb.BiomarkerComponents`

Shared component module imported via `html_helpers` into all LiveViews/components:

- **`sparkline/1`** — Pure SVG component. Takes `points` (list of `%{value, status}`). Renders `<svg>` with `<polyline>` and endpoint circle. Normalizes values to a `100x32` viewBox. Handles flat lines (all-same values) by centering at mid-height. Skips rendering for <2 points.
- **`reference_range_bar/1`** — Pure SVG component. Takes `value`, `low`, `high`, `status`. Renders a gray track with a teal reference range segment and a status-colored value marker tick. Labels show low/high numbers. Falls back to empty when data is missing (template shows text instead). Used in both person show and document show biomarker tables.
- **`biomarker_status_badge/1`** — DaisyUI badge colored by status: `normal`=success, `high`=error, `low`=info, `unknown`=ghost.
- **`biomarker_row_class/1`** — Returns CSS class for table row background tinting by status.

### `TrendChart` JS Hook

Chart.js hook (`assets/js/hooks/trend_chart.js`) registered in `app.js`:

- `mounted()`: Parses `data-chart` JSON attribute, creates a Chart.js line chart with:
  - Color-coded points by status (green/red/blue)
  - Time x-axis with month-level ticks
  - Reference range rendered as a `chartjs-plugin-annotation` box annotation
- `destroyed()`: Cleans up chart instance to prevent memory leaks.

## Context Functions

Three query functions in `Meddie.Documents`:

- **`list_person_biomarkers/2`** — Returns all biomarkers for a person from parsed `lab_results` documents, ordered by category → name → document_date. Preloads document.
- **`count_person_biomarkers_by_status/2`** — Lightweight aggregate returning `%{"normal" => N, "high" => N, ...}` for the tab badge and summary stats.
- **`list_biomarker_history/3`** — Takes `(scope, person_id, biomarker_names)`, returns `%{name => [%{numeric_value, status, document_date, ...}]}`. Filters out nil `numeric_value`. Used for document show sparklines.

## Aggregation Logic

`aggregate_biomarkers/1` in the person show LiveView:

1. Groups flat biomarker list by name
2. Picks the latest value per name (last entry, ordered by document date)
3. Builds sparkline points from entries with non-nil `numeric_value`
4. Computes staleness (latest date > 180 days ago)
5. Groups by category for rendering

Returns: `%{category => [%{name, latest, history, sparkline_points, stale?, data_point_count}]}`

## Edge Cases

- **Nil `document_date`**: Falls back to `inserted_at` converted to Date.
- **Nil `numeric_value`**: Skipped for sparklines and charts, still shown in tables.
- **Biomarker name matching**: Exact string match. Cross-language name variations (e.g., "Hemoglobin" vs "Hemoglobina") are treated as separate biomarkers. A future enhancement could add aliasing.
- **Single data point**: No sparkline rendered. Chart shows a single dot.
- **Nil category**: Grouped under "Other" / "Inne".
- **All-same values**: Sparkline renders a flat line at mid-height of the viewBox.
- **Different units across documents**: Values are plotted as-is. Unit consistency is not enforced (known limitation).

## Dependencies

- `chart.js` — charting library
- `chartjs-adapter-date-fns` + `date-fns` — time axis adapter
- `chartjs-plugin-annotation` — reference range band

## Key Files

| File | Role |
|------|------|
| `lib/meddie_web/components/biomarker_components.ex` | Shared sparkline, status badge, row class components |
| `lib/meddie/documents.ex` | Context layer — 3 biomarker query functions |
| `lib/meddie_web/live/people_live/show.ex` | Biomarkers tab, aggregation, trend expansion |
| `lib/meddie_web/live/document_live/show.ex` | Sparklines on document show |
| `assets/js/hooks/trend_chart.js` | Chart.js TrendChart hook |
| `assets/js/app.js` | Hook registration |

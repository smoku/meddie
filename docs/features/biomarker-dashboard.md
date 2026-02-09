# F5: Biomarker Dashboard

## Description

When a user views a parsed document, they see a structured table of all extracted biomarkers organized by category. Out-of-range values are visually flagged.

## Behavior

1. **Navigation**: User clicks a parsed document from the document history (F4). Route: `/documents/:id`.
2. **Data display**: Biomarkers are grouped by category (e.g., "Complete Blood Count", "Lipid Panel"). Within each group, biomarkers are listed alphabetically.
3. **Value flagging**: Values outside reference ranges are color-coded — red for high, blue for low, green for normal, gray for unknown.
4. **Reference range bar**: Each biomarker row includes a visual range bar showing where the value falls relative to the reference range.
5. **Document info**: The top of the page shows the document date, filename, and a link to view the original file (via signed Tigris URL).
6. **Trend link**: Each biomarker name is a link that opens the trend chart (F6) for that biomarker across all documents.

## UI Description

- **Header**: Document date (large), filename, "View original" link.
- **Category sections**: Collapsible sections per category. Each section shows:
  - Biomarker name | Value + Unit | Reference Range | Status | Trend link
- **Range bar**: A horizontal bar visualization:
  - Gray background = full possible range
  - Green zone = reference range
  - A dot/marker = the user's value, colored by status
- **Summary stats**: At the top, show counts: "32 biomarkers — 28 normal, 3 high, 1 low"

## Edge Cases

- **No reference range**: Show the value without a range bar. Status is "unknown" (gray).
- **Non-numeric values**: Some results are text (e.g., "Positive", "Reactive"). These are displayed as-is without a range bar.
- **Uncategorized biomarkers**: Biomarkers without a category are grouped under "Other".
- **Very long document**: If a document has 100+ biomarkers, all categories start collapsed except the first one.

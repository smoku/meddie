# F6: Trend Tracking

## Description

Charts a specific biomarker's values over time across all of a user's parsed documents. Uses a JavaScript charting library (Chart.js or similar) integrated via LiveView JS hooks.

## Behavior

1. **Navigation**: User clicks a biomarker name from the biomarker dashboard (F5), or selects a biomarker from a dropdown on the trends page. Route: `/trends?biomarker=Hemoglobin`.
2. **Data query**: The system fetches all `biomarkers` records for the current user with the selected `name`, ordered by the parent document's `document_date`.
3. **Chart rendering**: A line chart plots the values over time. The reference range is shown as a shaded band on the chart.
4. **Date range**: By default, show all available data. A date range picker allows filtering.
5. **Data table**: Below the chart, a table lists each data point: Date, Value, Unit, Document link.

## UI Description

- **Biomarker selector**: A searchable dropdown at the top listing all unique biomarker names for this user.
- **Line chart**: X-axis = document dates, Y-axis = biomarker values. Reference range shown as a green shaded horizontal band. Data points are dots on the line, colored by status (red/blue/green).
- **Hover tooltip**: Hovering a data point shows: date, value, unit, and which document it came from.
- **Date picker**: Two date inputs (from/to) that filter the chart.
- **Data table**: Below the chart, a simple table with Date, Value, Unit, and a link to the source document.

## JS Hook Implementation

```javascript
// Chart hook using Chart.js
export const BiomarkerChart = {
  mounted() {
    const ctx = this.el.querySelector("canvas").getContext("2d")
    const data = JSON.parse(this.el.dataset.chartData)
    this.chart = new Chart(ctx, {
      type: "line",
      data: {
        labels: data.dates,
        datasets: [{
          label: data.biomarker_name,
          data: data.values,
          // ... config
        }]
      },
      // ... reference range annotation plugin
    })
  },
  updated() {
    // Update chart when LiveView pushes new data
    const data = JSON.parse(this.el.dataset.chartData)
    this.chart.data.labels = data.dates
    this.chart.data.datasets[0].data = data.values
    this.chart.update()
  },
  destroyed() {
    this.chart.destroy()
  }
}
```

## Edge Cases

- **Single data point**: Show the chart with one dot. Display a message: "Upload more documents to see trends."
- **Missing dates**: If a document has no `document_date`, it's excluded from the trend chart but listed in the table with "Date unknown".
- **Different units**: If the same biomarker appears with different units across documents (e.g., "mg/dL" vs "mmol/L"), show a warning and don't connect the line between incompatible units.
- **Biomarker name variations**: The AI prompt standardizes names, but if slight variations exist (e.g., "Hemoglobin" vs "Haemoglobin"), they are treated as separate biomarkers. A future enhancement could add aliasing.

import { Chart, LineController, LineElement, PointElement, LinearScale, TimeScale, Tooltip, Filler } from "chart.js"
import "chartjs-adapter-date-fns"
import annotationPlugin from "chartjs-plugin-annotation"

Chart.register(LineController, LineElement, PointElement, LinearScale, TimeScale, Tooltip, Filler, annotationPlugin)

const statusColors = {
  normal: "oklch(0.62 0.17 155)",
  high: "oklch(0.58 0.22 25)",
  low: "oklch(0.60 0.18 245)",
  unknown: "oklch(0.40 0.015 260)",
}

function getThemeColors() {
  const style = getComputedStyle(document.documentElement)
  const textColor = style.getPropertyValue("color") || "oklch(0.18 0.01 260)"
  const gridColor = "oklch(0.5 0 0 / 0.06)"
  return { textColor, gridColor }
}

const TrendChart = {
  mounted() {
    const data = JSON.parse(this.el.dataset.chart)
    this.renderChart(data)
  },

  renderChart(data) {
    const canvas = document.createElement("canvas")
    this.el.appendChild(canvas)

    const pointColors = data.points.map(p => statusColors[p.status] || statusColors.unknown)
    const { textColor, gridColor } = getThemeColors()

    const annotations = {}
    if (data.reference_low != null && data.reference_high != null) {
      annotations.refBand = {
        type: "box",
        yMin: data.reference_low,
        yMax: data.reference_high,
        backgroundColor: "oklch(0.62 0.17 155 / 0.1)",
        borderWidth: 0,
        label: {
          display: false,
        },
      }
    }

    this.chart = new Chart(canvas, {
      type: "line",
      data: {
        datasets: [{
          label: data.name,
          data: data.points.map(p => ({ x: p.x, y: p.y })),
          borderColor: "oklch(0.55 0.20 255)",
          borderWidth: 2.5,
          pointBackgroundColor: pointColors,
          pointBorderColor: pointColors,
          pointRadius: 5,
          pointHoverRadius: 7,
          tension: 0.2,
          fill: true,
          backgroundColor: "oklch(0.55 0.20 255 / 0.06)",
        }],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          x: {
            type: "time",
            time: {
              unit: "month",
              tooltipFormat: "yyyy-MM-dd",
              displayFormats: { month: "MMM yyyy" },
            },
            grid: { display: false },
            ticks: {
              color: textColor,
              font: { family: "Inter, sans-serif" },
            },
          },
          y: {
            title: {
              display: !!data.unit,
              text: data.unit || "",
              color: textColor,
              font: { family: "Inter, sans-serif" },
            },
            grid: { color: gridColor },
            ticks: {
              color: textColor,
              font: { family: "Inter, sans-serif" },
            },
          },
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (ctx) => `${ctx.parsed.y} ${data.unit || ""}`,
            },
          },
          annotation: { annotations },
        },
      },
    })
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  },
}

export default TrendChart

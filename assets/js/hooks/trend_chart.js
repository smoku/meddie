import { Chart, LineController, LineElement, PointElement, LinearScale, TimeScale, Tooltip, Filler } from "chart.js"
import "chartjs-adapter-date-fns"
import annotationPlugin from "chartjs-plugin-annotation"

Chart.register(LineController, LineElement, PointElement, LinearScale, TimeScale, Tooltip, Filler, annotationPlugin)

const statusColors = {
  normal: "oklch(0.7 0.14 182.503)",
  high: "oklch(0.58 0.253 17.585)",
  low: "oklch(0.62 0.214 259.815)",
  unknown: "oklch(0.55 0.027 264.364)",
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

    const annotations = {}
    if (data.reference_low != null && data.reference_high != null) {
      annotations.refBand = {
        type: "box",
        yMin: data.reference_low,
        yMax: data.reference_high,
        backgroundColor: "oklch(0.7 0.14 182.503 / 0.08)",
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
          borderColor: "oklch(0.55 0.027 264.364)",
          borderWidth: 2,
          pointBackgroundColor: pointColors,
          pointBorderColor: pointColors,
          pointRadius: 4,
          pointHoverRadius: 6,
          tension: 0.2,
          fill: false,
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
          },
          y: {
            title: {
              display: !!data.unit,
              text: data.unit || "",
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

import * as pdfjsLib from "pdfjs-dist"

// Worker is copied to priv/static/assets/js/ by the build process
pdfjsLib.GlobalWorkerOptions.workerSrc = "/assets/js/pdf.worker.min.mjs"

const PdfViewer = {
  async mounted() {
    const url = this.el.dataset.url
    if (!url) return

    this.el.innerHTML =
      '<div class="flex items-center justify-center p-8"><span class="loading loading-spinner loading-md"></span></div>'

    try {
      const loadingTask = pdfjsLib.getDocument(url)
      const pdf = await loadingTask.promise

      this.el.innerHTML = ""

      for (let i = 1; i <= pdf.numPages; i++) {
        const page = await pdf.getPage(i)
        const scale = 1.5
        const viewport = page.getViewport({ scale })

        const canvas = document.createElement("canvas")
        canvas.className = "w-full mb-2"
        canvas.width = viewport.width
        canvas.height = viewport.height
        this.el.appendChild(canvas)

        const ctx = canvas.getContext("2d")
        await page.render({ canvasContext: ctx, viewport }).promise
      }
    } catch (err) {
      this.el.innerHTML = `<p class="text-error text-sm p-4">Failed to load PDF: ${err.message}</p>`
    }
  },

  destroyed() {
    this.el.innerHTML = ""
  },
}

export default PdfViewer

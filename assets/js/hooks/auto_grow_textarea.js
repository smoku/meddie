const AutoGrowTextarea = {
  mounted() {
    this.textarea = this.el
    this.maxHeight = 144 // ~6 lines

    this.textarea.style.overflowY = "hidden"

    this.textarea.addEventListener("input", () => this.resize())

    this.textarea.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault()
        const form = this.textarea.closest("form")
        if (form) {
          form.dispatchEvent(
            new Event("submit", { bubbles: true, cancelable: true })
          )
        }
      }
    })

    this.handleEvent("chat:reset_input", () => {
      this.textarea.value = ""
      this.textarea.style.height = "auto"
      this.textarea.style.overflowY = "hidden"
    })
  },

  updated() {
    this.resize()
  },

  resize() {
    this.textarea.style.height = "auto"
    const newHeight = Math.min(this.textarea.scrollHeight, this.maxHeight)
    this.textarea.style.height = `${newHeight}px`
    this.textarea.style.overflowY =
      this.textarea.scrollHeight > this.maxHeight ? "auto" : "hidden"
  },

  destroyed() {}
}

export default AutoGrowTextarea

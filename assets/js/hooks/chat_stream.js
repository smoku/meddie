const ChatStream = {
  mounted() {
    this.streamingTarget = null

    this.handleEvent("chat:token", ({ text }) => {
      const target = this.el.querySelector("[data-streaming-target]")
      if (target) {
        target.textContent += text
        this.scrollToBottom()
      }
    })

    this.handleEvent("chat:complete", () => {
      // Server will re-render the full message list via LiveView assigns
      // Clear streaming target content since it will be replaced
      const target = this.el.querySelector("[data-streaming-target]")
      if (target) {
        target.textContent = ""
      }
    })

    this.handleEvent("chat:error", ({ message }) => {
      const target = this.el.querySelector("[data-streaming-target]")
      if (target) {
        target.textContent = ""
      }
    })

    // Initial scroll to bottom
    this.scrollToBottom()
  },

  updated() {
    this.scrollToBottom()
  },

  scrollToBottom() {
    requestAnimationFrame(() => {
      this.el.scrollTop = this.el.scrollHeight
    })
  },

  destroyed() {}
}

export default ChatStream

import { marked } from "marked"

marked.setOptions({
  breaks: true,
  gfm: true,
  async: false,
})

const ChatStream = {
  mounted() {
    this.streamingText = ""

    this.handleEvent("chat:token", ({ text }) => {
      const target = this.el.querySelector("[data-streaming-target]")
      if (target) {
        this.streamingText += text
        target.innerHTML = marked.parse(this.streamingText)
        this.scrollToBottom()
      }
    })

    this.handleEvent("chat:complete", () => {
      this.streamingText = ""
      const target = this.el.querySelector("[data-streaming-target]")
      if (target) {
        target.innerHTML = ""
      }
    })

    this.handleEvent("chat:error", ({ message }) => {
      this.streamingText = ""
      const target = this.el.querySelector("[data-streaming-target]")
      if (target) {
        target.innerHTML = ""
      }
    })

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

  destroyed() {
    this.streamingText = ""
  }
}

export default ChatStream

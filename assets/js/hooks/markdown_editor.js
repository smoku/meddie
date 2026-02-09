import { Editor, rootCtx, defaultValueCtx } from "@milkdown/kit/core"
import { commonmark } from "@milkdown/kit/preset/commonmark"
import {
  toggleStrongCommand,
  toggleEmphasisCommand,
  wrapInHeadingCommand,
  wrapInBulletListCommand,
  wrapInOrderedListCommand,
  wrapInBlockquoteCommand,
} from "@milkdown/kit/preset/commonmark"
import { history } from "@milkdown/kit/plugin/history"
import { listener, listenerCtx } from "@milkdown/kit/plugin/listener"
import { callCommand } from "@milkdown/kit/utils"
import "@milkdown/kit/prose/view/style/prosemirror.css"

const TOOLBAR_BUTTONS = [
  { label: "B", title: "Bold (Ctrl+B)", cmd: () => callCommand(toggleStrongCommand.key), cls: "font-bold" },
  { label: "I", title: "Italic (Ctrl+I)", cmd: () => callCommand(toggleEmphasisCommand.key), cls: "italic" },
  { sep: true },
  { label: "H1", title: "Heading 1", cmd: () => callCommand(wrapInHeadingCommand.key, 1) },
  { label: "H2", title: "Heading 2", cmd: () => callCommand(wrapInHeadingCommand.key, 2) },
  { label: "H3", title: "Heading 3", cmd: () => callCommand(wrapInHeadingCommand.key, 3) },
  { sep: true },
  { label: "•", title: "Bullet list", cmd: () => callCommand(wrapInBulletListCommand.key) },
  { label: "1.", title: "Numbered list", cmd: () => callCommand(wrapInOrderedListCommand.key) },
  { label: ">", title: "Quote", cmd: () => callCommand(wrapInBlockquoteCommand.key), cls: "font-mono" },
]

function buildToolbar(editor) {
  const bar = document.createElement("div")
  bar.className = "milkdown-toolbar"

  for (const btn of TOOLBAR_BUTTONS) {
    if (btn.sep) {
      const sep = document.createElement("span")
      sep.className = "milkdown-toolbar-sep"
      bar.appendChild(sep)
      continue
    }

    const el = document.createElement("button")
    el.type = "button"
    el.title = btn.title
    el.textContent = btn.label
    el.className = "milkdown-toolbar-btn" + (btn.cls ? " " + btn.cls : "")
    el.addEventListener("mousedown", (e) => {
      e.preventDefault()
      editor.action(btn.cmd())
    })
    bar.appendChild(el)
  }

  return bar
}

const MarkdownEditor = {
  async mounted() {
    const textarea = this.el.querySelector("textarea")
    if (!textarea) return

    // Hide textarea — Milkdown renders its own WYSIWYG UI
    textarea.style.display = "none"

    // Create wrapper with toolbar + editor
    const wrapper = document.createElement("div")
    wrapper.classList.add("milkdown-wrapper")

    const container = document.createElement("div")
    container.classList.add("milkdown-editor")

    this.editor = await Editor.make()
      .config((ctx) => {
        ctx.set(rootCtx, container)
        ctx.set(defaultValueCtx, textarea.value || "")
        ctx.get(listenerCtx).markdownUpdated((_ctx, markdown) => {
          textarea.value = markdown
          textarea.dispatchEvent(new Event("input", { bubbles: true }))
        })
      })
      .use(commonmark)
      .use(history)
      .use(listener)
      .create()

    // Build toolbar after editor is created (commands available)
    const toolbar = buildToolbar(this.editor)
    wrapper.appendChild(toolbar)
    wrapper.appendChild(container)
    this.el.appendChild(wrapper)
  },

  destroyed() {
    if (this.editor) {
      this.editor.destroy()
      this.editor = null
    }
  },
}

export default MarkdownEditor

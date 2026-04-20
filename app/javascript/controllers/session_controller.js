import { Controller } from "@hotwired/stimulus"
import { marked } from "marked"

export default class extends Controller {
  static targets = ["events", "input", "form", "statusBadge", "fileInput", "filePreview"]
  static values = { url: String, messageUrl: String, attachmentsUrl: String }

  connect() {
    this.listening = false
  }

  async send(event) {
    event.preventDefault()
    const text = this.inputTarget.value.trim()
    const files = this.fileInputTarget.files
    if (!text && files.length === 0) return

    if (files.length > 0) {
      const names = Array.from(files).map(f => f.name).join(", ")
      this.appendEvent("user", `${text}\n📎 ${names}`.trim())
    } else if (text) {
      this.appendEvent("user", text)
    }
    this.inputTarget.value = ""

    if (!this.listening) {
      this.listening = true
      this.startStream()
    }

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    const formData = new FormData()
    formData.append("text", text)
    Array.from(files).forEach(f => formData.append("files[]", f))

    await fetch(this.messageUrlValue, {
      method: "POST",
      headers: { "X-CSRF-Token": csrfToken },
      body: formData
    })

    this.fileInputTarget.value = ""
    this.clearFilePreview()
  }

  startStream() {
    this.eventSource = new EventSource(this.urlValue)
    this.currentMessage = ""

    this.eventSource.onmessage = (e) => {
      const data = JSON.parse(e.data)
      this.handleEvent(data)
    }

    this.eventSource.onerror = () => {
      this.eventSource.close()
      this.listening = false
    }
  }

  handleEvent(data) {
    switch (data.type) {
      case "message":
        this.appendOrUpdateMessage(data.content)
        break
      case "thinking":
        this.appendCollapsible("thinking", "Thinking...", data.content)
        break
      case "tool_use":
        this.appendCollapsible("tool", `Using: ${data.name}`, data.input ? JSON.stringify(data.input, null, 2) : null)
        break
      case "tool_result":
        if (data.content) this.appendCollapsible("tool-result", "Tool result", data.content)
        break
      case "status":
        this.updateStatus(data.status)
        if (data.status === "idle" && data.stop_reason === "end_turn") {
          this.eventSource?.close()
          this.listening = false
          this.showGeneratedFiles()
        }
        break
      case "error":
        this.appendEvent("error", data.message)
        break
    }
  }

  async showGeneratedFiles() {
    try {
      const resp = await fetch(this.attachmentsUrlValue, {
        headers: { "Accept": "application/json" }
      })
      if (!resp.ok) return

      const data = await resp.json()
      const outputs = data.outputs || []
      outputs.forEach(file => {
        const el = document.createElement("div")
        el.className = "rounded-lg p-3 border bg-emerald-50 border-emerald-200 flex items-center justify-between"
        el.innerHTML = `
          <span class="text-sm text-emerald-800">${this.escapeHtml(file.filename)}</span>
          <a href="${file.url}" target="_blank" rel="noopener"
             class="text-xs text-emerald-700 font-medium hover:text-emerald-900">Open ↗</a>
        `
        this.eventsTarget.appendChild(el)
      })
      this.scrollToBottom()
    } catch (e) {
      // Silently fail — files will be visible on reload
    }
  }

  appendOrUpdateMessage(content) {
    let el = this.eventsTarget.querySelector("[data-role='assistant-message']:last-child")
    if (!el) {
      el = document.createElement("div")
      el.dataset.role = "assistant-message"
      el.className = "prose prose-sm max-w-none bg-white rounded-lg p-4 border border-gray-200"
      this.eventsTarget.appendChild(el)
    }
    this.currentMessage += content
    el.innerHTML = marked.parse(this.currentMessage)
    this.scrollToBottom()
  }

  appendEvent(type, content) {
    if (type === "message") this.currentMessage = ""

    const styles = {
      user: "bg-indigo-50 text-indigo-900 border-indigo-200",
      error: "bg-red-50 text-red-800 border-red-200"
    }

    const el = document.createElement("div")
    el.className = `rounded-lg p-3 border ${styles[type] || "bg-white border-gray-200"}`
    el.textContent = content
    this.eventsTarget.appendChild(el)
    this.scrollToBottom()
  }

  appendCollapsible(type, summary, details) {
    const styles = {
      thinking: { summary: "bg-amber-50 text-amber-800 border-amber-200 text-xs italic", details: "bg-amber-25 text-amber-700" },
      tool: { summary: "bg-gray-100 text-gray-600 border-gray-200 text-xs font-mono", details: "text-gray-500 font-mono" },
      "tool-result": { summary: "bg-gray-50 text-gray-500 border-gray-100 text-xs", details: "text-gray-400" }
    }
    const style = styles[type] || { summary: "bg-white border-gray-200", details: "" }

    const el = document.createElement("details")
    el.className = `rounded-lg border ${style.summary}`

    const summaryEl = document.createElement("summary")
    summaryEl.className = "p-3 cursor-pointer select-none list-none flex items-center gap-2"
    summaryEl.innerHTML = `<svg class="w-3 h-3 transition-transform details-arrow shrink-0" viewBox="0 0 12 12"><path d="M4 2l4 4-4 4" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>${this.escapeHtml(summary)}`
    el.appendChild(summaryEl)

    if (details) {
      const contentEl = document.createElement("div")
      contentEl.className = `px-3 pb-3 pt-0 text-xs whitespace-pre-wrap break-all ${style.details}`
      contentEl.textContent = details
      el.appendChild(contentEl)
    }

    this.eventsTarget.appendChild(el)
    this.scrollToBottom()
  }

  updateStatus(status) {
    const badge = this.statusBadgeTarget
    badge.textContent = status
    const colors = {
      running: "bg-blue-100 text-blue-800",
      idle: "bg-green-100 text-green-800",
      terminated: "bg-red-100 text-red-800"
    }
    badge.className = `px-3 py-1 rounded-full text-xs font-medium ${colors[status] || "bg-gray-100 text-gray-800"}`
  }

  filesChanged() {
    const files = this.fileInputTarget.files
    const preview = this.filePreviewTarget
    preview.innerHTML = ""
    if (files.length === 0) {
      preview.classList.add("hidden")
      return
    }
    preview.classList.remove("hidden")
    Array.from(files).forEach(f => {
      const tag = document.createElement("span")
      tag.className = "inline-flex items-center gap-1 bg-blue-50 border border-blue-200 rounded-md px-2 py-1 text-xs text-blue-700"
      tag.textContent = `📎 ${f.name}`
      preview.appendChild(tag)
    })
  }

  clearFilePreview() {
    this.filePreviewTarget.innerHTML = ""
    this.filePreviewTarget.classList.add("hidden")
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  scrollToBottom() {
    this.eventsTarget.scrollTop = this.eventsTarget.scrollHeight
  }

  disconnect() {
    this.eventSource?.close()
  }
}

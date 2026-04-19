import { Controller } from "@hotwired/stimulus"
import { marked } from "marked"

export default class extends Controller {
  static targets = ["events", "input", "form", "statusBadge", "reportLink"]
  static values = { url: String, messageUrl: String }

  connect() {
    this.listening = false
  }

  async send(event) {
    event.preventDefault()
    const text = this.inputTarget.value.trim()
    if (!text) return

    this.appendEvent("user", text)
    this.inputTarget.value = ""

    if (!this.listening) {
      this.listening = true
      this.startStream()
    }

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    await fetch(this.messageUrlValue, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded", "X-CSRF-Token": csrfToken },
      body: `text=${encodeURIComponent(text)}`
    })
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
        this.appendEvent("thinking", data.content || "Thinking...")
        break
      case "tool_use":
        this.appendEvent("tool", `Using: ${data.name}`)
        break
      case "tool_result":
        if (data.content) this.appendEvent("tool-result", data.content)
        break
      case "status":
        this.updateStatus(data.status)
        if (data.status === "idle" && data.stop_reason === "end_turn") {
          this.eventSource?.close()
          this.listening = false
          this.reportLinkTarget.classList.remove("hidden")
        }
        break
      case "error":
        this.appendEvent("error", data.message)
        break
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
      thinking: "bg-amber-50 text-amber-800 border-amber-200 text-xs italic",
      tool: "bg-gray-100 text-gray-600 border-gray-200 text-xs font-mono",
      "tool-result": "bg-gray-50 text-gray-500 border-gray-100 text-xs",
      error: "bg-red-50 text-red-800 border-red-200"
    }

    const el = document.createElement("div")
    el.className = `rounded-lg p-3 border ${styles[type] || "bg-white border-gray-200"}`
    el.textContent = content
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

  scrollToBottom() {
    this.eventsTarget.scrollTop = this.eventsTarget.scrollHeight
  }

  disconnect() {
    this.eventSource?.close()
  }
}

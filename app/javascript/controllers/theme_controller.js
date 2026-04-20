import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["lightBtn", "darkBtn", "systemBtn"]

  connect() {
    this.mediaQuery = matchMedia("(prefers-color-scheme: dark)")
    this.handleSystemChange = () => this.applyTheme()
    this.mediaQuery.addEventListener("change", this.handleSystemChange)
    this.applyTheme()
    this.updateButtons()
  }

  disconnect() {
    this.mediaQuery.removeEventListener("change", this.handleSystemChange)
  }

  light() {
    localStorage.theme = "light"
    this.applyTheme()
    this.updateButtons()
  }

  dark() {
    localStorage.theme = "dark"
    this.applyTheme()
    this.updateButtons()
  }

  system() {
    localStorage.removeItem("theme")
    this.applyTheme()
    this.updateButtons()
  }

  applyTheme() {
    const pref = localStorage.theme
    if (pref === "dark" || (!pref && this.mediaQuery.matches)) {
      document.documentElement.classList.add("dark")
    } else {
      document.documentElement.classList.remove("dark")
    }
  }

  updateButtons() {
    const pref = localStorage.theme
    const active = "text-gray-900 dark:text-gray-100"
    const inactive = "text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300"

    ;[this.lightBtnTarget, this.darkBtnTarget, this.systemBtnTarget].forEach(btn => {
      btn.className = `p-1.5 rounded-md transition ${inactive}`
    })

    const target = pref === "light" ? this.lightBtnTarget : pref === "dark" ? this.darkBtnTarget : this.systemBtnTarget
    target.className = `p-1.5 rounded-md transition ${active}`
  }
}

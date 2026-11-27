// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/certfy"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Global hooks.
const ConfirmDialog = {
  mounted() {
    this.dialog = document.getElementById("confirm-dialog")
    this.pending = null

    this.onCapture = (e) => {
      const trigger = e.target.closest("[data-confirm]")
      if (!trigger || !this.dialog) return

      e.preventDefault()
      e.stopImmediatePropagation()

      const messageEl = this.dialog.querySelector("[data-confirm-message]")
      if (messageEl) messageEl.textContent = trigger.getAttribute("data-confirm")

      this.pending = trigger
      this.dialog.showModal()
      this.dialog.querySelector("[data-confirm-cancel]")?.focus()
    }

    this.onConfirm = () => {
      if (!this.pending) return
      this.dialog.close()

      const trigger = this.pending
      this.pending = null
      trigger.removeAttribute("data-confirm")
      trigger.click()
    }

    this.onCancel = () => {
      this.pending = null
      this.dialog.close()
    }

    document.addEventListener("click", this.onCapture, true)
    this.dialog?.querySelector("[data-confirm-ok]")?.addEventListener("click", this.onConfirm)
    this.dialog?.querySelector("[data-confirm-cancel]")?.addEventListener("click", this.onCancel)
    this.dialog?.addEventListener("close", this.onCancel)
  },
  destroyed() {
    document.removeEventListener("click", this.onCapture, true)
  },
}

const Dropdown = {
  mounted() {
    this.onClick = (e) => {
      const dropdown = e.target.closest(".dropdown")
      if (!dropdown) {
        if (document.activeElement && document.activeElement.closest?.(".dropdown")) {
          document.activeElement.blur()
        }
      } else if (e.target.closest(".dropdown-content")) {
        dropdown.querySelector("[tabindex]")?.blur()
      }
    }
    document.addEventListener("click", this.onClick)
  },
  destroyed() {
    document.removeEventListener("click", this.onClick)
  },
}

const UnsavedChanges = {
  mounted() {
    this.dirty = false
    this.onChange = () => {
      this.dirty = true
    }
    this.onSubmit = () => {
      this.dirty = false
    }
    this.beforeUnload = (e) => {
      if (!this.dirty) return
      e.preventDefault()
      e.returnValue = ""
    }

    this.el.addEventListener("input", this.onChange)
    this.el.addEventListener("change", this.onChange)
    this.el.addEventListener("submit", this.onSubmit)
    window.addEventListener("beforeunload", this.beforeUnload)
  },
  destroyed() {
    window.removeEventListener("beforeunload", this.beforeUnload)
  },
}

const Drawer = {
  mounted() {
    this.onClick = (e) => {
      if (e.target.closest("a")) {
        const toggle = this.el.querySelector(".drawer-toggle")
        if (toggle) toggle.checked = false
      }
    }
    this.el.addEventListener("click", this.onClick)
  },
  destroyed() {
    this.el.removeEventListener("click", this.onClick)
  },
}

// Turns a native <select> into a combobox with a local, accent-insensitive
// search. The native select stays in the form and receives a `change` event
// when an option is picked, so LiveView handles it like a regular select.
const normalize = (text) =>
  (text || "")
    .toString()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")

const SearchableSelect = {
  mounted() {
    this.trigger = this.el.querySelector("[data-trigger]")
    this.label = this.el.querySelector("[data-label]")
    this.select = this.el.querySelector("select")
    this.popup = this.el.querySelector("[data-popup]")
    this.search = this.el.querySelector("[data-search]")
    this.list = this.el.querySelector("[data-list]")
    this.empty = this.el.querySelector("[data-empty]")
    this.placeholder = this.el.dataset.placeholder || ""
    this.active = null

    this.onTriggerClick = (e) => {
      e.preventDefault()
      this.isOpen() ? this.close() : this.open()
    }
    this.onSearchInput = (e) => {
      e.stopPropagation()
      this.filter()
    }
    this.onSearchChange = (e) => e.stopPropagation()
    this.onSearchKeydown = (e) => this.onKeydown(e)
    this.onOptionClick = (e) => {
      const option = e.target.closest("[data-option]")
      if (option) this.selectValue(option.dataset.value)
    }
    this.onDocumentPointer = (e) => {
      if (this.isOpen() && !this.el.contains(e.target)) this.close()
    }
    this.onWindowScroll = (e) => {
      if (!this.isOpen()) return
      if (this.popup.contains(e.target)) return
      this.close()
    }
    this.onResize = () => this.close()

    this.trigger.addEventListener("click", this.onTriggerClick)
    this.search.addEventListener("input", this.onSearchInput)
    this.search.addEventListener("change", this.onSearchChange)
    this.search.addEventListener("keydown", this.onSearchKeydown)
    this.list.addEventListener("click", this.onOptionClick)
    document.addEventListener("pointerdown", this.onDocumentPointer)
    window.addEventListener("scroll", this.onWindowScroll, true)
    window.addEventListener("resize", this.onResize)

    this.syncLabel()
    this.syncSelected()
  },

  updated() {
    this.syncLabel()
    this.syncSelected()
    if (this.isOpen()) this.close()
  },

  destroyed() {
    this.trigger.removeEventListener("click", this.onTriggerClick)
    this.search.removeEventListener("input", this.onSearchInput)
    this.search.removeEventListener("change", this.onSearchChange)
    this.search.removeEventListener("keydown", this.onSearchKeydown)
    this.list.removeEventListener("click", this.onOptionClick)
    document.removeEventListener("pointerdown", this.onDocumentPointer)
    window.removeEventListener("scroll", this.onWindowScroll, true)
    window.removeEventListener("resize", this.onResize)
  },

  isOpen() {
    return !this.popup.hidden
  },

  options() {
    return Array.from(this.list.querySelectorAll("[data-option]"))
  },

  syncLabel() {
    const option = this.select.selectedOptions[0]
    const hasValue = option && option.value !== ""
    const text = hasValue ? option.textContent.trim() : this.placeholder

    this.label.textContent = text
    this.label.classList.toggle("text-base-content/50", !hasValue)
    this.trigger.title = text
  },

  syncSelected() {
    const value = this.select.value
    this.options().forEach((option) => {
      option.setAttribute("aria-selected", option.dataset.value === value ? "true" : "false")
    })
  },

  open() {
    this.popup.hidden = false
    this.trigger.setAttribute("aria-expanded", "true")
    this.search.value = ""
    this.filter()
    this.position()
    this.centerOnSelected()
    this.search.focus()
  },

  close() {
    if (!this.isOpen()) return
    this.popup.hidden = true
    this.trigger.setAttribute("aria-expanded", "false")
    this.search.value = ""
  },

  position() {
    const margin = 8
    const rect = this.trigger.getBoundingClientRect()
    const width = Math.min(Math.max(rect.width, 260), window.innerWidth - margin * 2)
    const left = Math.min(Math.max(rect.left, margin), window.innerWidth - width - margin)

    this.popup.style.width = `${width}px`
    this.popup.style.left = `${left}px`
    this.popup.style.top = "0px"

    const height = this.popup.offsetHeight
    const below = rect.bottom + 4
    const above = rect.top - height - 4
    const fitsBelow = below + height <= window.innerHeight - margin
    const top = !fitsBelow && above > margin ? above : below

    this.popup.style.top = `${top}px`
  },

  centerOnSelected() {
    const selected = this.list.querySelector('[aria-selected="true"]')
    if (selected) selected.scrollIntoView({block: "nearest"})
  },

  filter() {
    const term = normalize(this.search.value.trim())
    let first = null

    this.options().forEach((option) => {
      const matches = normalize(option.dataset.label).includes(term)
      option.hidden = !matches
      option.classList.remove("bg-base-200")
      if (matches && !first) first = option
    })

    this.empty.hidden = first !== null
    this.setActive(first)
    this.list.scrollTop = 0
  },

  setActive(option) {
    if (this.active) this.active.classList.remove("bg-base-200")
    this.active = option
    if (!option) return

    option.classList.add("bg-base-200")
    option.scrollIntoView({block: "nearest"})
  },

  moveActive(delta) {
    const visible = this.options().filter((option) => !option.hidden)
    if (visible.length === 0) return

    const current = visible.indexOf(this.active)
    const index = current === -1 ? 0 : (current + delta + visible.length) % visible.length

    this.setActive(visible[index])
  },

  onKeydown(e) {
    if (e.key === "Escape") {
      e.preventDefault()
      this.close()
      this.trigger.focus()
    } else if (e.key === "Tab") {
      this.close()
    } else if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault()
      this.moveActive(e.key === "ArrowDown" ? 1 : -1)
    } else if (e.key === "Enter") {
      e.preventDefault()
      if (this.active) this.selectValue(this.active.dataset.value)
    }
  },

  selectValue(value) {
    this.select.value = value
    this.select.dispatchEvent(new Event("change", {bubbles: true}))
    this.syncLabel()
    this.syncSelected()
    this.close()
    this.trigger.focus()
  },
}

const CopyTag = {
  mounted() {
    this.onClick = async () => {
      try {
        await navigator.clipboard.writeText(this.el.dataset.copy || "")
        this.el.classList.add("text-success")
        setTimeout(() => this.el.classList.remove("text-success"), 1200)
      } catch (_error) {
        // Clipboard may be unavailable; the tag remains visible in the table.
      }
    }
    this.el.addEventListener("click", this.onClick)
  },
  destroyed() {
    this.el.removeEventListener("click", this.onClick)
  },
}
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ConfirmDialog, Dropdown, UnsavedChanges, Drawer, SearchableSelect, CopyTag},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#1F5C4A"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}


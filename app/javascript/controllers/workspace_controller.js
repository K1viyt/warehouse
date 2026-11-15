import { Controller } from "@hotwired/stimulus"
import { request, ApiError } from "lib/api"
import { escapeHtml as html, errorMessage, productImage, statusLabel, roleLabel } from "lib/presentation"

export default class extends Controller {
  static targets = ["content", "toast", "page", "drawer", "drawerContent", "loginTemplate", "registerTemplate", "pendingTemplate", "registeredTemplate", "shellTemplate", "catalogTemplate", "usersTemplate", "profileTemplate", "productFormTemplate"]
  static values = { images: Object }

  connect() {
    this.mode = "cards"
    this.usersPage = 1
    this.usersStatus = ""
    this.products = []
    this.onHistory = () => this.openView(location.hash.slice(1) || "catalog", false)
    this.onDrawerClose = () => this.opener?.focus()
    window.addEventListener("popstate", this.onHistory)
    this.drawerTarget.addEventListener("close", this.onDrawerClose)
    this.boot()
  }

  disconnect() {
    this.productsAbort?.abort()
    this.usersAbort?.abort()
    clearTimeout(this.toastTimer)
    window.removeEventListener("popstate", this.onHistory)
    this.drawerTarget.removeEventListener("close", this.onDrawerClose)
  }

  async boot() {
    try {
      this.user = await request("/me")
      this.openView(location.hash.slice(1) || "catalog", false)
    } catch (error) {
      this.user = null
      this.openView(location.hash === "#register" ? "register" : "login", false)
      if (error.status !== 401) this.showError(this.contentTarget, error)
    } finally {
      this.contentTarget.setAttribute("aria-busy", "false")
    }
  }

  clone(name) { return this[`${name}TemplateTarget`].content.cloneNode(true) }

  navigate(event) {
    event.preventDefault()
    this.openView(event.currentTarget.dataset.view)
  }

  openView(view, history = true) {
    const requestedView = view
    if (this.drawerTarget.open) this.drawerTarget.close()
    this.productsAbort?.abort()
    this.usersAbort?.abort()
    if (!this.user) view = ["register", "registered"].includes(view) ? view : "login"
    else if (this.user.status === "pending") view = "pending"
    else if (!["catalog", "users", "profile"].includes(view)) view = "catalog"
    if (view === "users" && this.user?.role !== "admin") view = "catalog"
    this.view = view
    if (history) window.history.pushState({}, "", `#${view}`)
    else if (requestedView !== view) window.history.replaceState({}, "", `#${view}`)
    if (["login", "register", "pending", "registered"].includes(view)) {
      this.contentTarget.replaceChildren(this.clone(view))
      if (view === "pending") this.contentTarget.querySelector(".pending-email").textContent = this.user.email_address || ""
      document.title = `${view === "register" ? "Заявка на доступ" : view === "pending" ? "Ожидание активации" : "Вход"} — СЕКЦИЯ`
      return
    }
    if (!this.hasPageTarget) this.contentTarget.replaceChildren(this.clone("shell"))
    this.contentTarget.querySelector(".current-user-name").textContent = this.user.name
    this.contentTarget.querySelector(".current-user-role").textContent = roleLabel(this.user.role)
    this.contentTarget.querySelectorAll("[data-admin-only]").forEach(node => { node.hidden = this.user.role !== "admin" })
    this.contentTarget.querySelectorAll("nav [data-view]").forEach(node => {
      if (node.dataset.view === view) node.setAttribute("aria-current", "page")
      else node.removeAttribute("aria-current")
    })
    this.contentTarget.querySelector(".workspace-shell").classList.remove("menu-open")
    const menu = this.contentTarget.querySelector(".mobile-header button")
    menu.setAttribute("aria-expanded", "false")
    this.pageTarget.replaceChildren(this.clone(view))
    document.title = `${({ catalog: "Товары", users: "Пользователи", profile: "Профиль" })[view]} — СЕКЦИЯ`
    if (view === "catalog") this.loadProducts()
    if (view === "users") this.loadUsers()
    if (view === "profile") this.renderProfile()
    if (history) this.pageTarget.focus()
  }

  async submitForm(event, action) {
    event.preventDefault()
    const form = event.currentTarget
    if (form.dataset.busy === "true") return
    this.clearError(form)
    const button = form.querySelector('[type="submit"]')
    form.dataset.busy = "true"
    form.setAttribute("aria-busy", "true")
    button.disabled = true
    try { await action(Object.fromEntries(new FormData(form)), form) }
    catch (error) { this.showError(form, error) }
    finally { form.dataset.busy = "false"; form.setAttribute("aria-busy", "false"); button.disabled = false }
  }

  login(event) {
    this.submitForm(event, async login => {
      await request("/session", { method: "POST", body: { login } })
      // Reload the HTML after session rotation to obtain its new CSRF token.
      window.location.assign("/")
    })
  }

  register(event) {
    this.submitForm(event, async (user, form) => {
      if (user.password !== user.password_confirmation) {
        throw new ApiError(422, { error: "Password confirmation doesn't match Password" })
      }
      await request("/registrations", { method: "POST", body: { user } })
      form.reset()
      this.openView("registered")
    })
  }

  togglePassword(event) {
    const button = event.currentTarget
    const input = button.parentElement.querySelector("input")
    const show = input.type === "password"
    input.type = show ? "text" : "password"
    button.textContent = show ? "Скрыть" : "Показать"
    button.setAttribute("aria-label", show ? "Скрыть пароль" : "Показать пароль")
    button.setAttribute("aria-pressed", String(show))
  }

  async logout(event) {
    const button = event.currentTarget
    if (button.disabled) return
    button.disabled = true
    try { await request("/session", { method: "DELETE" }); window.location.assign("/") }
    catch (error) { this.notify(errorMessage(error)); button.disabled = false }
  }

  async checkStatus(event) {
    const button = event.currentTarget
    if (button.disabled) return
    button.disabled = true
    this.clearError(this.contentTarget)
    try {
      this.user = await request("/me")
      if (this.user.status === "active") this.openView("catalog")
      else this.notify("Заявка всё ещё на рассмотрении. Проверьте статус позже.")
    } catch (error) { this.handleAccess(error, this.contentTarget) }
    finally { button.disabled = false }
  }

  toggleMenu(event) {
    const open = this.contentTarget.querySelector(".workspace-shell").classList.toggle("menu-open")
    event.currentTarget.setAttribute("aria-expanded", String(open))
  }

  async loadProducts() {
    if (this.view !== "catalog") return
    this.productsAbort?.abort()
    const controller = new AbortController()
    this.productsAbort = controller
    const area = this.pageTarget.querySelector(".catalog-content")
    this.clearError(this.pageTarget)
    area.setAttribute("aria-busy", "true")
    area.innerHTML = '<div class="loading-state">Загружаем каталог…</div>'
    try {
      this.products = await request("/products", { signal: controller.signal })
      if (controller.signal.aborted || this.view !== "catalog") return
      this.renderProducts()
    } catch (error) {
      if (error.name === "AbortError") return
      area.replaceChildren()
      this.handleAccess(error, this.pageTarget)
    } finally { area.setAttribute("aria-busy", "false") }
  }

  setView(event) { this.mode = event.currentTarget.dataset.mode; this.renderProducts() }

  renderProducts() {
    if (this.view !== "catalog") return
    const area = this.pageTarget.querySelector(".catalog-content")
    this.pageTarget.querySelector(".catalog-count").textContent = `${this.products.length} ПОЗИЦИЙ`
    this.pageTarget.querySelectorAll("[data-mode]").forEach(node => node.setAttribute("aria-pressed", String(node.dataset.mode === this.mode)))
    if (!this.products.length) {
      area.innerHTML = '<div class="empty-state"><span class="section-index">КАТАЛОГ НАЧИНАЕТСЯ ЗДЕСЬ</span><h2>Место для первой детали.</h2><p>Добавьте товар: название, артикул и единицу измерения.</p><button class="button button--primary" data-action="workspace#newProduct">＋ Добавить товар</button></div>'
      return
    }
    if (this.mode === "cards") {
      area.innerHTML = `<div class="product-grid">${this.products.map((p, index) => `<button class="product-card" data-action="workspace#showProduct" data-id="${html(p.id)}" aria-label="Открыть товар ${html(p.name)}"><div class="product-card__visual"><img src="${html(productImage(p, this.imagesValue))}" alt="" loading="lazy" width="680" height="960"><span class="product-card__number mono">${String(index + 1).padStart(2, "0")}</span><span class="product-card__open" aria-hidden="true">↗</span></div><div class="product-card__body"><h2>${html(p.name)}</h2><div class="product-card__meta"><span><small>АРТИКУЛ</small><span class="mono">${html(p.sku)}</span></span><span><small>ЕДИНИЦА</small><span>${html(p.unit)}</span></span></div></div></button>`).join("")}</div>`
    } else {
      area.innerHTML = `<div class="table-scroll"><table class="data-table"><caption class="sr-only">Каталог товаров</caption><thead><tr><th>Артикул</th><th>Наименование</th><th>Единица</th><th><span class="sr-only">Открыть</span></th></tr></thead><tbody>${this.products.map(p => `<tr><td class="mono">${html(p.sku)}</td><td><button class="table-link" data-action="workspace#showProduct" data-id="${html(p.id)}">${html(p.name)}</button></td><td>${html(p.unit)}</td><td aria-hidden="true">↗</td></tr>`).join("")}</tbody></table></div>`
    }
  }

  openDrawer(event) {
    this.opener = event?.currentTarget || document.activeElement
    this.drawerTarget.showModal()
  }

  newProduct(event) {
    this.detailId = null
    this.drawerContentTarget.replaceChildren(this.clone("productForm"))
    this.openDrawer(event)
  }

  closeDrawer() { this.detailId = null; this.drawerTarget.close() }

  async showProduct(event) {
    this.drawerContentTarget.innerHTML = '<h2 id="drawer-title">Детали товара</h2><div class="loading-state">Загружаем…</div><div class="form-error" role="alert" tabindex="-1" hidden></div>'
    this.openDrawer(event)
    const id = event.currentTarget.dataset.id
    this.detailId = id
    try {
      const p = await request(`/products/${encodeURIComponent(id)}`)
      if (!this.drawerTarget.open || this.detailId !== id) return
      this.drawerContentTarget.innerHTML = `<h2 id="drawer-title">${html(p.name)}</h2><p class="mono detail-sku">${html(p.sku)}</p><img class="detail-image" src="${html(productImage(p, this.imagesValue))}" alt="Типовое изображение материала"><p class="field-hint">Иллюстрация типа товара. Точные характеристики определяются артикулом.</p><dl class="detail-list"><div><dt>Наименование</dt><dd>${html(p.name)}</dd></div><div><dt>Артикул</dt><dd class="mono">${html(p.sku)}</dd></div><div><dt>Единица измерения</dt><dd>${html(p.unit)}</dd></div></dl>`
    } catch (error) { this.handleAccess(error, this.drawerContentTarget) }
  }

  createProduct(event) {
    this.submitForm(event, async product => {
      await request("/products", { method: "POST", body: { product } })
      this.closeDrawer()
      this.notify("Товар создан и добавлен в каталог.")
      await this.loadProducts()
    })
  }

  filterUsers(event) {
    this.usersStatus = event.currentTarget.dataset.status
    this.usersPage = 1
    this.loadUsers()
  }

  async loadUsers() {
    if (this.view !== "users") return
    this.usersAbort?.abort()
    const controller = new AbortController()
    this.usersAbort = controller
    const area = this.pageTarget.querySelector(".users-content")
    this.clearError(this.pageTarget)
    this.pageTarget.querySelectorAll("[data-status]").forEach(node => node.setAttribute("aria-pressed", String(node.dataset.status === this.usersStatus)))
    area.setAttribute("aria-busy", "true")
    area.innerHTML = '<div class="loading-state">Загружаем пользователей…</div>'
    try {
      const params = new URLSearchParams({ page: this.usersPage, per_page: 10 })
      if (this.usersStatus) params.set("status", this.usersStatus)
      const data = await request(`/admin/users?${params}`, { signal: controller.signal })
      if (controller.signal.aborted || this.view !== "users") return
      this.pagination = data.pagination
      if (data.pagination.total > 0 && data.users.length === 0 && this.usersPage > 1) {
        this.usersPage = Math.max(1, data.pagination.total_pages)
        return this.loadUsers()
      }
      area.innerHTML = data.users.length ? `<div class="table-scroll"><table class="data-table users-table"><caption class="sr-only">Пользователи системы</caption><thead><tr><th>Пользователь</th><th>Роль</th><th>Статус</th><th>Действие</th></tr></thead><tbody>${data.users.map(user => `<tr><td><strong>${html(user.name)}</strong><span class="user-email">${html(user.email_address)}</span></td><td>${html(roleLabel(user.role))}</td><td><span class="badge badge--${html(user.status)}">${html(statusLabel(user.status))}</span></td><td>${this.userAction(user)}</td></tr>`).join("")}</tbody></table></div>` : '<div class="empty-state"><h2>Здесь пока никого.</h2><p>Пользователей с выбранным статусом нет.</p></div>'
      this.pageTarget.querySelector(".pagination-label").textContent = `Страница ${data.pagination.page} из ${Math.max(1, data.pagination.total_pages)} · Всего ${data.pagination.total}`
      this.pageTarget.querySelector('[data-action="workspace#previousPage"]').disabled = this.usersPage <= 1
      this.pageTarget.querySelector('[data-action="workspace#nextPage"]').disabled = this.usersPage >= data.pagination.total_pages
    } catch (error) {
      if (error.name === "AbortError") return
      area.replaceChildren()
      this.handleAccess(error, this.pageTarget)
    } finally { area.setAttribute("aria-busy", "false") }
  }

  userAction(user) {
    if (user.role === "admin" && user.status === "active") return '<span class="muted">—</span>'
    const action = ({ pending: "activate", active: "block", blocked: "unblock" })[user.status]
    const label = ({ activate: "Активировать", block: "Заблокировать", unblock: "Разблокировать" })[action]
    return action ? `<button class="button ${action === "activate" ? "button--primary" : "button--quiet"}" data-action="workspace#changeUser" data-id="${html(user.id)}" data-operation="${action}">${label}</button>` : ""
  }

  async changeUser(event) {
    const button = event.currentTarget
    if (button.disabled) return
    button.disabled = true
    try {
      const user = await request(`/admin/users/${encodeURIComponent(button.dataset.id)}/${button.dataset.operation}`, { method: "PATCH" })
      this.notify(`${user.name}: ${statusLabel(user.status).toLowerCase()}.`)
      await this.loadUsers()
    } catch (error) { this.handleAccess(error, this.hasPageTarget ? this.pageTarget : this.contentTarget) }
    finally { button.disabled = false }
  }

  previousPage() { if (this.usersPage > 1) { this.usersPage--; this.loadUsers() } }
  nextPage() { if (this.usersPage < this.pagination?.total_pages) { this.usersPage++; this.loadUsers() } }

  renderProfile() {
    const user = this.user
    this.pageTarget.querySelector(".profile-content").innerHTML = `<div class="profile-card"><div class="profile-avatar" aria-hidden="true">${html(user.name?.charAt(0).toUpperCase())}</div><h2>${html(user.name)}</h2><p class="muted">${html(user.email_address)}</p><dl class="detail-list"><div><dt>Роль</dt><dd>${html(roleLabel(user.role))}</dd></div><div><dt>Статус</dt><dd><span class="badge badge--${html(user.status)}">${html(statusLabel(user.status))}</span></dd></div></dl></div>`
  }

  clearError(container) {
    const node = container.querySelector(".form-error")
    if (node) { node.hidden = true; node.textContent = "" }
  }

  showError(container, error) {
    const node = container.querySelector(".form-error")
    if (!node) return this.notify(errorMessage(error))
    node.textContent = errorMessage(error)
    node.hidden = false
    node.focus()
  }

  handleAccess(error, container) {
    if (error.status === 401 || error.body?.error === "Your access has been blocked") {
      this.user = null
      this.openView("login")
      this.showError(this.contentTarget, error)
    } else if (error.body?.error === "Account is pending activation") {
      this.user.status = "pending"
      this.openView("pending")
    } else this.showError(container, error)
  }

  notify(message) {
    clearTimeout(this.toastTimer)
    this.toastTarget.textContent = message
    this.toastTarget.hidden = false
    this.toastTimer = setTimeout(() => { this.toastTarget.hidden = true }, 6500)
  }
}

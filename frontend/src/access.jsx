import React, { useEffect, useState } from "react";
import { request } from "./api";
import { roles, statuses } from "./labels";
import { ActionButton, ErrorNotice, Heading, Modal, Status } from "./ui";

const membershipRoles = { operator: "Оператор", warehouse_manager: "Управляющий складом" };
function Pager({ page, pages, onChange }) {
  return <div className="pagination"><button className="secondary" disabled={page <= 1} onClick={() => onChange(page - 1)}>Назад</button><span>{page} / {Math.max(1, pages)}</span><button className="secondary" disabled={page >= pages} onClick={() => onChange(page + 1)}>Далее</button></div>;
}

function Memberships({ user, onClose, onChanged }) {
  const [items, setItems] = useState([]);
  const [warehouses, setWarehouses] = useState([]);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);
  const [ready, setReady] = useState(false);
  const [message, setMessage] = useState("");
  const load = async () => {
    const [assignments, available] = await Promise.all([request(`/admin/warehouse_memberships?user_id=${user.id}`), request("/admin/warehouses")]);
    setItems(assignments); setWarehouses(available); setReady(true);
  };
  useEffect(() => { load().catch(setError); }, [user.id]);
  async function save(event, item) {
    event.preventDefault(); setBusy(true); setError(null); setMessage("");
    const values = Object.fromEntries(new FormData(event.currentTarget));
    try {
      await request(item ? `/admin/warehouse_memberships/${item.id}` : "/admin/warehouse_memberships", {
        method: item ? "PATCH" : "POST", body: { membership: { ...values, user_id: user.id } }
      });
      await load(); onChanged(); setMessage("Назначение сохранено.");
    } catch (cause) { setError(cause); }
    finally { setBusy(false); }
  }
  const options = <><label>Роль<select name="role">{Object.entries(membershipRoles).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label><label>Состояние<select name="status">{Object.entries(statuses).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label></>;
  return <Modal title={`Доступ: ${user.name}`} onClose={onClose}>
    <p className="subtle">Каждое назначение действует только на своём складе. Блокировка учётной записи перекрывает все назначения.</p><ErrorNotice error={error}/>
    {message && <p role="status">{message}</p>}
    {!ready && <p role="status">Загрузка…</p>}
    {items.map(item => <form key={`${item.id}-${item.role}-${item.status}`} className="fields access-card" onSubmit={event => save(event, item)}>
      <strong>{item.warehouse_name}</strong>
      <label>Роль<select name="role" defaultValue={item.role}>{Object.entries(membershipRoles).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
      <label>Состояние<select name="status" defaultValue={item.status}>{Object.entries(statuses).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
      <ActionButton disabled={busy}>Сохранить назначение</ActionButton>
    </form>)}
    {ready && warehouses.some(warehouse => !items.some(item => item.warehouse_id === warehouse.id)) && <form className="fields access-card" onSubmit={event => save(event, null)}>
      <h3>Добавить склад</h3><label>Склад<select name="warehouse_id" required>{warehouses.filter(warehouse => !items.some(item => item.warehouse_id === warehouse.id)).map(warehouse => <option key={warehouse.id} value={warehouse.id}>{warehouse.name}</option>)}</select></label>
      {options}<ActionButton disabled={busy}>Добавить назначение</ActionButton>
    </form>}
  </Modal>;
}

function Team() {
  const [status, setStatus] = useState("");
  const [query, setQuery] = useState("");
  const [page, setPage] = useState(1);
  const [result, setResult] = useState(null);
  const [revision, setRevision] = useState(0);
  const [selected, setSelected] = useState(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const refresh = () => setRevision(value => value + 1);
  useEffect(() => {
    const controller = new AbortController(); setError(null); setResult(null);
    request(`/admin/users?${new URLSearchParams({ status, q: query, page, per_page: 10 })}`, { signal: controller.signal })
      .then(data => { if (page > Math.max(1, data.pagination.total_pages)) setPage(Math.max(1, data.pagination.total_pages)); else setResult(data); })
      .catch(cause => { if (!controller.signal.aborted) setError(cause); });
    return () => controller.abort();
  }, [status, query, page, revision]);
  async function change(user) {
    if (!window.confirm(`${user.status === "blocked" ? "Разблокировать" : "Заблокировать"} учётную запись ${user.name}?`)) return;
    setBusy(true); setError(null);
    try { await request(`/admin/users/${user.id}/${user.status === "blocked" ? "unblock" : "block"}`, { method: "PATCH" }); refresh(); }
    catch (cause) { setError(cause); } finally { setBusy(false); }
  }
  return <>
    <form className="search-row" onSubmit={event => { event.preventDefault(); setQuery(new FormData(event.currentTarget).get("q").trim()); setPage(1); }}>
      <label>Поиск сотрудника<input name="q" placeholder="Точная почта, ID или начало имени" type="search"/></label><button className="secondary">Найти</button>
    </form>
    <div className="filters">{[["", "Все"], ...Object.entries(statuses)].map(([value, label]) => <button key={value} className="secondary" aria-pressed={status === value} onClick={() => { setStatus(value); setPage(1); }}>{label}</button>)}</div>
    <ErrorNotice error={error}/>
    {!result ? <button className="secondary" onClick={refresh}>{error ? "Повторить" : "Загрузка…"}</button> : <>
      {!result.users.length && <p>Сотрудники не найдены.</p>}
      <div className="team-list">{result.users.map(user => <article className="team-row" key={user.id}>
        <div><strong>{user.name}</strong><small>#{user.id} · {user.email_address}</small></div><span>{roles[user.role]}</span><Status value={user.status}>{statuses[user.status]}</Status>
        {user.role !== "admin" && <div className="button-row"><button className="secondary" onClick={() => setSelected(user)}>Склады и роли</button>{user.status !== "pending" && <button disabled={busy} className="secondary" onClick={() => change(user)}>{user.status === "blocked" ? "Разблокировать" : "Заблокировать"}</button>}</div>}
      </article>)}</div><Pager page={page} pages={result.pagination.total_pages} onChange={setPage}/>
    </>}
    {selected && <Memberships user={selected} onClose={() => setSelected(null)} onChanged={refresh}/>}
  </>;
}

function Recoveries() {
  const [page, setPage] = useState(1);
  const [data, setData] = useState(null);
  const [selected, setSelected] = useState(null);
  const [error, setError] = useState(null);
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  const [revision, setRevision] = useState(0);
  useEffect(() => {
    const controller = new AbortController(); setError(null);
    request(`/admin/password_recovery_requests?page=${page}`, { signal: controller.signal }).then(result => {
      if (page > Math.max(1, result.pagination.total_pages)) setPage(Math.max(1, result.pagination.total_pages)); else setData(result);
    }).catch(cause => { if (!controller.signal.aborted) setError(cause); });
    return () => controller.abort();
  }, [page, revision]);
  async function act(event, item, reject = false) {
    event?.preventDefault(); setBusy(true); setError(null); setMessage("");
    const values = event ? Object.fromEntries(new FormData(event.currentTarget)) : {};
    try {
      const result = await request(`/admin/password_recovery_requests/${item.id}`, { method: reject ? "DELETE" : "PATCH", body: reject ? undefined : { recovery: { ...values, identity_confirmed: values.identity_confirmed === "on" } } });
      setSelected(null); setMessage(result?.message || "Заявка отклонена."); setRevision(value => value + 1);
    } catch (cause) { setError(cause); }
    finally { setBusy(false); }
  }
  return <>
    <p className="subtle">Заявка не подтверждает личность. Свяжитесь с сотрудником по известному рабочему контакту до смены пароля. Заявки действуют сутки.</p>
    <button className="secondary" onClick={() => setRevision(value => value + 1)}>Обновить заявки</button><ErrorNotice error={error}/>{message && <p role="status">{message}</p>}
    {data?.requests.length === 0 && <p>Ожидающих заявок нет.</p>}
    {data?.requests.map(item => <article className="access-card" key={item.id}><strong>{item.user.name}</strong><p>{item.user.email_address}</p><small>До {new Date(item.expires_at).toLocaleString("ru-RU")}</small>
      <div className="button-row"><button className="primary" disabled={busy} onClick={() => { setError(null); setSelected(item); }}>Восстановить доступ</button><button className="secondary" disabled={busy} onClick={() => { if (window.confirm("Отклонить заявку?")) act(null, item, true); }}>Отклонить</button></div>
    </article>)}
    {data && <Pager page={page} pages={data.pagination.total_pages} onChange={setPage}/>}
    {selected && <Modal title={`Временный пароль: ${selected.user.name}`} onClose={() => { if (!busy) setSelected(null); }}>
      <form className="fields" onSubmit={event => act(event, selected)}>
        <p>Передайте пароль лично или по проверенному каналу. При входе сотрудник обязан его заменить.</p>
        <label>Временный пароль<input name="password" type="password" autoComplete="new-password" minLength={8} required/></label>
        <label>Повторите пароль<input name="password_confirmation" type="password" autoComplete="new-password" minLength={8} required/></label>
        <label className="checkbox-label"><input name="identity_confirmed" type="checkbox" required/><span>Личность сотрудника проверена</span></label>
        <ErrorNotice error={error}/><ActionButton disabled={busy}>{busy ? "Сохраняем…" : "Установить временный пароль"}</ActionButton>
      </form>
    </Modal>}
  </>;
}

function Warehouses() {
  const [items, setItems] = useState([]);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);
  const load = () => request("/admin/warehouses").then(setItems);
  useEffect(() => { load().catch(setError); }, []);
  async function save(event, id) {
    event.preventDefault(); setBusy(true); setError(null);
    const form = event.currentTarget;
    try {
      await request(id ? `/admin/warehouses/${id}` : "/admin/warehouses", { method: id ? "PATCH" : "POST", body: { warehouse: Object.fromEntries(new FormData(form)) } });
      if (!id) form.reset(); await load();
    } catch (cause) { setError(cause); } finally { setBusy(false); }
  }
  return <><ErrorNotice error={error}/><p className="subtle">Новый склад создаётся без сотрудников, с нулевыми остатками каталога. Назначения выдаются отдельно.</p>
    {items.map(item => <form className="search-row" key={`${item.id}-${item.name}`} onSubmit={event => save(event, item.id)}><label>Склад #{item.id}<input name="name" defaultValue={item.name} required/></label><button className="secondary" disabled={busy}>Переименовать</button></form>)}
    <form className="fields access-card" onSubmit={event => save(event, null)}><h3>Новый склад</h3><label>Название<input name="name" required/></label><ActionButton disabled={busy}>Создать склад</ActionButton></form>
  </>;
}

const eventNames = { password_changed: "Пароль изменён", password_reset_by_admin: "Выдан временный пароль", recovery_rejected: "Заявка отклонена", warehouse_membership_changed: "Изменено назначение", warehouse_created: "Создан склад", warehouse_renamed: "Переименован склад", organization_onboarded: "Подключена организация", user_blocked: "Пользователь заблокирован", user_unblocked: "Пользователь разблокирован" };
function Events() {
  const [rows, setRows] = useState([]);
  const [cursor, setCursor] = useState(null);
  const [userId, setUserId] = useState("");
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);
  async function load(id = userId, before = null) {
    setBusy(true); setError(null);
    try {
      const query = new URLSearchParams(); if (id) query.set("user_id", id); if (before) query.set("before_id", before);
      const data = await request(`/admin/access_events?${query}`);
      setRows(previous => before ? [...previous, ...data.events] : data.events); setCursor(data.next_cursor);
    } catch (cause) { setError(cause); } finally { setBusy(false); }
  }
  useEffect(() => { load(); }, []);
  return <><form className="search-row" onSubmit={event => { event.preventDefault(); const id = new FormData(event.currentTarget).get("user_id"); setUserId(id); load(id); }}><label>ID сотрудника (пусто — все)<input name="user_id" type="number" min="1"/></label><button className="secondary" disabled={busy}>Показать</button></form><ErrorNotice error={error}/>
    {!rows.length && !busy && <p>Событий пока нет.</p>}{rows.map(item => <article className="access-card" key={item.id}><strong>{eventNames[item.action] || item.action}</strong><p>{item.user_name} · выполнил {item.actor_name}</p><small>{new Date(item.created_at).toLocaleString("ru-RU")}</small>{item.details.warehouse_id && <p>Склад #{item.details.warehouse_id}{item.details.role && ` · ${membershipRoles[item.details.role]} · ${statuses[item.details.status]}`}</p>}</article>)}
    {cursor && <button className="secondary" disabled={busy} onClick={() => load(userId, cursor)}>Следующие события</button>}
  </>;
}

export function CompanyAccess() {
  const [tab, setTab] = useState("team");
  const tabs = [["team", "Сотрудники"], ["recovery", "Восстановление"], ["warehouses", "Склады"], ["events", "Журнал доступа"]];
  return <><Heading index="02 / УПРАВЛЕНИЕ ДОСТУПОМ" title="Команда" description="Сотрудники, склады и доступы вашей организации."/>
    <div className="filters">{tabs.map(([key, label]) => <button className="secondary" key={key} aria-pressed={tab === key} onClick={() => setTab(key)}>{label}</button>)}</div>
    {tab === "team" && <Team/>}{tab === "recovery" && <Recoveries/>}{tab === "warehouses" && <Warehouses/>}{tab === "events" && <Events/>}
  </>;
}

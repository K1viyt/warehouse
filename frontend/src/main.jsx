import React, { useCallback, useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import { Boxes, ChevronLeft, ChevronRight, CircleUserRound, LogOut, UsersRound } from "lucide-react";
import { request } from "./api";
import { roles, statuses } from "./labels";
import { Brand, Gate, Pending, Verification } from "./auth";
import { Catalog } from "./catalog";
import { Empty, ErrorNotice, Heading, Status } from "./ui";
import "./workspace.css";

function Team() {
  const [status, setStatus] = useState("");
  const [page, setPage] = useState(1);
  const [result, setResult] = useState(null);
  const [retry, setRetry] = useState(0);
  const [busy, setBusy] = useState(null);
  const [error, setError] = useState(null);
  useEffect(() => {
    const controller = new AbortController();
    const query = new URLSearchParams({ status, page, per_page: 10 });
    setResult(null); setError(null);
    request(`/admin/users?${query}`, { signal: controller.signal }).then(data => {
      if (page > Math.max(1, data.pagination.total_pages)) setPage(Math.max(1, data.pagination.total_pages));
      else setResult(data);
    }).catch(cause => { if (!controller.signal.aborted) setError(cause); });
    return () => controller.abort();
  }, [status, page, retry]);
  async function update(id, action) {
    setBusy(id); setError(null);
    try {
      await request(`/admin/users/${id}/${action}`, { method: "PATCH" });
      setRetry(version => version + 1);
    } catch (cause) { setError(cause); }
    finally { setBusy(null); }
  }
  const actions = { pending: ["activate", "Одобрить"], blocked: ["unblock", "Разблокировать"], active: ["block", "Заблокировать"] };
  return <>
    <Heading index="02 / УПРАВЛЕНИЕ ДОСТУПОМ" title="Команда" description="Сотрудники и заявки вашей организации."/>
    <div className="filters">
      {[["", "Все"], ...Object.entries(statuses)].map(([value, label]) => <button key={value} className="secondary" aria-pressed={status === value} onClick={() => { setStatus(value); setPage(1); }}>{label}</button>)}
    </div>
    <ErrorNotice error={error}/>
    {!result ? error ? <button className="secondary" onClick={() => setRetry(retry + 1)}>Повторить</button> : <p role="status">Загружаем команду…</p> :
      !result.users.length ? <Empty title="Список пуст">В выбранной категории сотрудников пока нет.</Empty> : <>
        <div className="team-list">{result.users.map(user => <article className="team-row" key={user.id}>
          <div><strong>{user.name}</strong><small>{user.email_address}</small></div>
          <span>{roles[user.role]}</span><Status value={user.status}>{statuses[user.status]}</Status>
          {user.role !== "admin" && <button className="secondary" disabled={busy !== null} onClick={() => update(user.id, actions[user.status][0])}>{actions[user.status][1]}</button>}
        </article>)}</div>
        <div className="pagination">
          <button className="icon-button" aria-label="Предыдущая страница" disabled={page <= 1} onClick={() => setPage(page - 1)}><ChevronLeft/></button>
          <span className="kicker">{page} / {result.pagination.total_pages}</span>
          <button className="icon-button" aria-label="Следующая страница" disabled={page >= result.pagination.total_pages} onClick={() => setPage(page + 1)}><ChevronRight/></button>
        </div>
      </>}
  </>;
}

function Profile({ user, refresh }) {
  return <>
    <Heading index="03 / АККАУНТ" title="Профиль" description="Учётная запись и доступные склады."/>
    <section className="info-panel">
      <h2>{user.name}</h2><p>{user.email_address}</p>
      <Status value={user.status}>{statuses[user.status]}</Status>
      <dl className="facts"><div><dt>Организация</dt><dd>{user.organization.name}</dd></div><div><dt>Роль</dt><dd>{roles[user.role]}</dd></div></dl>
      <p className="kicker">ДОСТУПНЫЕ СКЛАДЫ</p>
      {user.warehouses.length ? <ul>{user.warehouses.map(warehouse => <li key={warehouse.id}>{warehouse.name}</li>)}</ul> : <p>Нет доступных складов.</p>}
      <Verification user={user}/>
      <button className="secondary" onClick={refresh}>Обновить профиль</button>
    </section>
  </>;
}

function App() {
  const [user, setUser] = useState(undefined);
  const [tab, setTab] = useState("catalog");
  const [error, setError] = useState(null);
  const refresh = useCallback(async () => {
    setError(null);
    try { setUser(await request("/me")); }
    catch (cause) {
      if (cause.status === 401 || cause.status === 403) setUser(null);
      else setError(cause);
    }
  }, []);
  useEffect(() => { refresh(); }, [refresh]);
  async function logout() {
    try {
      await request("/session", { method: "DELETE" });
      setUser(null); setTab("catalog"); setError(null);
    } catch (cause) { setError(cause); }
  }
  if (user === undefined) return <main className="interstitial"><Brand/><section className="info-panel">
    <ErrorNotice error={error}/>{error ? <button className="secondary" onClick={refresh}>Повторить</button> : <p role="status">Открываем рабочее пространство…</p>}
  </section></main>;
  if (!user) return <><Gate onLogin={refresh}/>{error && <div className="global-error"><ErrorNotice error={error}/></div>}</>;
  if (user.status === "pending") return <><Pending user={user} onRefresh={refresh} onLogout={logout}/>{error && <div className="global-error"><ErrorNotice error={error}/></div>}</>;
  const links = [["catalog", "Каталог", Boxes], ...(user.role === "admin" ? [["team", "Команда", UsersRound]] : []), ["profile", "Профиль", CircleUserRound]];
  const active = links.some(([key]) => key === tab) ? tab : "catalog";
  return <div className="workspace">
    <aside className="sidebar">
      <Brand/><p className="kicker sidebar-label">РАБОЧЕЕ ПРОСТРАНСТВО</p>
      <nav aria-label="Разделы">{links.map(([key, title, Icon]) => <button key={key} type="button" aria-current={active === key ? "page" : undefined} onClick={() => setTab(key)}><Icon size={20}/>{title}</button>)}</nav>
      <div className="sidebar-foot"><small>{user.name}</small><span>{roles[user.role]}</span><button type="button" onClick={logout}><LogOut size={18}/> Выйти</button></div>
    </aside>
    <main className="workspace-main">
      <div className="workspace-bar"><span className="kicker">СКЛАДСКОЙ КОНТУР</span><span className="organization"><i/>{user.organization.name}</span></div>
      <div className="workspace-body">
        <ErrorNotice error={error}/>
        {active === "catalog" && <Catalog user={user} onUnauthorized={refresh}/>}
        {active === "team" && <Team/>}
        {active === "profile" && <Profile user={user} refresh={refresh}/>}
      </div>
    </main>
  </div>;
}

createRoot(document.getElementById("workspace-root")).render(<App/>);

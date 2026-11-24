import React, { useCallback, useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import { Boxes, ChevronLeft, ChevronRight, CircleUserRound, LogOut, UsersRound } from "lucide-react";
import { request } from "./api";
import { roles, statuses } from "./labels";
import { Brand, Gate, Pending, Verification } from "./auth";
import { CompanyAccess } from "./access";
import { PasswordForm, ResetPage } from "./recovery";
import { Catalog } from "./catalog";
import { Empty, ErrorNotice, Heading, Status } from "./ui";
import "./workspace.css";

function Profile({ user, refresh }) {
  return <>
    <Heading index="03 / АККАУНТ" title="Профиль" description="Учётная запись и доступные склады."/>
    <section className="info-panel">
      <h2>{user.name}</h2><p>{user.email_address}</p>
      <Status value={user.status}>{statuses[user.status]}</Status>
      <dl className="facts"><div><dt>Организация</dt><dd>{user.organization.name}</dd></div><div><dt>Роль</dt><dd>{roles[user.role]}</dd></div></dl>
      <p className="kicker">ДОСТУПНЫЕ СКЛАДЫ</p>
      {user.warehouses.length ? <ul>{user.warehouses.map(warehouse => <li key={warehouse.id}>{warehouse.name}</li>)}</ul> : <p>Нет доступных складов.</p>}
      {user.role !== "admin" && user.memberships?.length > 0 && <div><p className="kicker">НАЗНАЧЕНИЯ</p>{user.memberships.map(item => <p key={item.id}>{item.warehouse_name} · {item.role === "warehouse_manager" ? "Управляющий" : "Оператор"} · {statuses[item.status]}</p>)}</div>}
      <Verification user={user}/>
      <PasswordForm onDone={refresh}/>
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
  if (window.location.pathname === "/password_reset") return <ResetPage/>;
  if (user === undefined) return <main className="interstitial"><Brand/><section className="info-panel">
    <ErrorNotice error={error}/>{error ? <button className="secondary" onClick={refresh}>Повторить</button> : <p role="status">Открываем рабочее пространство…</p>}
  </section></main>;
  if (!user) return <><Gate onLogin={refresh}/>{error && <div className="global-error"><ErrorNotice error={error}/></div>}</>;
  if (user.password_change_required) return <main className="interstitial"><Brand/><section className="info-panel"><PasswordForm forced onDone={refresh}/><button className="secondary" onClick={logout}>Выйти</button></section></main>;
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
        {active === "team" && <CompanyAccess/>}
        {active === "profile" && <Profile user={user} refresh={refresh}/>}
      </div>
    </main>
  </div>;
}

createRoot(document.getElementById("workspace-root")).render(<App/>);

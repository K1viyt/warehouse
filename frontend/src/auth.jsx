import React, { useEffect, useState } from "react";
import { Box, Eye, EyeOff, LogOut, RefreshCw } from "lucide-react";
import { request } from "./api";
import { RecoveryRequest, PasswordForm } from "./recovery";
import { assets } from "./labels";
import { ActionButton, ErrorNotice } from "./ui";

export function Brand() {
  return <span className="brand"><Box size={25} strokeWidth={2.5}/> СЕКЦИЯ<span>.</span></span>;
}

export function Gate({ onLogin }) {
  const [mode, setMode] = useState("login");
  const [options, setOptions] = useState([]);
  const [organization, setOrganization] = useState("");
  const [warehouse, setWarehouse] = useState("");
  const [optionsError, setOptionsError] = useState(null);
  const [retry, setRetry] = useState(0);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);
  const [visible, setVisible] = useState(false);
  const registration = mode === "registration";
  const warehouses = options.find(item => String(item.id) === organization)?.warehouses ?? [];

  useEffect(() => {
    if (!registration) return;
    const controller = new AbortController();
    setOptionsError(null);
    request("/registration_options", { signal: controller.signal }).then(items => {
      setOptions(items);
      const first = items.length === 1 ? items[0] : null;
      setOrganization(first ? String(first.id) : "");
      setWarehouse(first?.warehouses.length === 1 ? String(first.warehouses[0].id) : "");
    }).catch(cause => { if (!controller.signal.aborted) setOptionsError(cause); });
    return () => controller.abort();
  }, [registration, retry]);

  function selectOrganization(value) {
    setOrganization(value);
    const available = options.find(item => String(item.id) === value)?.warehouses ?? [];
    setWarehouse(available.length === 1 ? String(available[0].id) : "");
  }

  async function submit(event) {
    event.preventDefault();
    const fields = Object.fromEntries(new FormData(event.currentTarget));
    setError(null);
    setBusy(true);
    try {
      if (registration) {
        await request("/registrations", { method: "POST", body: { user: fields } });
        setMode("done");
      } else {
        await request("/session", { method: "POST", body: { login: fields } });
        await onLogin();
      }
    } catch (cause) { setError(cause); }
    finally { setBusy(false); }
  }

  return <main className="gate">
    <section className="gate-visual" style={{ backgroundImage: `linear-gradient(180deg, #14161388, transparent 30%, #141613e8), url("${assets.warehouse}")` }}>
      <Brand/>
      <div className="gate-caption"><span className="kicker">СКЛАДСКОЙ КОНТУР / 01</span><h2>У каждого товара<br/>своё место<span>.</span></h2><p>Каталог, склады и команда в одном рабочем пространстве.</p></div>
      <span className="gate-mark" aria-hidden="true">▰ ▰ ▰ ▰ ▰ ▰</span>
    </section>
    <section className="gate-main">
      <span className="kicker">СЕКЦИЯ / ДОСТУП</span>
      <div className="gate-form">
        {mode === "recovery" ? <RecoveryRequest onBack={() => setMode("login")}/> : mode === "done" ? <>
          <h1>Заявка принята<b>.</b></h1>
          <p className="subtle">Администратор организации проверит заявку на доступ. Подтвердить адрес можно по ссылке из письма.</p>
          <ActionButton onClick={() => setMode("login")}>Ко входу</ActionButton>
        </> : <>
          <div className="switch" aria-label="Режим входа">
            <button type="button" aria-pressed={!registration} disabled={busy} onClick={() => { setMode("login"); setError(null); setVisible(false); }}>Вход</button>
            <button type="button" aria-pressed={registration} disabled={busy} onClick={() => { setMode("registration"); setError(null); setVisible(false); }}>Регистрация</button>
          </div>
          <h1>{registration ? "Новая заявка" : "Вход в систему"}<b>.</b></h1>
          <p className="subtle">{registration ? "Укажите организацию и склад, на котором будете работать." : "Войдите, чтобы открыть рабочее пространство."}</p>
          <form key={mode} onSubmit={submit} className="fields">
            {registration && <label>Имя<input name="name" autoComplete="name" required/></label>}
            <label>Электронная почта<input name="email_address" type="email" autoComplete="username" placeholder="name@company.ru" required/></label>
            <label>Пароль<span className="password-field"><input name="password" type={visible ? "text" : "password"} autoComplete={registration ? "new-password" : "current-password"} required/>
              <button type="button" className="icon-button" aria-label={visible ? "Скрыть пароль" : "Показать пароль"} onClick={() => setVisible(!visible)}>{visible ? <EyeOff size={18}/> : <Eye size={18}/>}</button></span></label>
            {registration && <>
              <label>Повторите пароль<input name="password_confirmation" type={visible ? "text" : "password"} autoComplete="new-password" required/></label>
              <div className="field-row">
                <label>Организация<select name="organization_id" required value={organization} onChange={event => selectOrganization(event.target.value)}>
                  <option value="">Выберите</option>{options.map(item => <option key={item.id} value={item.id}>{item.name}</option>)}
                </select></label>
                <label>Склад<select name="warehouse_id" required value={warehouse} disabled={!warehouses.length} onChange={event => setWarehouse(event.target.value)}>
                  <option value="">Выберите</option>{warehouses.map(item => <option key={item.id} value={item.id}>{item.name}</option>)}
                </select></label>
              </div>
              {optionsError && <><ErrorNotice error={optionsError}/><button type="button" className="secondary" onClick={() => setRetry(retry + 1)}>Обновить список складов</button></>}
            </>}
            <ErrorNotice error={error}/>
            <ActionButton disabled={busy || (registration && !warehouse)}>{busy ? "Подождите…" : registration ? "Отправить заявку" : "Войти"}</ActionButton>
          </form>
          {!registration && <button type="button" className="secondary" onClick={() => { setMode("recovery"); setError(null); }}>Забыли пароль?</button>}
        </>}
      </div>
      <span className="kicker gate-footer">СЕКЦИЯ — СИСТЕМА СКЛАДСКОГО УЧЁТА</span>
    </section>
  </main>;
}

export function Verification({ user }) {
  const [message, setMessage] = useState("");
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);
  async function resend() {
    setBusy(true); setError(null); setMessage("");
    try {
      await request("/email_verification/resend", { method: "POST" });
      setMessage("Письмо поставлено в очередь на отправку.");
    } catch (cause) { setError(cause); }
    finally { setBusy(false); }
  }
  return <div className="verification">
    <p>{user.email_verified ? "Почта подтверждена" : "Почта ожидает подтверждения"}</p>
    {!user.email_verified && <button type="button" className="secondary" disabled={busy} onClick={resend}>Отправить письмо ещё раз</button>}
    {message && <p role="status">{message}</p>}<ErrorNotice error={error}/>
  </div>;
}

export function Pending({ user, onRefresh, onLogout }) {
  return <main className="interstitial"><Brand/><section className="info-panel">
    <span className="kicker">СЕКЦИЯ / ЗАЯВКА</span><h1>На рассмотрении<b>.</b></h1>
    <p>{user.name}, администратор организации «{user.organization.name}» должен одобрить доступ к складу.</p>
    <Verification user={user}/>
    <PasswordForm onDone={onRefresh}/>
    <div className="button-row"><button className="primary" onClick={onRefresh}><RefreshCw size={16}/> Проверить статус</button>
      <button className="secondary" onClick={onLogout}><LogOut size={16}/> Выйти</button></div>
  </section></main>;
}

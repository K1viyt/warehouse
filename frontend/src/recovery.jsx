import React, { useState } from "react";
import { request } from "./api";
import { ActionButton, ErrorNotice } from "./ui";

export function RecoveryRequest({ onBack }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [message, setMessage] = useState("");
  async function submit(event) {
    event.preventDefault(); setBusy(true); setError(null); setMessage("");
    const values = Object.fromEntries(new FormData(event.currentTarget));
    try {
      const result = await request("/password_recovery", { method: "POST", body: { recovery: values } });
      setMessage(result.message);
    } catch (cause) { setError(cause); }
    finally { setBusy(false); }
  }
  return <>
    <h1>Вернуть доступ<b>.</b></h1>
    <p className="subtle">На подтверждённую почту придёт ссылка. Если почта недоступна, обратитесь к администратору своей фирмы.</p>
    <form className="fields" onSubmit={submit}>
      <label>Электронная почта<input name="email_address" type="email" autoComplete="username" required/></label>
      <label>Способ восстановления<select name="channel"><option value="email">Ссылка на подтверждённую почту</option><option value="admin">Заявка администратору</option></select></label>
      <ErrorNotice error={error}/>{message && <p role="status">{message}</p>}
      <ActionButton disabled={busy}>{busy ? "Отправляем…" : "Запросить восстановление"}</ActionButton>
      <button className="secondary" type="button" onClick={onBack}>Назад ко входу</button>
    </form>
  </>;
}

export function PasswordForm({ token, forced = false, onDone }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [done, setDone] = useState(false);
  async function submit(event) {
    event.preventDefault(); setBusy(true); setError(null);
    const values = Object.fromEntries(new FormData(event.currentTarget));
    if (values.password !== values.password_confirmation) {
      setError(new Error("Пароли не совпадают.")); setBusy(false); return;
    }
    try {
      await request(token ? "/password_reset" : "/password", {
        method: token ? "POST" : "PATCH",
        body: token ? { password_reset: { ...values, token } } : { password_change: values }
      });
      setDone(true);
      if (token) window.history.replaceState(null, "", "/password_reset");
    } catch (cause) { setError(cause); }
    finally { setBusy(false); }
  }
  if (done) return <div role="status"><p>Пароль изменён. Все предыдущие сессии завершены.</p><button className="primary" onClick={onDone}>Войти заново</button></div>;
  return <form className="fields password-change" onSubmit={submit}>
    <h2>{forced ? "Замените временный пароль" : "Новый пароль"}</h2>
    <p className="subtle">Минимум 8 символов. Новый пароль должен отличаться от текущего.</p>
    {!token && <label>{forced ? "Временный пароль от администратора" : "Текущий пароль"}<input name="current_password" type="password" autoComplete="current-password" required/></label>}
    <label>Новый пароль<input name="password" type="password" autoComplete="new-password" minLength={8} required/></label>
    <label>Повторите новый пароль<input name="password_confirmation" type="password" autoComplete="new-password" minLength={8} required/></label>
    <ErrorNotice error={error}/>
    <ActionButton disabled={busy}>{busy ? "Сохраняем…" : "Сменить пароль"}</ActionButton>
  </form>;
}

export function ResetPage() {
  const [token] = useState(() => new URLSearchParams(window.location.search).get("token"));
  return <main className="interstitial"><section className="info-panel"><span className="kicker">СЕКЦИЯ / ВОССТАНОВЛЕНИЕ</span>
    {token ? <PasswordForm token={token} onDone={() => window.location.assign("/")}/> : <><p>Откройте ссылку из письма или запросите новую.</p><a href="/">Ко входу</a></>}
  </section></main>;
}

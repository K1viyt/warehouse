import React, { useEffect, useState } from "react";
import { ArrowRight, PackagePlus, Truck } from "lucide-react";
import { request } from "./api";
import { ActionButton, Empty, ErrorNotice, Heading, Modal } from "./ui";

const kinds = { receipt: "Приход", issue: "Списание", transfer: "Перемещение", purchase: "Закупка" };
const states = { pending: "На согласовании", posted: "Проведён", approved: "Одобрен", shipped: "В пути", received: "Принят", rejected: "Отклонён", cancelled: "Отменён" };
const verbs = { approve: "Одобрить", reject: "Отклонить", ship: "Отправить", receive: "Принять", cancel: "Отменить" };
const format = value => Number(value).toLocaleString("ru-RU", { maximumFractionDigits: 3 });
const date = value => new Date(value).toLocaleString("ru-RU", { dateStyle: "short", timeStyle: "short" });

function requestKey() {
  if (crypto.randomUUID) return crypto.randomUUID();
  // Local HTTP on a warehouse LAN can use getRandomValues without a secure context.
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, value => value.toString(16).padStart(2, "0")).join("");
  return [hex.slice(0,8), hex.slice(8,12), hex.slice(12,16), hex.slice(16,20), hex.slice(20)].join("-");
}

function DocumentForm({ inventory, warehouse, onClose, onSaved }) {
  const [kind, setKind] = useState("receipt");
  const [lines, setLines] = useState([{ product_id: "", quantity: "" }]);
  const [reason, setReason] = useState("");
  const [source, setSource] = useState("");
  const [key] = useState(requestKey);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const sources = inventory.warehouses.filter(w => String(w.id) !== String(warehouse.id));
  function change(index, field, value) {
    setLines(lines.map((row, i) => i === index ? { ...row, [field]: value } : row));
  }
  async function save(event) {
    event.preventDefault();
    setBusy(true); setError(null);
    try {
      const doc = await request("/warehouse_documents", { method: "POST", body: { document: {
        kind, lines, reason, request_key: key, warehouse_id: warehouse.id, source_id: kind === "transfer" ? source : null
      } } });
      onSaved(doc);
    } catch (cause) { setError(cause); } finally { setBusy(false); }
  }
  return <Modal title="Новая операция" onClose={() => !busy && onClose()}>
    <p className="subtle">{warehouse.name}</p>
    <form className="fields" onSubmit={save}>
      <label>Вид операции<select value={kind} onChange={e => setKind(e.target.value)}>{Object.entries(kinds).map(([id, name]) => <option key={id} value={id} disabled={id === "transfer" && !sources.length}>{name}</option>)}</select></label>
      {kind === "transfer" && <label>Склад-источник<select required value={source} onChange={e => setSource(e.target.value)}><option value="">Выберите склад</option>{sources.map(w => <option key={w.id} value={w.id}>{w.name}</option>)}</select></label>}
      {lines.map((row, i) => {
        const product = inventory.products.find(p => String(p.id) === row.product_id);
        return <fieldset className="operation-line" key={i}><legend>Позиция {i + 1}</legend>
          <label>Товар<select required value={row.product_id} onChange={e => change(i,"product_id",e.target.value)}><option value="">Выберите товар</option>{inventory.products.map(p => <option key={p.id} value={p.id}>{p.name} · {p.sku}</option>)}</select></label>
          <label>Количество{product && " · " + product.unit}<input required type="number" min={product?.unit === "шт" ? 1 : 0.001} step={product?.unit === "шт" ? 1 : 0.001} value={row.quantity} onChange={e => change(i,"quantity",e.target.value)}/></label>
          {lines.length > 1 && <button type="button" className="secondary" onClick={() => setLines(lines.filter((_, n) => n !== i))}>Убрать позицию</button>}
        </fieldset>;
      })}
      <button className="secondary" type="button" disabled={lines.length >= 100} onClick={() => setLines([...lines, { product_id: "", quantity: "" }])}>Добавить позицию</button>
      <label>Основание<input required maxLength={500} value={reason} onChange={e => setReason(e.target.value)}/></label>
      <ErrorNotice error={error}/><ActionButton disabled={busy}>{kind === "receipt" || kind === "issue" ? "Провести" : "Оформить заявку"}</ActionButton>
    </form>
  </Modal>;
}

function Inventory({ data, warehouse }) {
  if (!data.products.length) return <Empty title="Каталог пуст">Добавьте товар в каталоге фирмы.</Empty>;
  return <div className="stock-list">{data.products.map(p => <article key={p.id} className="stock-item">
    <div><small className="kicker">{p.sku}</small><h3>{p.name}</h3></div>
    <dl>{[["Фактически", p.quantity],["В резерве", p.reserved],["Доступно", p.available[warehouse.id] || 0]].map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{format(value)} <small>{p.unit}</small></dd></div>)}</dl>
    {data.warehouses.length > 1 && <details><summary>Доступность на других складах фирмы</summary>{data.warehouses.filter(w => w.id !== warehouse.id).map(w => <p key={w.id}>{w.name} · {format(p.available[w.id] || 0)} {p.unit}</p>)}</details>}
  </article>)}</div>;
}

function DocumentCard({ doc, advance, busy }) {
  return <article className="doc-card">
    <header><small className="kicker">№ {doc.id} · {doc.author}</small><span className={"doc-state " + doc.state}>{states[doc.state]}</span></header>
    <h3>{kinds[doc.kind]}</h3><p>{doc.source && <>{doc.source} <ArrowRight size={14}/> </>}{doc.destination}</p><p>{doc.reason}</p>
    <ul>{doc.lines.map(l => <li key={l.sku}>{l.name} · {l.sku} — {format(l.quantity)} {l.unit}</li>)}</ul>
    <details><summary>История документа</summary>{doc.events.map((e,i) => <p key={i}>{date(e.at)} · {e.actor} · {states[e.state]}</p>)}</details>
    {doc.actions.length > 0 && <footer>{doc.actions.map(a => <button className="secondary" disabled={busy} key={a} onClick={() => advance(doc.id,a)}>{verbs[a]}</button>)}</footer>}
  </article>;
}

function Ledger({ warehouse, tab, inventory, refresh }) {
  const [filters, setFilters] = useState({});
  const [rows, setRows] = useState([]);
  const [next, setNext] = useState(null);
  const [before, setBefore] = useState("");
  const [revision, setRevision] = useState(0);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error,setError] = useState(null);
  const [reverse,setReverse] = useState(null);
  const journal = tab === "journal";
  useEffect(() => {
    const abort = new AbortController();
    setLoading(true); setError(null);
    const query = new URLSearchParams({...filters, before});
    request(`/warehouses/${warehouse.id}/${tab}?${query}`, {signal: abort.signal})
      .then(data => { setRows(old => before ? [...old,...data.rows] : data.rows); setNext(data.next_cursor); })
      .catch(e => { if (!abort.signal.aborted) setError(e); })
      .finally(() => { if (!abort.signal.aborted) setLoading(false); });
    return () => abort.abort();
  }, [tab, warehouse.id, filters, before, revision]);
  async function mutate(path, method, body) {
    setBusy(true); setError(null);
    try {
      await request(path,{method, body}); setReverse(null); setBefore(""); setRevision(v => v+1); refresh();
    } catch(e) { setError(e); } finally { setBusy(false); }
  }
  function filter(field, value) { setBefore(""); setFilters(old => ({...old,[field]:value})); }
  return <>
    {journal && <div className="ledger-filters fields"><label>Тип движения<select value={filters.movement_type || ""} onChange={e => filter("movement_type",e.target.value)}><option value="">Все движения</option><option value="receipt">Приход</option><option value="issue">Списание</option></select></label>
      <label>Товар<select value={filters.product_id || ""} onChange={e => filter("product_id",e.target.value)}><option value="">Все товары</option>{inventory.products.map(p => <option key={p.id} value={p.id}>{p.name} · {p.sku}</option>)}</select></label>
      <label>С даты<input type="date" onChange={e => filter("from",e.target.value)}/></label><label>По дату<input type="date" onChange={e => filter("to",e.target.value)}/></label>
      <label>ID сотрудника<input type="number" min="1" onChange={e => filter("user_id",e.target.value)}/></label></div>}
    {!reverse && <ErrorNotice error={error}/>}
    {rows.map(r => journal ? <article className="doc-card" key={r.id}><header><small className="kicker">№ {r.id} · {date(r.created_at)}</small><strong>{kinds[r.movement_type]} · {format(r.quantity)} {r.unit}</strong></header><h3>{r.product}</h3><p>{r.sku} · {r.operator} (№ {r.operator_id})</p><p>{r.reason}{r.reversal_of && " · Исправление № " + r.reversal_of}</p>
      {r.reversible && <button className="secondary" onClick={() => {setReverse(r); setError(null);}}>Исправить движение</button>}</article> :
      <DocumentCard key={r.id} doc={r} busy={busy} advance={(id,transition) => mutate("/warehouse_documents/"+id,"PATCH",{transition})}/>)}
    {loading && <p role="status">Загрузка…</p>}{!loading && !rows.length && !error && <Empty title="Записей пока нет">Здесь появятся операции выбранного склада.</Empty>}
    {next && <button className="secondary" disabled={loading} onClick={() => setBefore(next)}>Показать ещё</button>}
    {reverse && <Modal title={"Исправить движение № " + reverse.id} onClose={() => !busy && setReverse(null)}><p>Обратная запись на {format(reverse.quantity)} {reverse.unit} сохранит исходное движение в журнале.</p><form className="fields" onSubmit={e => { e.preventDefault(); mutate(`/warehouses/${warehouse.id}/journal/${reverse.id}/reverse`,"POST",{reason: new FormData(e.currentTarget).get("reason")}); }}><label>Основание исправления<input name="reason" required/></label><ErrorNotice error={error}/><ActionButton disabled={busy}>Провести исправление</ActionButton></form></Modal>}
  </>;
}

export function Operations({user}) {
  const [id,setId] = useState(user.warehouses[0]?.id);
  const warehouse = user.warehouses.find(w => w.id === id);
  const [data,setData] = useState(null);
  const [tab,setTab] = useState("inventory");
  const [form,setForm] = useState(false);
  const [revision,setRevision] = useState(0);
  const [ledgerVersion,setLedgerVersion] = useState(0);
  const [error,setError] = useState(null);
  const [message,setMessage] = useState("");
  useEffect(() => {
    if (!id) return;
    const abort = new AbortController();
    setError(null);
    request("/warehouses/"+id+"/inventory",{signal:abort.signal}).then(setData).catch(e => { if (!abort.signal.aborted) setError(e); });
    return () => abort.abort();
  }, [id,revision]);
  return <section className="operations"><Heading index={user.organization.name} title="Складской учёт" description={warehouse?.name}
    actions={<ActionButton disabled={!data?.products.length} onClick={() => setForm(true)}><PackagePlus size={18}/>Новая операция</ActionButton>}/>
    {!warehouse ? <Empty title="Нет доступных складов">Назначения складов выдаёт администратор вашей фирмы.</Empty> : <>
      <div className="stock-context"><Truck aria-hidden="true"/><label>Рабочий склад<select value={id} onChange={e => {setData(null);setMessage("");setId(Number(e.target.value));}}>{user.warehouses.map(w => <option key={w.id} value={w.id}>{w.name}</option>)}</select></label></div>
      <nav className="stock-tabs" aria-label="Учёт">{[["inventory","Остатки"],["documents","Документы"],["journal","Журнал"]].map(([t,name]) => <button key={t} aria-pressed={tab === t} onClick={() => {setTab(t); if (t === "inventory") setRevision(v => v+1);}}>{name}</button>)}</nav>
      {message && <p className="notice" role="status">{message}</p>}<ErrorNotice error={error}/>
      {data ? tab === "inventory" ? <Inventory data={data} warehouse={warehouse}/> : <Ledger key={id+"-"+tab+"-"+ledgerVersion} tab={tab} warehouse={warehouse} inventory={data} refresh={() => setRevision(v => v+1)}/> : !error && <p role="status">Загружаем остатки…</p>}
      {error && <button className="secondary" onClick={() => setRevision(v => v+1)}>Повторить</button>}
      {form && data && <DocumentForm inventory={data} warehouse={warehouse} onClose={() => setForm(false)} onSaved={doc => {setForm(false);setMessage(kinds[doc.kind]+" № "+doc.id+" · "+states[doc.state]);setRevision(v=>v+1);setLedgerVersion(v=>v+1);}}/>}
    </>}
  </section>;
}

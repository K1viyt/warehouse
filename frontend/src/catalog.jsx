import React, { useEffect, useState } from "react";
import { ArrowUpRight, Grid2X2, List, Plus, Search } from "lucide-react";
import { request } from "./api";
import { assets } from "./labels";
import { ActionButton, Empty, ErrorNotice, Heading, Modal, PhotoInput } from "./ui";

function illustration(name) {
  if (/дюбел/i.test(name)) return assets.dowel;
  if (/болт/i.test(name)) return assets.bolt;
  if (/шуруп|саморез/i.test(name)) return assets.screw;
  return assets.material;
}

function Picture({ product }) {
  return <img src={product.photo_url || illustration(product.name)} alt={product.photo_url ? product.name : ""} loading="lazy"/>;
}

function ProductForm({ warehouses, onSaved, onClose }) {
  const [file, setFile] = useState(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  async function submit(event) {
    event.preventDefault();
    const body = new FormData(event.currentTarget);
    body.delete("photo");
    if (file) body.set("product[photo]", file);
    setBusy(true); setError(null);
    try { onSaved(await request("/products", { method: "POST", body })); }
    catch (cause) { setError(cause); }
    finally { setBusy(false); }
  }
  return <Modal title="Новая карточка" onClose={onClose}>
    <form className="fields" onSubmit={submit}>
      <label>Наименование<input name="product[name]" placeholder="Например, Болт М8" required/></label>
      <div className="field-row">
        <label>Артикул<input name="product[sku]" placeholder="BOLT-M8" required/></label>
        <label>Единица измерения<select name="product[unit]" required><option value="шт">шт — штуки</option><option value="кг">кг — килограммы</option></select></label>
      </div>
      <label>Склад<select name="warehouse_id" required defaultValue={warehouses.length === 1 ? warehouses[0].id : ""}>
        <option value="" disabled>Выберите склад</option>{warehouses.map(item => <option key={item.id} value={item.id}>{item.name}</option>)}
      </select></label>
      <PhotoInput onChange={setFile}/>
      <ErrorNotice error={error}/>
      <ActionButton disabled={busy}>{busy ? "Сохраняем…" : "Создать карточку"}</ActionButton>
    </form>
  </Modal>;
}

function ProductDetail({ initial, onSaved, onClose }) {
  const [product, setProduct] = useState(initial);
  const [file, setFile] = useState(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [uploadVersion, setUploadVersion] = useState(0);
  const [message, setMessage] = useState("");
  async function upload(event) {
    event.preventDefault();
    const body = new FormData();
    body.set("photo", file);
    setBusy(true); setError(null); setMessage("");
    try {
      const updated = await request(`/products/${product.id}/photo`, { method: "PUT", body });
      setProduct(updated); onSaved(updated); setFile(null);
      setUploadVersion(version => version + 1);
      setMessage("Фотография сохранена.");
    } catch (cause) { setError(cause); }
    finally { setBusy(false); }
  }
  return <Modal title={product.name} onClose={onClose}>
    <div className="detail-image"><Picture product={product}/></div>
    <dl className="facts"><div><dt>Артикул</dt><dd>{product.sku}</dd></div><div><dt>Единица измерения</dt><dd>{product.unit}</dd></div></dl>
    <form className="fields" onSubmit={upload}>
      <PhotoInput key={uploadVersion} onChange={setFile} label={product.photo_url ? "Заменить фотографию" : "Добавить фотографию"}/>
      <ErrorNotice error={error}/>{message && <p className="subtle" role="status">{message}</p>}
      <ActionButton disabled={!file || busy}>{busy ? "Сохраняем…" : "Сохранить фотографию"}</ActionButton>
    </form>
  </Modal>;
}

export function Catalog({ user, onUnauthorized }) {
  const [products, setProducts] = useState(null);
  const [error, setError] = useState(null);
  const [query, setQuery] = useState("");
  const [view, setView] = useState("grid");
  const [panel, setPanel] = useState(null);
  const [retry, setRetry] = useState(0);
  const [message, setMessage] = useState("");
  useEffect(() => {
    const controller = new AbortController();
    setError(null);
    request("/products", { signal: controller.signal }).then(setProducts).catch(cause => {
      if (controller.signal.aborted) return;
      if (cause.status === 401 || cause.status === 403) onUnauthorized();
      else setError(cause);
    });
    return () => controller.abort();
  }, [retry, onUnauthorized]);
  const term = query.trim().toLocaleLowerCase("ru");
  const visible = (products ?? []).filter(product => [product.name, product.sku].some(value => value.toLocaleLowerCase("ru").includes(term)));
  function saved(product) {
    setProducts(current => current.some(item => item.id === product.id) ? current.map(item => item.id === product.id ? product : item) : [...current, product]);
  }
  return <>
    <Heading index="01 / НОМЕНКЛАТУРА" title="Каталог" description="Товары вашей организации и их карточки."
      actions={<ActionButton disabled={!products || !user.warehouses.length} onClick={() => { setMessage(""); setPanel("new"); }}><Plus size={18}/> Новый товар</ActionButton>}/>
    {!user.warehouses.length && <p className="notice">Для создания товара нужен доступ хотя бы к одному складу.</p>}
    <div className="catalog-tools">
      <label className="search"><Search size={19}/><input type="search" aria-label="Поиск по каталогу" placeholder="Найти по названию или артикулу" value={query} onChange={event => setQuery(event.target.value)}/></label>
      <span className="kicker result-count">{products ? `${visible.length} / ${products.length} ПОЗИЦИЙ` : "ЗАГРУЗКА"}</span>
      <div className="switch">
        <button type="button" aria-label="Карточки" aria-pressed={view === "grid"} onClick={() => setView("grid")}><Grid2X2 size={17}/></button>
        <button type="button" aria-label="Список" aria-pressed={view === "list"} onClick={() => setView("list")}><List size={19}/></button>
      </div>
    </div>
    {message && <p className="notice" role="status">{message}</p>}
    {error ? <><ErrorNotice error={error}/><button className="secondary" onClick={() => setRetry(retry + 1)}>Повторить</button></>
      : !products ? <p className="subtle" role="status">Загружаем каталог…</p>
      : !visible.length ? <Empty title={term ? "Товары не найдены" : "Каталог пока пуст"}>{term ? "Измените запрос и попробуйте ещё раз." : "Создайте первую карточку товара."}</Empty>
      : <div className={view === "grid" ? "product-grid" : "product-list"}>
        {visible.map((product, index) => <button type="button" className="product-card" key={product.id} onClick={() => setPanel(product)}>
          <div className="product-image"><Picture product={product}/><span className="image-index">{String(index + 1).padStart(2, "0")}</span></div>
          <div className="product-meta"><span className="kicker">{product.sku}</span><strong>{product.name}</strong><span className="unit">{product.unit}</span><ArrowUpRight className="product-arrow" size={20}/></div>
        </button>)}
      </div>}
    {panel === "new" ? <ProductForm warehouses={user.warehouses} onClose={() => setPanel(null)} onSaved={product => {
      saved(product); setQuery(""); setPanel(null); setMessage(`Карточка «${product.name}» создана.`);
    }}/> : panel && <ProductDetail initial={panel} onSaved={saved} onClose={() => setPanel(null)}/>}
  </>;
}

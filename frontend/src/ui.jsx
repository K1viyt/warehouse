import React, { useEffect, useRef, useState } from "react";
import { AlertCircle, ArrowUpRight, ImagePlus, X } from "lucide-react";

export function ErrorNotice({ error }) {
  if (!error) return null;
  return <p className="notice notice-error" role="alert"><AlertCircle size={17}/>{error.message || error}</p>;
}

export function Status({ value, children }) {
  return <span className={`badge badge-${value}`}><i/>{children}</span>;
}

export function Heading({ index, title, description, actions }) {
  return <header className="page-heading">
    <div><p className="kicker">{index}</p><h1>{title}<b>.</b></h1><p className="subtle">{description}</p></div>
    {actions}
  </header>;
}

export function Empty({ title, children }) {
  return <div className="empty"><span className="kicker">СЕКЦИЯ / ПУСТО</span><h2>{title}</h2><p className="subtle">{children}</p></div>;
}

export function Modal({ title, onClose, children }) {
  const ref = useRef(null);
  useEffect(() => {
    const dialog = ref.current;
    dialog.showModal();
    return () => dialog.close();
  }, []);
  return <dialog ref={ref} className="panel-dialog" aria-labelledby="panel-title" onCancel={onClose}
    onClick={event => { if (event.target === ref.current) onClose(); }}>
    <section className="dialog-inner">
      <header><span className="kicker">КАТАЛОГ / КАРТОЧКА</span><button type="button" className="icon-button" aria-label="Закрыть" onClick={onClose}><X size={22}/></button></header>
      <h2 id="panel-title">{title}</h2>
      {children}
    </section>
  </dialog>;
}

export function PhotoInput({ onChange, label = "Добавить фотографию" }) {
  const [file, setFile] = useState(null);
  const [preview, setPreview] = useState("");
  useEffect(() => {
    if (!file) { setPreview(""); return; }
    const url = URL.createObjectURL(file);
    setPreview(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);
  return <label className="photo-picker">
    {preview ? <img src={preview} alt="Предпросмотр выбранной фотографии"/> : <ImagePlus size={25}/>}
    <span><strong>{file ? file.name : label}</strong><small>JPEG, PNG или WebP · до 5 МБ</small></span>
    <input type="file" name="photo" accept="image/jpeg,image/png,image/webp"
      onChange={event => { const next = event.target.files[0] ?? null; setFile(next); onChange(next); }}/>
  </label>;
}

export function ActionButton({ children, ...props }) {
  return <button className="primary" {...props}>{children}<ArrowUpRight size={17} aria-hidden="true"/></button>;
}

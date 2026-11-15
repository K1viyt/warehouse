import json, math, html, textwrap, shutil
from pathlib import Path
import xml.etree.ElementTree as E

HERE=Path(__file__).resolve().parent
DATA=json.loads((HERE/"requirements.json").read_text(encoding="utf-8"))
OUT=HERE/"technical-spec.drawio"
COL={"ready":("#D8DFCE","#768462","ЕСТЬ · проверено разработчиком · QA ожидает"),
"partial":("#E5D3B6","#AB7843","ЧАСТИЧНО · завершённого сценария нет"),
"plan":("#E2DDD3","#918B7D","ПЛАН · API и UI пока нет"),
"gap":("#EBD4C4","#AC6341","ОТКРЫТЫЙ ПРОБЕЛ · требует решения"),
"policy":("#E7E1D6","#A09A8D","КОНТЕКСТ / ПРАВИЛО · не результат QA")}
W=1600
base="whiteSpace=wrap;html=1;fontFamily=Arial;fontColor=#202320;"
doc=E.Element("mxfile",{"host":"app.diagrams.net","version":"32.4.1","agent":"Section requirements generator","pages":"18"})
models={}
def geom(cell,x,y,w,h):
    return E.SubElement(cell,"mxGeometry",{"x":str(x),"y":str(y),"width":str(w),"height":str(h),"as":"geometry"})
def box(root,id,label,x,y,w,h,style="",parent="1",link=None,meta=None):
    attrs={"id":id,"label":label}
    if link: attrs["link"]=link
    if meta: attrs.update(meta)
    ob=E.SubElement(root,"UserObject",attrs)
    cell=E.SubElement(ob,"mxCell",{"vertex":"1","parent":parent,"style":base+style})
    g=geom(cell,x,y,w,h)
    return cell,g
def text(root,id,label,x,y,w,h,size=16,color="#202320",parent="1",link=None,extra=""):
    return box(root,id,label,x,y,w,h,f"text;strokeColor=none;fillColor=none;align=left;verticalAlign=top;fontSize={size};fontColor={color};spacing=0;"+extra,parent,link)[0]
def edge(root,id,source,target,label="",style="",points=None):
    c=E.SubElement(root,"mxCell",{"id":id,"edge":"1","parent":"1","source":source,"target":target,"value":label,
    "style":base+"edgeStyle=orthogonalEdgeStyle;rounded=1;orthogonalLoop=1;jettySize=auto;strokeColor=#8C8B7C;strokeWidth=2;endArrow=block;endFill=1;fontSize=13;labelBackgroundColor=#F3EFE7;"+style})
    g=E.SubElement(c,"mxGeometry",{"relative":"1","as":"geometry"})
    if points:
        a=E.SubElement(g,"Array",{"as":"points"})
        for x,y in points:E.SubElement(a,"mxPoint",{"x":str(x),"y":str(y)})
def link(page):return "data:page/id,"+page
def newpage(id,name,title,subtitle,H=1400):
    d=E.SubElement(doc,"diagram",{"id":id,"name":name})
    m=E.SubElement(d,"mxGraphModel",{"dx":"1600","dy":str(H),"grid":"1","gridSize":"10","guides":"1","tooltips":"1","connect":"1","arrows":"1","fold":"1","page":"1","pageScale":"1","pageWidth":str(W),"pageHeight":str(H),"math":"0","shadow":"0","background":"#F3EFE7"})
    r=E.SubElement(m,"root");E.SubElement(r,"mxCell",{"id":"0"});E.SubElement(r,"mxCell",{"id":"1","parent":"0"})
    box(r,id+"-brand","СЕКЦИЯ / ТЕХНИЧЕСКОЕ ЗАДАНИЕ",60,30,1080,40,"rounded=0;strokeColor=none;fillColor=#202320;fontColor=#F3EFE7;fontSize=15;fontStyle=1;align=left;spacingLeft=18;")
    box(r,id+"-home","← К дереву",1280,30,260,40,"rounded=1;arcSize=10;fillColor=#A54628;strokeColor=none;fontColor=#FFFFFF;fontSize=15;fontStyle=1;",link=link("map"))
    text(r,id+"-title",html.escape(title),60,95,1480,55,32,extra="fontStyle=1;")
    text(r,id+"-sub",html.escape(subtitle),60,155,1480,50,15,"#625F57")
    models[id]=(d,m,r)
    return r
def footer(id,H,prev=None,nxt=None):
    d,m,r=models[id];m.set("pageHeight",str(math.ceil(H/10)*10));m.set("dy",str(H))
    text(r,id+"-source",f"Снимок {DATA['date']} · код {DATA['codeCommit']} · QA-приёмка не выполнена",60,H-65,1060,30,12,"#625F57")
    if prev:box(r,id+"-prev","← Предыдущая",1120,H-75,200,40,"rounded=1;arcSize=10;fillColor=#E7E1D6;strokeColor=#B8B1A5;fontSize=13;",link=link(prev))
    if nxt:box(r,id+"-next","Следующая →",1340,H-75,200,40,"rounded=1;arcSize=10;fillColor=#E7E1D6;strokeColor=#B8B1A5;fontSize=13;",link=link(nxt))
def card(root,page,c,x,y,w,h):
    fill,stroke,status=COL[c["status"]]
    cid=page+"-"+c["id"]
    cell,g=box(root,cid,html.escape(c["id"]+" · "+c["title"]),x,y,w,h,
      f"swimlane;startSize=60;horizontal=1;rounded=1;arcSize=8;collapsible=0;fillColor={fill};swimlaneFillColor=#FAF7F1;strokeColor={stroke};fontSize=18;fontStyle=1;align=left;spacingLeft=18;spacingRight=18;",
      meta={"requirement-id":c["id"],"status":c["status"],"qa":"not-run","baseline":DATA["codeCommit"]})
    text(root,cid+"-status",html.escape(status),20,75,w-40,30,12,stroke,parent=cid,extra="fontStyle=1;")
    lines="<div style='font-size:15px;line-height:1.4'>"+"".join("<p style='margin:0 0 9px 0'>"+html.escape(s)+"</p>" for s in c["lines"])+"</div>"
    text(root,cid+"-body",lines,20,115,w-40,h-130,15,parent=cid)
def cardheight(c,w):
    chars=max(50,int((w-40)/8.2))
    lines=sum(max(1,len(textwrap.wrap(s,width=chars))) for s in c["lines"])
    return math.ceil(max(290,135+lines*22+len(c["lines"])*10)/10)*10
def cards_page(p):
    r=newpage(p["id"],p["name"],p["title"],p["subtitle"])
    y=230
    for k in range(0,len(p["cards"]),2):
        row=p["cards"][k:k+2];he=max(cardheight(c,720) for c in row)
        for i,c in enumerate(row):card(r,p["id"],c,60+i*760,y,720,he)
        y+=he+35
    return y+110
def table(root,id,headers,rows,widths,x=60,y=230,rowh=90):
    total=sum(widths)
    head=40
    box(root,id+"-table","",x,y,total,head+len(rows)*rowh,"rounded=0;fillColor=#FAF7F1;strokeColor=#B8B1A5;container=1;collapsible=0;")
    off=0
    for j,h in enumerate(headers):
        box(root,id+"-h"+str(j),html.escape(h),off,0,widths[j],head,"rounded=0;fillColor=#202320;strokeColor=#FAF7F1;fontColor=#F3EFE7;fontSize=13;fontStyle=1;align=left;spacing=12;",parent=id+"-table");off+=widths[j]
    for i,row in enumerate(rows):
        off=0
        for j,val in enumerate(row):
            fill="#FAF7F1" if i%2==0 else "#EDE7DC"
            textlabel="<div style='font-size:13px;line-height:1.35'>"+html.escape(val).replace("\n","<br>")+"</div>"
            box(root,id+"-r"+str(i)+"c"+str(j),textlabel,off,head+i*rowh,widths[j],rowh,
                f"rounded=0;fillColor={fill};strokeColor=#D0C9BB;fontSize=13;align=left;verticalAlign=middle;spacing=12;",parent=id+"-table");off+=widths[j]
    return y+head+len(rows)*rowh

# Overview: a six-branch tree. Grid positions are derived from branch order.
r=newpage("map","00 · Дерево ТЗ","Склад «СЕКЦИЯ»: дерево требований","«Открыть требования» — подробности раздела. −/+ сворачивает краткое описание.",1680)
rootcell,g=box(r,"map-project","СЕКЦИЯ<br><b>Один склад</b><br>Каталог → остатки → движения",60,690,320,170,"rounded=1;arcSize=10;fillColor=#202320;strokeColor=#202320;fontColor=#F3EFE7;fontSize=24;spacing=18;",link=link("passport"))
branches=[
("access","Доступ и роли","registration","ready","Регистрация · вход · ожидание активации · профиль<br>Бэк: есть | UI: есть | QA: ожидает"),
("catalog","Каталог товаров","catalog","ready","Список · карточка · создание · проверки артикула и единиц<br>Бэк: есть | UI: есть | QA: ожидает"),
("admin","Администрирование","administration","ready","Список · фильтры · страницы · активация · блокировка<br>Бэк: есть | UI: есть | QA: ожидает"),
("stock","Складские операции","balances","partial","Остатки: только модель/БД. Приход, списание, журнал: план<br>Транзакции, блокировка и идемпотентность ещё впереди"),
("contracts","Контракты и данные","api-access","policy","Текущие маршруты · DTO · коды ответов · схема данных<br>Будущие контракты не выдаются за действующие"),
("quality","Качество и приёмка","quality","policy","Интерфейс · безопасность · 32 QA-сценария · открытые решения<br>Разработчик проверил; независимая приёмка ожидает")]
for i,(key,title,target,status,desc) in enumerate(branches):
    y=230+i*190
    fill,stroke,lab=COL[status]
    cid="map-"+key
    cell,g=box(r,cid,f"{i+1:02d} / {title}  ↗",540,y,1000,150,f"swimlane;startSize=50;horizontal=1;rounded=1;arcSize=8;collapsible=1;fillColor={fill};swimlaneFillColor=#FAF7F1;strokeColor={stroke};fontSize=21;fontStyle=1;align=left;spacingLeft=20;")
    E.SubElement(g,"mxRectangle",{"x":"540","y":str(y),"width":"1000","height":"50","as":"alternateBounds"})
    text(r,cid+"-detail",f"<div style='line-height:1.5'>{desc}<br><b>Открыть требования →</b></div>",22,63,956,72,16,parent=cid,link=link(target))
    edge(r,"map-edge-"+key,"map-project",cid,style=f"exitX=1;exitY={(i+1)/7:.3f};entryX=0;entryY=0.5;",points=[(450,690+170*(i+1)/7),(450,y+75)])
text(r,"map-legend","<b>Легенда:</b> зелёный — есть; песочный — частично; серый — план; медный — открытый пробел.<br>Ни один блок пока не отмечен как принятый независимым тестером.",60,1450,1480,55,15)
box(r,"map-github","Открыть ветку GitHub ↗",60,1530,420,40,"rounded=1;fillColor=#E7E1D6;strokeColor=#B8B1A5;fontSize=15;",link="https://github.com/K1viyt/warehouse/tree/feature/frontend-warehouse-ui")
box(r,"map-figma","Открыть макеты Figma ↗",500,1530,420,40,"rounded=1;fillColor=#E7E1D6;strokeColor=#B8B1A5;fontSize=15;",link="https://www.figma.com/design/fRy4i8gmJo8H882xNO2Mld")
box(r,"map-guide","Как читать и обновлять ТЗ ↗",940,1530,600,40,"rounded=1;fillColor=#E7E1D6;strokeColor=#B8B1A5;fontSize=15;",link=link("acceptance"))
footer("map",1670,nxt="passport")

heights={}
for p in DATA["pages"]:heights[p["id"]]=cards_page(p)

# Account-state diagram: no login arrow is confused with an account-status change.
r=newpage("lifecycle","04 · Жизненный цикл","Статус аккаунта и административные переходы","Роль admin/operator не меняется при активации или блокировке.",1050)
for id,title,desc,x,fill in [
("pending","PENDING","Заявка создана<br>Вход и /me разрешены<br>Каталог запрещён",60,"#E5D3B6"),
("active","ACTIVE","Доступ к каталогу<br>Админ-действия только при role=admin",580,"#D8DFCE"),
("blocked","BLOCKED","Вход запрещён<br>Защищённый запрос сбрасывает старую сессию",1100,"#EBD4C4")]:
    box(r,"life-"+id,f"<b>{title}</b><br><br>{desc}",x,300,440,200,f"rounded=1;arcSize=10;fillColor={fill};strokeColor=#8C8B7C;fontSize=22;spacing=20;")
edge(r,"life-activate","life-pending","life-active","activate / 200","exitX=1;exitY=0.5;entryX=0;entryY=0.5;")
edge(r,"life-block","life-active","life-blocked","block / 200","exitX=1;exitY=0.5;entryX=0;entryY=0.5;")
edge(r,"life-unblock","life-blocked","life-active","unblock / 200","exitX=0.5;exitY=1;entryX=0.5;entryY=1;",[(1320,620),(800,620)])
text(r,"life-allowed","<b>Кто выполняет переходы</b><br>Только active admin через PATCH /admin/users/:id/...<br>Создание заявки начинает аккаунт с pending.<br>Вход/выход меняет сессию, а не status.",60,740,710,170,18)
text(r,"life-invalid","<b>Отказы</b><br>Неподходящий переход → 409; неизвестный id → 404.<br>Гость → 401; оператор/неактивный администратор → 403.<br>Активного администратора блокировать нельзя.",830,740,710,170,18)
heights["lifecycle"]=1050

# Exact current API contracts; future routes are intentionally not invented.
r=newpage("api-access","10 · API доступа","Текущий API: доступ и профиль","Все изменяющие запросы из браузера требуют CSRF; ошибки API не равны ошибкам HTML-формы.",1200)
rows=[
["GET /","—","200 · HTML-оболочка","Вход/регистрация/рабочая область; не замена JSON API."],
["GET /interface/csrf","—","200 · {csrf_token}","Токен текущей сессии; Cache-Control: no-store."],
["POST /registrations","user: name, email_address,\npassword, password_confirmation","201 · id, name, email_address,\nrole, status","422 · errors[]; concurrent RecordNotUnique пока не перехвачен."],
["POST /session","login: email_address, password","200 · id, name, role, status","401 · неверные данные; 403 · blocked. Pending разрешён."],
["GET /me","Сессионная cookie","200 · id, name, email_address,\nrole, status","401 · гость; 403 · blocked + reset_session."],
["DELETE /session","Сессионная cookie + CSRF","204 · пустое тело","Клиент не парсит JSON; последующий /me → 401."],
["GET /up","—","Проверка запуска Rails","Не доказывает полную работоспособность бизнес-сценариев."]
]
bottom=table(r,"api-auth",["Маршрут","Вход","Успех","Отказ / примечание"],rows,[300,380,360,440],rowh=115)
text(r,"api-auth-errors","<b>Формат:</b> валидации — {errors: [строки]}, прочие контролируемые отказы — {error: строка}.<br>UI переводит известные сообщения; сам не принимает решение о праве доступа.",60,bottom+30,1480,75,16)
heights["api-access"]=bottom+180
r=newpage("api-catalog","11 · API каталога и admin","Текущий API: каталог и пользователи","Только действующие маршруты; значения в примерах не являются персональными данными.",1600)
rows=[
["GET /products","active operator/admin","200 · массив товаров","401 · гость; 403 · pending/blocked."],
["GET /products/:id","active operator/admin","200 · один товар","404 обрабатывает Rails; единый DTO ошибки не закреплён."],
["POST /products","product: sku, name, unit;\nactive operator/admin","201 · созданный товар","422 · errors[]; 409 · RecordNotUnique SKU."],
["GET /admin/users","active admin; page, per_page,\nнеобязательный status","200 · {users, pagination}","users: id,name,email_address,role,status,created_at."],
["GET /admin/users/pending","active admin","200 · массив pending","Сортировка created_at; тот же белый список полей."],
["PATCH /admin/users/:id/activate","active admin; pending","200 · пользователь active","409 · active/blocked; 404 · id отсутствует."],
["PATCH /admin/users/:id/block","active admin; active operator","200 · пользователь blocked","409 · pending/blocked/admin; 404 · id отсутствует."],
["PATCH /admin/users/:id/unblock","active admin; blocked","200 · пользователь active","409 · pending/active; 404 · id отсутствует."],
]
bottom=table(r,"api-catalog-table",["Маршрут","Условие / вход","Успех","Отказ / уточнение"],rows,[400,350,330,400],rowh=115)
text(r,"api-pagination","<b>pagination:</b> page, per_page, total, total_pages. Total считается до offset/limit.<br><b>Защищённые admin-маршруты:</b> сначала проверка active, затем admin. API остатков/движений/редактирования товаров пока нет.",60,bottom+30,1480,85,16)
heights["api-catalog"]=bottom+195

r=newpage("data","12 · Модель данных","Данные: что существует и что только предлагается","Сплошная граница — текущая схема; пунктир — будущая концепция, а не готовый DDL.",1400)
entities=[
("users","USERS · сейчас",["PK id","name · NOT NULL","email_address · NOT NULL, UNIQUE","password_digest · NOT NULL","role: operator/admin · default operator","status: pending/active/blocked · default pending","created_at, updated_at"],60,250,440,330,False),
("products","PRODUCTS · сейчас",["PK id","sku · UNIQUE; обязательность в модели","name · обязательность в модели","unit · шт/кг проверяет модель","archived_at · API архивирования нет","created_at, updated_at","name/sku/unit в БД пока допускают NULL"],580,250,440,330,False),
("stock_balances","STOCK_BALANCES · сейчас",["PK id","FK product_id → products.id","product_id · NOT NULL, UNIQUE","quantity · decimal(12,3), default 0","quantity · NOT NULL, CHECK >= 0","created_at, updated_at","Один Product → 0…1 StockBalance сейчас"],1100,250,440,330,False),
("movements","MOVEMENTS · предложение",["PK id · проектируется","product_id → Product","operator_id → User","signed delta · kind","reason / destination · created_at","Идемпотентный идентификатор операции","Неизменяемые подтверждённые записи"],580,810,440,330,True),
("counterparties","COUNTERPARTIES · опционально",["Только после подтверждения области","Поставщик / получатель","Состав полей ещё не утверждён","Связь движения может быть необязательной","До этого источник/назначение можно","фиксировать согласованным текстом"],1100,810,440,330,True)]
for eid,title,ls,x,y,w,h,planned in entities:
    box(r,"data-"+eid,"<b>"+title+"</b><br><br>"+"<br>".join(html.escape(s) for s in ls),x,y,w,h,
        "rounded=1;arcSize=8;fillColor="+("#E2DDD3" if planned else "#FAF7F1")+";strokeColor=#8C8B7C;fontSize=16;align=left;verticalAlign=top;spacing=20;"+("dashed=1;" if planned else ""))
edge(r,"data-balance-fk","data-stock_balances","data-products",style="exitX=0;exitY=0.5;entryX=1;entryY=0.5;")
edge(r,"data-future-product","data-movements","data-products","будущий FK","dashed=1;exitX=0.5;exitY=0;entryX=0.5;entryY=1;")
edge(r,"data-future-user","data-movements","data-users","будущий автор","dashed=1;exitX=0;exitY=0.5;entryX=0.5;entryY=1;",[(540,975),(540,680),(280,680)])
edge(r,"data-future-counterparty","data-movements","data-counterparties",style="dashed=1;exitX=1;exitY=0.5;entryX=0;entryY=0.5;")
text(r,"data-note","<b>Количество — не ключ связи.</b> SKU — бизнес-артикул, id — стабильный идентификатор.<br>Наличие таблицы StockBalance не означает готовый учёт: товар и остаток ещё не создаются атомарно, API движений отсутствует.",60,1220,1480,80,18)
heights["data"]=1420

qa_access=[
("QA-01","Регистрация корректных данных","Отправить новую почту и совпадающие пароли.","201; одна запись operator/pending; UI подтверждает заявку.","Разработчик: авто + браузер"),
("QA-02","Занятая почта / другой регистр","Повторить email существующего аккаунта в верхнем регистре.","422; понятное сообщение; User.count не меняется.","Разработчик: авто"),
("QA-03","Пароли не совпадают","Заполнить разные password и confirmation.","Ошибка; поля сохранены; аккаунт не создан.","Разработчик: браузер"),
("QA-04","Подмена роли и статуса","В POST user передать role=admin, status=active.","Создан только operator/pending.","Разработчик: авто"),
("QA-05","Неверный пароль","Войти с известной почтой и неправильным паролем.","401; ошибка; каталога нет.","Разработчик: авто + браузер"),
("QA-06","Нормализация входа","Войти с верхним регистром и пробелами в email.","200; тот же пользователь; пароль не меняется.","Разработчик: авто + браузер"),
("QA-07","Аккаунт pending","Войти; открыть /me; обратиться к /products.","Вход и профиль разрешены; каталог 403; экран ожидания.","Разработчик: авто + браузер"),
("QA-08","Активация","Admin активирует pending, пользователь проверяет статус.","200; active; после проверки доступен каталог.","Разработчик: авто + браузер"),
("QA-09","Неподходящий переход","Повторить activate у active; activate у blocked.","409; состояние не изменено.","Разработчик: авто"),
("QA-10","Блокировка открытой сессии","Заблокировать вошедшего оператора; обновить каталог.","403; UI входа; /me затем 401.","Разработчик: авто + браузер"),
("QA-11","Разблокировка","Admin разблокирует blocked; пользователь входит.","200 и active; защищённый доступ восстановлен.","Разработчик: авто + браузер"),
("QA-12","Неизвестный пользователь","Admin PATCH activate/block/unblock несуществующего id.","404; управляемая ошибка; список не испорчен.","Разработчик: авто"),
("QA-13","Оператор в admin","Оператор открывает #users и прямой /admin/users.","Нет админ-экрана; серверный API 403.","Разработчик: авто + браузер"),
("QA-14","Страницы и фильтры","12+ заявок; pending, вторая страница, смена фильтра.","Нет дублей; верные total/page; новый фильтр с первой.","Разработчик: авто + браузер"),
("QA-15","Выход","Выйти и запросить /me; войти снова.","204 без JSON; /me 401; повторный вход работает.","Разработчик: авто + браузер"),
("QA-16","CSRF и смена сессии","Без токена; с токеном; вход после reset_session.","Без токена отказ; с актуальным токеном успех.","Разработчик: авто + браузер")]
qa_catalog=[
("QA-17","Создание и сохранность","Создать уникальный товар; обновить страницу; открыть id.","201; одна запись; товар остаётся после reload.","Разработчик: авто + браузер"),
("QA-18","Пустое название / SKU","Отдельный API-кейс на каждое поле; остальные валидны.","422; ошибка нужного поля; Product.count не меняется.","Модель проверена; изолировать API-кейсы"),
("QA-19","Недопустимая единица","POST с unit=г/т/pcs и корректными name/sku.","422; запись не создана; доступны только шт/кг.","Модель проверена; API проверить отдельно"),
("QA-20","Обычный дубль SKU","В форме создать товар с существующим SKU.","422; понятная ошибка; введённые поля сохранены.","Разработчик: авто + браузер"),
("QA-21","Гонка SKU","Два одновременных создания одного SKU.","Не больше одной записи; управляемый отказ 409/422.","Код/индекс есть; параллельная QA ожидает"),
("QA-22","Карточки и таблица","Переключить вид; открыть тот же товар в панели.","Одинаковые данные; корректные id и единица.","Реализация есть; независимая QA"),
("QA-23","HTML в пользовательском тексте","Создать название с HTML / onerror; открыть список/карточку.","Текст показан буквально, скрипт не выполняется.","Разработчик: браузер"),
("QA-24","Мобильный экран и клавиатура","390 px; меню, таблица, dialog; Tab и Escape.","Нет overflow страницы; понятный фокус, закрытие панели.","Ширина проверена; полный keyboard audit — QA"),
("QA-25","Сбой сети / не-JSON / двойной клик","Прервать запрос; вернуть неожиданный ответ; нажать дважды.","Нет ложного успеха; поля остаются; повтор доступен.","Обработка есть; отдельная QA-инъекция ожидает"),
("QA-26","Иллюстрации и демо-данные","Открыть три стандартных SKU и произвольный SKU.","Фото доступны; саморез прямой; у прочего общий фон.","Разработчик: браузер"),
("QA-27","Границы остатка","Модель/БД: negative, 0, повтор product_id, неверный FK.","Отрицательный/дубликат/неверный FK запрещены; 0 допустим.","Частично: модельные тесты; API нет"),
("QA-28","Атомарное создание остатка","Сымитировать сбой StockBalance после создания Product.","Обе записи откатываются; нет товара без остатка.","BLOCKED: ещё не реализовано"),
("QA-29","Приход и дробное количество","К 10 кг добавить 2,5 кг.","12,5 кг; одно положительное движение.","BLOCKED: ещё не реализовано"),
("QA-30","Недостаточный остаток","При 10 кг списать 12 кг.","Отказ с доступным количеством; БД не изменена.","BLOCKED: ещё не реализовано"),
("QA-31","Конкуренция и откат","При 10 кг параллельно списать 7+7; отдельно сбой журнала.","Одно списание; остаток 3; при сбое полный rollback.","BLOCKED: ещё не реализовано"),
("QA-32","Идемпотентность и коррекция","Повторить идентификатор операции; исправить ошибку.","Один эффект; отдельная корректировка; история сохранена.","BLOCKED: ещё не реализовано")]
for pid,name,title,rows in [("qa-access","14 · QA доступа","Матрица приёмки: доступ и пользователи",qa_access),("qa-stock","15 · QA каталога и склада","Матрица приёмки: каталог и будущий склад",qa_catalog)]:
    r=newpage(pid,name,title,"Каждая строка — отдельная проверка. QA-результат пока Not run; последняя колонка описывает только основание разработчика.",2200)
    bottom=table(r,pid+"-matrix",["ID / сценарий","Действия","Ожидаемый результат","Основание / готовность"],[[a+"\n"+b,c,d,e+"\nQA: NOT RUN"] for a,b,c,d,e in rows],[280,440,450,310],rowh=105)
    text(r,pid+"-qa-note","<b>Заполнение тестером:</b> для каждого ID сохранить Passed/Failed/Blocked, дату, SHA, окружение и ссылку на доказательство/дефект.<br>BLOCKED для плановых операций не является новым дефектом работающего интерфейса.",60,bottom+30,1480,80,16)
    heights[pid]=bottom+190

order=["map","passport","registration","sessions","lifecycle","administration","catalog","balances","operations","history","api-access","api-catalog","data","quality","qa-access","qa-stock","decisions","acceptance"]
# Reorder diagrams while preserving stable IDs; page navigation uses IDs, not titles.
existing=list(doc);doc[:]=[models[p][0] for p in order]
for i,pid in enumerate(order):
    if pid!="map":footer(pid,heights[pid],order[i-1] if i else None,order[i+1] if i+1<len(order) else None)
E.indent(doc,space="  ")
E.ElementTree(doc).write(OUT,encoding="utf-8",xml_declaration=True)
qa=HERE/"qa-inputs";qa.mkdir(exist_ok=True)
for i,pid in enumerate(order):
    root=E.Element("mxfile",{"host":"app.diagrams.net","version":"32.4.1"})
    root.append(E.fromstring(E.tostring(models[pid][0],encoding="unicode")))
    E.ElementTree(root).write(qa/f"{i:02d}-{pid}.drawio",encoding="utf-8",xml_declaration=True)
report={"pages":len(order),"requirements":sum(len(p["cards"]) for p in DATA["pages"]),"qa_cases":len(qa_access)+len(qa_catalog),"baseline":DATA["codeCommit"],"page_ids":order}
(HERE/"technical-report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
print(json.dumps(report,ensure_ascii=False))


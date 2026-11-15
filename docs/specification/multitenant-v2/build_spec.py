"""Customer requirements: shared source for editable Draw.io, linked PDF and offline HTML."""
from pathlib import Path
import html, json, math, zipfile
import xml.etree.ElementTree as ET
import fitz

OUT = Path(__file__).resolve().parent
DATE = '29.10.2026'
REV = '5fa8680'
PALETTE = {
 'green': ('#DCEFE3', '#247348', 'ГОТОВО'),
 'yellow': ('#FFF0C6', '#95670F', 'ЧАСТИЧНО'),
 'red': ('#F8DFDA', '#AE4037', 'НЕ РЕАЛИЗОВАНО'),
 'neutral': ('#E8E3D9', '#665D50', 'НА СОГЛАСОВАНИЕ'),
}
MODULES = [
('companies', 'Фирмы и изоляция данных', 'Одна система обслуживает несколько независимых организаций.', [
 ('Организация', 'red', 'Для каждой фирмы хранится отдельная запись: идентификатор, наименование и форма организации — например, ООО или ИП.'),
 ('Склады организации', 'red', 'У фирмы может быть несколько складов. Каждый склад принадлежит одной фирме. Данные разных фирм не смешиваются.'),
 ('Изоляция просмотра', 'red', 'Сотрудник не видит товары, склады, пользователей, заявки и документы другой фирмы, в том числе при подмене идентификатора в запросе.'),
 ('Изоляция изменений', 'red', 'Нельзя создать, изменить, подтвердить или удалить запись от имени другой фирмы. Проверка выполняется системой, а не только интерфейсом.'),
 ('Согласованность связей', 'red', 'Операции связывают только товары, склады и сотрудников своей фирмы. Передача материалов между фирмами не входит в текущее ТЗ.'),
 ('Первый администратор', 'red', 'Администратор создаётся при настройке сервера с привязкой к фирме. Обычная регистрация не позволяет назначить себе административную роль.'),
]),
('access', 'Регистрация и доступ', 'Учётная запись, вход и допуск сотрудника к работе.', [
 ('Регистрация и ожидание', 'yellow', 'Регистрация с именем, почтой и паролем и ожидание активации уже работают. Выбор или приглашение в конкретную фирму и склад ещё не реализованы.'),
 ('Вход и выход', 'green', 'Работает вход по почте и паролю и завершение сеанса. Неверные данные отклоняются. Пароль сохраняется в виде хеша.'),
 ('Нормализация и уникальность почты', 'green', 'Почта приводится к нижнему регистру, пробелы по краям удаляются. Повторный адрес не создаёт вторую учётную запись; уникальность закреплена в БД.'),
 ('Формат почты', 'yellow', 'Проверка есть в форме; серверная проверка формата и ограничение длины ещё нужны. Список допустимых доменов выносится на согласование.'),
 ('Личный профиль', 'yellow', 'Имя, почта, текущая роль и состояние учётной записи отображаются. Фирма, назначенные склады и роли на складах пока не отображаются.'),
 ('Блокировка', 'yellow', 'Блокировка пользователя действует и при открытом сеансе. Раздельное управление доступом к складам и областью фирмы ещё нужно добавить.'),
 ('Заявка в свою фирму', 'red', 'Администратор рассматривает заявки только своей фирмы. Пользователь не получает доступ к чужой фирме через регистрацию или изменение параметров запроса.'),
]),
('roles', 'Роли и ответственность', 'Три роли; полномочия ограничены фирмой и назначенным складом.', [
 ('Базовое разграничение ролей', 'yellow', 'Администратор и оператор уже различаются. Сейчас роль глобальная: привязка полномочий к фирме и складу ещё не реализована.'),
 ('Администратор фирмы', 'red', 'Управляет сотрудниками, заявками на доступ, ролями и складами своей фирмы. Видит её каталог и операции; не имеет доступа к другим фирмам.'),
 ('Ответственный за склад', 'red', 'Назначается на конкретный склад. Рассматривает заявки на выдачу с него, подтверждает отправку и приём. Назначение не даёт прав на остальные склады.'),
 ('Оператор склада', 'red', 'Работает в назначенном складе; видит каталог и доступные остатки складов своей фирмы. Создаёт заявки на перемещение и закупку, но не утверждает их самостоятельно.'),
 ('Назначение доступа', 'red', 'Назначение связывает сотрудника со складом, ролью и состоянием допуска. Возможность назначения на несколько складов требует согласования.'),
 ('Проверка полномочий', 'red', 'Каждое действие проверяется сервером по фирме, складу и роли. Скрытие кнопок служит удобству, но не заменяет запрет операции.'),
]),
('catalog', 'Каталог и карточки товаров', 'Общий справочник фирмы; количество хранится отдельно по складам.', [
 ('Каталог фирмы', 'yellow', 'Просмотр каталога работает. Требуется принадлежность товаров фирме: все её склады используют один справочник, другие фирмы имеют свои справочники.'),
 ('Создание и просмотр', 'green', 'Работают создание товара, подробная карточка, табличное представление и карточки. Этот статус относится к существующей версии без разделения по фирмам.'),
 ('Обязательные данные', 'yellow', 'Название и артикул обязательны; разрешены единицы «шт» и «кг». Формат и длины названия и артикула ещё нужно согласовать и закрепить.'),
 ('Уникальность артикула', 'yellow', 'Сейчас артикул уникален во всей системе. Нужно разрешить одинаковые артикулы у разных фирм и запретить повтор внутри одной фирмы.'),
 ('Разные товары', 'red', 'Одинаковое название не объединяет карточки. Разные внутренние артикулы учитываются раздельно; артикулы поставщиков как обозначения одного товара — отдельное расширение.'),
 ('Удаление ошибочной карточки', 'red', 'Предлагается удалять карточку только при нулевых остатках на всех складах и отсутствии движений и ссылок в документах. Права на удаление нужно согласовать.'),
 ('Архивирование', 'red', 'Для товара с историей предлагается архивирование с сохранением документов. При ненулевых остатках или незавершённых заявках архивирование отклоняется.'),
 ('Изображение товара', 'red', 'Предлагается загрузка одного изображения с ограничением размера и формата. Без изображения используется стандартная иллюстрация. Точные ограничения ещё не согласованы.'),
]),
('balances', 'Остатки и доступность', 'Один товар может отсутствовать на одном складе и быть на другом.', [
 ('Создание нулевого остатка', 'yellow', 'Товар и его нулевой остаток создаются вместе. Есть команда заполнения пропущенных остатков. Для нескольких складов требуется изменить эту схему.'),
 ('Остаток по складу и товару', 'red', 'Количество относится к конкретному складу и позиции общего каталога фирмы. Один склад не может иметь два остатка для одного товара.'),
 ('Правила количества', 'green', 'В текущем остатке разрешены ноль и положительное количество; отрицательное запрещено моделью и БД. Хранение — до трёх знаков после запятой.'),
 ('Просмотр своей фирмы', 'red', 'Пользователь видит количество в своём складе и доступность на остальных складах своей фирмы. Видимость не даёт права напрямую менять чужой остаток.'),
 ('Физический и доступный остаток', 'red', 'Предлагается различать физическое количество, резерв и доступное к выдаче. Момент резервирования и срок резерва вынесены на согласование.'),
 ('Актуальность количества', 'red', 'После проведённой операции интерфейс показывает сохранённый результат. Отсутствие остатка не трактуется как разрешение на выдачу; пользователь видит отсутствие материалов.'),
]),
('receipt', 'Приход материалов', 'Поступление увеличивает остаток и оставляет запись в истории.', [
 ('Сервис поступления', 'yellow', 'Реализовано увеличение остатка и создание движения «приход». Есть тесты успешного выполнения и отката. HTTP-маршрута и формы пока нет.'),
 ('Оформление прихода', 'red', 'В форме выбирают склад и товар своей фирмы, вводят положительное количество и обязательное основание. Полномочия на проведение уточняются на согласовании.'),
 ('Количество и основание движения', 'green', 'В модели и БД движения количество должно быть больше нуля, тип ограничен приходом или списанием. Основание обязательно. Это базовые правила данных.'),
 ('Совместное сохранение', 'yellow', 'В существующем сервисе остаток и движение сохраняются вместе; ошибка откатывает обе записи. Блокировка защищает остаток. Работа в области фирмы и склада ещё нужна.'),
 ('Кто и когда', 'yellow', 'Сервис сохраняет переданного сотрудника и время создания. При подключении HTTP сотрудник должен определяться по сеансу, а не произвольному полю формы.'),
 ('Повторная отправка', 'red', 'Повтор того же запроса не должен создавать второй приход. Блокировка остатка сама по себе не устраняет повторные операции.'),
]),
('issue', 'Выдача и списание', 'Материал расходуется только в пределах доступного количества.', [
 ('Запрос на выдачу', 'red', 'Выбирают склад, товар и положительное количество; указывают назначение или основание. Порядок согласования обычного списания ещё нужно определить.'),
 ('Достаточность остатка', 'red', 'Нельзя выдать больше доступного количества. При отказе пользователь видит доступный объём и может изменить заявку.'),
 ('Проведение операции', 'red', 'Уменьшение остатка и запись движения выполняются вместе с проверкой прав. При ошибке количество и история остаются прежними.'),
 ('Одновременная работа', 'red', 'Параллельные операции не могут израсходовать один остаток сверх доступного количества. Проверка выполняется по актуальным данным под блокировкой.'),
 ('Повтор и исправление', 'red', 'Повторная отправка не повторяет расход. Ошибочно проведённую операцию исправляют отдельным действием с основанием и сохранением исходной истории.'),
]),
('transfer', 'Перемещение между складами', 'Запрос, разрешение выдачи, отправка и подтверждение получения.', [
 ('Заявка склада-получателя', 'red', 'Оператор запрашивает материалы с другого склада своей фирмы. Указывает источник, получателя, товары, количества и основание. Чужой остаток сразу не меняется.'),
 ('Рассмотрение источником', 'red', 'Ответственный склада-источника одобряет или отклоняет заявку. Оператор склада-получателя не может самостоятельно разрешить выдачу с источника.'),
 ('Резерв после одобрения', 'red', 'Предлагается резервировать согласованное количество. Оно остаётся физически на источнике, но недоступно другим выдачам. Момент и срок резерва требуют согласования.'),
 ('Отправка', 'red', 'Ответственный источника подтверждает фактическую отправку. Остаток источника уменьшается вместе с записью отправки; перед действием проверяются количество и права.'),
 ('Материалы в пути', 'red', 'После отправки и до приёма материалы видны как находящиеся в пути. Они уже не на источнике и ещё не увеличивают остаток получателя.'),
 ('Подтверждение приёма', 'red', 'Ответственный склада-получателя подтверждает получение. Количество увеличивает его остаток, документ сохраняет связь с исходной отправкой.'),
 ('Отмена и расхождения', 'red', 'Предлагается отмена до отправки с освобождением резерва. Частичная отгрузка, недостача, возврат и отмена после отправки требуют отдельных согласованных правил.'),
 ('Защита документа', 'red', 'Допустимы только переходы из текущего состояния. Повтор отправки или приёма не дублирует количество. Оба склада и товары принадлежат одной фирме.'),
]),
('purchase', 'Потребность и закупка', 'Если материалов нет в фирме, оформляется потребность во внешней поставке.', [
 ('Определение потребности', 'red', 'Оператор проверяет доступность в своей фирме. При отсутствии или нехватке материалов создаёт заявку на закупку для своего склада.'),
 ('Состав заявки', 'red', 'В заявке фиксируются склад, товары, количества и основание. Разные артикулы идут отдельными строками. Одинаковый товар при одинаковых условиях предлагается объединять суммой количества.'),
 ('Решение по закупке', 'red', 'Кто согласует заявку, выбирает поставщика и оформляет заказ, нужно определить. Эти полномочия не назначаются автоматически ответственному за склад.'),
 ('Заказ не равен приходу', 'red', 'Создание или согласование заказа поставщику не меняет остаток. Материалы учитываются на складе только после фактического приёма.'),
 ('Приём поставки', 'red', 'Полученная поставка связывается с заявкой или заказом и проводится как приход. Частичные поставки, цены и документы поставщика требуют уточнения объёма.'),
 ('Смета перевозки', 'red', 'Расчёт стоимости перевозки — отдельная функция от заявки на перемещение. Нужность цен, тарифов и согласования сметы вынесена на обсуждение.'),
]),
('history', 'Журнал и прослеживаемость', 'Можно объяснить происхождение количества и действия сотрудников.', [
 ('Основа журнала', 'yellow', 'Есть таблица движений с товаром, сотрудником, количеством, типом, основанием и временем. Поле склада и привязка к документам ещё не реализованы.'),
 ('Просмотр истории', 'red', 'История доступна в пределах фирмы и разрешённых складов. Для каждой операции видны товар, склад, количество, сотрудник, время и основание.'),
 ('Отбор и страницы', 'red', 'Журнал фильтруется по складу, товару, периоду и типу операции. Длинный список разделяется на страницы без потери выбранных фильтров.'),
 ('Сохранность истории', 'red', 'Проведённые движения не удаляются при обычной работе. Архивирование карточек не уничтожает историю; исправления оставляют отдельный след.'),
 ('Связность перемещений', 'red', 'Из заявки можно проследить согласование, отправку и приём. Количество в пути и складские остатки позволяют объяснить местонахождение материалов.'),
 ('Аудит доступа', 'red', 'Сохраняется, кто согласовал заявку, назначил права или заблокировал доступ. Просмотр аудита ограничен полномочиями внутри фирмы.'),
]),
('interface', 'Интерфейс и проверка результата', 'Показываем пользователю только доступные ему действия и реальные результаты.', [
 ('Работающий интерфейс', 'green', 'Есть экраны регистрации, входа, ожидания, каталога и управления пользователями. Подключены существующие серверные действия односкладской версии.'),
 ('Пагинация пользователей', 'yellow', 'Страницы и фильтр состояния пользователей работают. Требуется ограничить выборку фирмой администратора, сохраняя корректный подсчёт страниц.'),
 ('Рабочий контекст', 'red', 'В интерфейсе видны фирма и текущий склад. Смена склада доступна только в пределах назначенных прав; формы не позволяют случайно оформить действие в чужом контексте.'),
 ('Формы складского учёта', 'red', 'Нужны формы прихода, списания, заявок на перемещение и закупку. Кнопки доступны по полномочиям, успех показывается только после подтверждения системой.'),
 ('Внешний вид и адаптация', 'green', 'Реализована индустриальная визуальная концепция, реалистичные изображения и адаптация экранов. Новые складские сценарии ещё предстоит оформить в этой системе.'),
 ('Приёмочные сценарии', 'red', 'Проверить две фирмы, минимум два склада фирмы, три роли, запреты подмены ID, параллельные операции, повторные запросы и полный путь перемещения.'),
]),
]

QUESTIONS = [
 ('Вступление в фирму', 'Приглашение сотрудника или выбор фирмы при регистрации? Кто создаёт организацию и назначает первого администратора?'),
 ('Назначения и блокировка', 'Допускаем ли несколько складов у одного сотрудника? Нужна блокировка отдельного назначения, всего аккаунта или оба варианта?'),
 ('Операционные права', 'Кто проводит обычный приход и списание? Кто согласует закупки? Может ли администратор фирмы выполнять действия ответственного склада?'),
 ('Резерв и расхождения', 'Резервировать при согласовании? Нужен ли срок резерва? Частичные отправки, приём, возврат и недостача входят в ближайший этап?'),
 ('Каталог и изображения', 'Кто редактирует, удаляет, архивирует товары и загружает изображения? Каковы допустимые длины, форматы артикула, размер и тип файла?'),
 ('Почта и границы закупки', 'Разрешаем любой корректный почтовый домен или согласованный список? Нужны ли подтверждение почты, цены, поставщики и смета перевозки в ближайшем этапе?'),
]

BG='#F4F0E8'; INK='#242820'; MUTED='#706B61'; W=1920
pages=[]
def add_page(pid,title,subtitle,height):
 p={'id':pid,'title':title,'subtitle':subtitle,'height':height,'nodes':[],'edges':[]};pages.append(p)
 return p
def node(p,nid,title,body,state,x,y,w,h,link=None):
 p['nodes'].append(dict(id=nid,title=title,body=body,state=state,x=x,y=y,w=w,h=h,link=link))
def branch(p,source,target,points,entry):p['edges'].append(dict(source=source,target=target,points=points,entry=entry))
def overall(items):
 s={i[1] for i in items};return next(iter(s)) if len(s)==1 else 'yellow'

sections=[(pid,title,desc,overall(items)) for pid,title,desc,items in MODULES]
sections += [('journey','Путь материалов','Как потребность превращается в перемещение или закупку.','red'),('questions','Решения для согласования','Открытые правила выделены отдельно от согласованных требований.','neutral')]
p=add_page('map','Мультитенантная складская система','Общий каталог фирмы · независимые остатки складов · согласованная передача материалов',1790)
node(p,'root','СЕКЦИЯ','Фирмы → склады → сотрудники → материалы','neutral',790,300,340,110)
for i,(pid,title,desc,state) in enumerate(sections):
 row=i//2; left=i%2==0;x=60 if left else 1010;y=470+row*170
 node(p,'map-'+pid,f'{i+1:02d} / '+title,desc,state,x,y,850,140,link=pid)
 branch(p,'root','map-'+pid,[(960,440),(960,y+70)],'right' if left else 'left')

for k,(pid,title,desc,items) in enumerate(MODULES):
 rows=math.ceil(len(items)/2);height=540+rows*215
 p=add_page(pid,f'{k+1:02d} / '+title,desc,height)
 node(p,pid+'-root',title,'Целевая функция и текущая готовность',overall(items),710,300,500,100)
 for i,(name,state,body) in enumerate(items):
  row=i//2;left=i%2==0;x=60 if left else 1010;y=450+row*215
  nid=pid+'-'+str(i+1);node(p,nid,name,body,state,x,y,850,185)
  branch(p,pid+'-root',nid,[(960,425),(960,y+92.5)],'right' if left else 'left')

p=add_page('journey','12 / Путь материалов','Целевой процесс. Складские заявки и их согласование пока не реализованы.',1420)
steps=[
 ('need','Потребность склада №2','Оператор выбирает товар из каталога своей фирмы.',760,300,400,130),
 ('available','Есть на складе №1','Создать заявку на перемещение внутри фирмы.',90,490,760,130),
 ('missing','В фирме недостаточно','Создать заявку на закупку недостающего количества.',1070,490,760,130),
 ('approve','Решение источника','Ответственный склада №1 одобряет или отклоняет заявку. Резерв — на согласование.',90,710,760,150),
 ('supplier','Согласование закупки','Уполномоченное лицо и объём работы с поставщиком — на согласование. Заказ не меняет остаток.',1070,710,760,150),
 ('send','Отправлено → в пути','Подтверждение отправки уменьшает остаток источника. Повтор не дублирует выдачу.',90,950,760,150),
 ('delivery','Поставка прибыла','Фактическое получение оформляется приходом с обязательным основанием.',1070,950,760,150),
 ('receive','Приём на складе №2','Подтверждение приёма увеличивает остаток получателя. Сохраняются сотрудник, время и связь с документом.',530,1200,860,140),
]
for nid,t,b,x,y,w,h in steps:node(p,nid,t,b,'red',x,y,w,h)
def flow(a,b,pts,entry='top'):p['edges'].append(dict(source=a,target=b,points=pts,entry=entry,flow=True))
flow('need','available',[(960,445),(470,445)]);flow('need','missing',[(960,445),(1450,445)])
flow('available','approve',[]);flow('missing','supplier',[]);flow('approve','send',[]);flow('supplier','delivery',[])
flow('send','receive',[(470,1150),(960,1150)]);flow('delivery','receive',[(1450,1150),(960,1150)])

p=add_page('questions','13 / Решения для согласования','Предложения не выдаются за утверждённые правила. Эти пункты не являются статусом готовности.',1140)
node(p,'questions-root','Обсуждение с командой','Согласовать до изменения структуры данных','neutral',710,300,500,100)
for i,(t,b) in enumerate(QUESTIONS):
 row=i//2;left=i%2==0;y=450+row*215;nid='q-'+str(i+1)
 node(p,nid,t,b,'neutral',60 if left else 1010,y,850,185)
 branch(p,'questions-root',nid,[(960,425),(960,y+92.5)],'right' if left else 'left')

def label(n):
 fill,stroke,status=PALETTE[n['state']]
 if n['h']<=130:
  return '<div style="text-align:left;line-height:1.2"><div style="font-size:23px"><b>'+html.escape(n['title'])+'</b></div><div style="font-size:17px;margin-top:7px">'+html.escape(n['body'])+'</div></div>'
 return '<div style="text-align:left;line-height:1.25"><div style="font-size:13px;color:'+stroke+'"><b>'+status+'</b></div><div style="font-size:23px;margin-top:7px"><b>'+html.escape(n['title'])+'</b></div><div style="font-size:19px;margin-top:8px">'+html.escape(n['body'])+'</div></div>'

doc=ET.Element('mxfile',host='app.diagrams.net',pages=str(len(pages)),version='32.4.1')
for pi,p in enumerate(pages):
 d=ET.SubElement(doc,'diagram',id=p['id'],name=('00 / Обзор' if pi==0 else p['title']))
 m=ET.SubElement(d,'mxGraphModel',page='1',pageWidth=str(W),pageHeight=str(p['height']),background=BG,grid='1',gridSize='10')
 r=ET.SubElement(m,'root');ET.SubElement(r,'mxCell',id='0');ET.SubElement(r,'mxCell',id='1',parent='0')
 def cell(nid,value,x,y,w,h,style,link=None):
  ob=ET.SubElement(r,'UserObject',id=nid,label=value,**({'link':'data:page/id,'+link} if link else {}))
  c=ET.SubElement(ob,'mxCell',vertex='1',parent='1',style='html=1;whiteSpace=wrap;fontFamily=Arial;'+style)
  ET.SubElement(c,'mxGeometry',x=str(x),y=str(y),width=str(w),height=str(h),**{'as':'geometry'})
 cell('brand','СЕКЦИЯ / ТЕХНИЧЕСКОЕ ЗАДАНИЕ · РЕДАКЦИЯ 2',60,30,1500,45,'fillColor='+INK+';strokeColor=none;fontColor=#FFFFFF;fontSize=18;align=left;spacingLeft=18;')
 cell('title',html.escape(p['title']),60,100,1800,58,'text;strokeColor=none;fillColor=none;fontSize=36;fontStyle=1;align=left;')
 cell('subtitle',html.escape(p['subtitle']),60,165,1800,44,'text;strokeColor=none;fillColor=none;fontSize=21;align=left;')
 for i,s in enumerate(['green','yellow','red']):
  fill,stroke,lab=PALETTE[s];cell('legend-'+s,lab,60+i*460,230,440,42,f'rounded=1;fillColor={fill};strokeColor={stroke};fontColor={stroke};fontSize=17;fontStyle=1;')
 cell('note','Цвет — готовность требования в коде; жёлтый также означает незавершённый переход к фирмам и складам.',60,p['height']-67,1800,24,'text;fillColor=none;strokeColor=none;fontColor='+MUTED+';fontSize=15;align=left;')
 cell('date',f'{DATE} · Код {REV} · '+str(pi+1)+' / '+str(len(pages)),60,p['height']-35,1800,20,'text;fillColor=none;strokeColor=none;fontColor='+MUTED+';fontSize=14;align=left;')
 if pi:cell('back','← Общая карта',1580,30,280,45,'rounded=1;fillColor='+INK+';strokeColor=none;fontColor=#FFFFFF;fontSize=18;',link='map')
 for j,e in enumerate(p['edges']):
  entry={'right':'entryX=1;entryY=0.5;','left':'entryX=0;entryY=0.5;','top':'entryX=0.5;entryY=0;'}[e['entry']]
  c=ET.SubElement(r,'mxCell',id='edge-'+str(j),edge='1',parent='1',source=e['source'],target=e['target'],style='html=1;edgeStyle=orthogonalEdgeStyle;rounded=1;orthogonalLoop=1;jettySize=auto;strokeColor=#A39A8B;strokeWidth=2;endArrow=block;exitX=0.5;exitY=1;'+entry)
  g=ET.SubElement(c,'mxGeometry',relative='1',**{'as':'geometry'})
  if e['points']:
   a=ET.SubElement(g,'Array',**{'as':'points'})
   for x,y in e['points']:ET.SubElement(a,'mxPoint',x=str(x),y=str(y))
 for n in p['nodes']:
  fill,stroke,_=PALETTE[n['state']]
  cell(n['id'],label(n),n['x'],n['y'],n['w'],n['h'],f'rounded=1;arcSize=10;fillColor={fill};strokeColor={stroke};strokeWidth=2;align=left;verticalAlign=middle;spacing=20;',n['link'])
ET.indent(doc)
drawio=OUT/'section-spec-v2.drawio';ET.ElementTree(doc).write(drawio,encoding='utf-8',xml_declaration=True)
(OUT/'requirements-v2.json').write_text(json.dumps({'date':DATE,'code_revision':REV,'modules':MODULES,'questions':QUESTIONS},ensure_ascii=False,indent=2),encoding='utf-8')

pdf=fitz.open(); archive=fitz.Archive('C:/Windows/Fonts')
css="@font-face{font-family:Arial;src:url(arial.ttf)} @font-face{font-family:Arial;src:url(arialbd.ttf);font-weight:bold} body{font-family:Arial;color:#242820;margin:0;}"
text_checks=[]
def rgb(h):return tuple(int(h[i:i+2],16)/255 for i in (1,3,5))
def textbox(page,rect,content,size=20,color=INK):
 spare,scale=page.insert_htmlbox(fitz.Rect(rect),f'<div style="font-size:{size}px;color:{color}">{content}</div>',css=css,archive=archive,scale_low=1)
 if spare<0:raise RuntimeError('Text overflow: '+content[:100])
 text_checks.append(scale)
for pi,p in enumerate(pages):
 page=pdf.new_page(width=W,height=p['height']);page.draw_rect(page.rect,fill=rgb(BG),color=None)
 page.draw_rect(fitz.Rect(60,30,1860,75),fill=rgb(INK),color=None)
 textbox(page,(80,41,1550,72),'СЕКЦИЯ / ТЕХНИЧЕСКОЕ ЗАДАНИЕ · РЕДАКЦИЯ 2',18,'#FFFFFF')
 textbox(page,(60,100,1860,160),'<b>'+html.escape(p['title'])+'</b>',36)
 textbox(page,(60,168,1860,215),html.escape(p['subtitle']),21)
 for i,s in enumerate(['green','yellow','red']):
  fill,stroke,lab=PALETTE[s];rect=fitz.Rect(60+i*460,230,500+i*460,272);page.draw_rect(rect,fill=rgb(fill),color=rgb(stroke),radius=0.15)
  textbox(page,(rect.x0+15,240,rect.x1-10,270),'<b>'+lab+'</b>',17,stroke)
 for e in p['edges']:
  source=next(n for n in p['nodes'] if n['id']==e['source']);target=next(n for n in p['nodes'] if n['id']==e['target'])
  start=(source['x']+source['w']/2,source['y']+source['h'])
  end={'right':(target['x']+target['w'],target['y']+target['h']/2),'left':(target['x'],target['y']+target['h']/2),'top':(target['x']+target['w']/2,target['y'])}[e['entry']]
  pts=[start]+e['points']+[end]
  if len(pts)==2 and start[0]!=end[0]:pts=[start,(start[0],(start[1]+end[1])/2),(end[0],(start[1]+end[1])/2),end]
  for a,b in zip(pts,pts[1:]):page.draw_line(a,b,color=rgb('#A39A8B'),width=2)
 for n in p['nodes']:
  fill,stroke,lab=PALETTE[n['state']];rect=fitz.Rect(n['x'],n['y'],n['x']+n['w'],n['y']+n['h']);page.draw_rect(rect,fill=rgb(fill),color=rgb(stroke),width=2,radius=0.08)
  # Compact central root nodes use a shorter label, without a redundant status.
  if n['h']<=110:
   content=f'<div style="font-size:23px"><b>{html.escape(n["title"])}</b></div><div style="font-size:17px;margin-top:7px">{html.escape(n["body"])}</div>'
  else:content=label(n)
  textbox(page,(rect.x0+20,rect.y0+15,rect.x1-20,rect.y1-12),content,19)
 if pi:
  page.draw_rect(fitz.Rect(1580,30,1860,75),fill=rgb(INK),color=None)
  textbox(page,(1600,42,1850,74),'← Общая карта',18,'#FFFFFF')
 textbox(page,(60,p['height']-67,1860,p['height']-40),'Цвет — готовность требования в коде; жёлтый также означает незавершённый переход к фирмам и складам.',15,MUTED)
 textbox(page,(60,p['height']-35,1860,p['height']-10),f'{DATE} · Код {REV} · {pi+1} / {len(pages)}',14,MUTED)
for pi,p in enumerate(pages):
 for n in p['nodes']:
  if n['link']:pdf[pi].insert_link({'kind':fitz.LINK_GOTO,'from':fitz.Rect(n['x'],n['y'],n['x']+n['w'],n['y']+n['h']),'page':next(i for i,q in enumerate(pages) if q['id']==n['link'])})
 if pi:pdf[pi].insert_link({'kind':fitz.LINK_GOTO,'from':fitz.Rect(1580,30,1860,75),'page':0})
pdf.set_toc([[1,'Общая карта',1]]+[[1,p['title'],i+1] for i,p in enumerate(pages) if i])
pdf.set_metadata({'title':'СЕКЦИЯ — графическое ТЗ, редакция 2','subject':'Фирмы, склады, роли и складской учёт','author':'Проект СЕКЦИЯ'})
pdf.save(OUT/'section-spec-v2.pdf',garbage=4,deflate=True)
qa=OUT/'preview';qa.mkdir(exist_ok=True)
for i,p in enumerate(pdf):
 pix=p.get_pixmap(matrix=fitz.Matrix(1400/W,1400/W),alpha=False);pix.save(qa/f'page-{i+1:02d}.png')
pdf[0].get_pixmap(matrix=fitz.Matrix(1,1),alpha=False).save(OUT/'overview-v2.png')
pdf.close()

# Offline HTML: navigation by sections and expandable requirement branches.
nav=''.join(f'<a href="#{p["id"]}">{html.escape(p["title"])}</a>' for p in pages)
body=''
for p in pages:
 body+=f'<section id="{p["id"]}"><h1>{html.escape(p["title"])}</h1><p class="subtitle">{html.escape(p["subtitle"])}</p><div class="tree">'
 for n in p['nodes']:
  fill,stroke,lab=PALETTE[n['state']]
  if n['id'].endswith('root') or n['id']=='root':continue
  if n['link']:
   body+=f'<a class="card" href="#{n["link"]}" style="--fill:{fill};--stroke:{stroke}"><small>{lab}</small><h2>{html.escape(n["title"])}</h2><p>{html.escape(n["body"])}</p><b>Открыть раздел →</b></a>'
  else:
   body+=f'<details class="card" open style="--fill:{fill};--stroke:{stroke}"><summary><small>{lab}</small><h2>{html.escape(n["title"])}</h2></summary><p>{html.escape(n["body"])}</p></details>'
 body+='</div><a class="back" href="#map">↑ Общая карта</a></section>'
htmltext='''<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>СЕКЦИЯ · Графическое ТЗ · Редакция 2</title><style>
*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:22px}body{margin:0;background:#F4F0E8;color:#242820;font-family:Arial,sans-serif;line-height:1.5}header{background:#242820;color:#fff;padding:26px 4vw}header b{font-size:26px}header p{margin:8px 0}aside{position:fixed;top:0;bottom:0;width:270px;overflow:auto;background:#e9e3d8;padding:24px 18px}aside a{display:block;color:inherit;padding:9px;text-decoration:none;border-bottom:1px solid #cec6b8;font-size:14px}main{margin-left:270px}section{padding:35px 4vw;border-bottom:2px solid #d4ccbe}h1{font-size:32px;line-height:1.2}h2{font-size:21px;line-height:1.3;margin:7px 0}.subtitle{font-size:18px;max-width:1100px}.tree{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px;position:relative;padding-left:24px;border-left:3px solid #b3aa9a}.card{background:var(--fill);border:1.5px solid var(--stroke);border-radius:12px;padding:22px;color:inherit;text-decoration:none;position:relative}.card:before{content:'';position:absolute;left:-25px;top:38px;width:23px;border-top:2px solid #b3aa9a}.card p{margin:10px 0 0;font-size:17px}.card small{color:var(--stroke);font-weight:bold;letter-spacing:1px}summary{cursor:pointer}summary h2{display:inline}summary small{display:block}.back{display:inline-block;margin-top:24px;color:#665d50}a:focus-visible,summary:focus-visible{outline:3px solid #242820;outline-offset:4px}.legend{display:flex;gap:10px;flex-wrap:wrap}.legend span{padding:7px 12px;border-radius:7px;color:#242820;font-size:14px}@media(max-width:1000px){aside{position:relative;width:auto;max-height:250px}main{margin-left:0}.tree{grid-template-columns:1fr}h1{font-size:26px}}@media print{aside,.back{display:none}main{margin:0}section{break-before:page}.tree{display:block}.card{display:block;break-inside:avoid;margin:12px 0}}
</style>'''+f'<aside><b>СЕКЦИЯ · ТЗ 2</b><p>{DATE}</p>{nav}</aside><main><header><b>Фирмы, склады и движение материалов</b><p>Редакция 2 · {DATE} · состояние кода {REV}</p><div class="legend"><span style="background:#DCEFE3">Готово</span><span style="background:#FFF0C6">Частично</span><span style="background:#F8DFDA">Не реализовано</span><span style="background:#E8E3D9">На согласование</span></div><p>Цвет отражает реализацию требования, а не независимую приёмку. Готовые базовые функции не означают готовую изоляцию фирм.</p></header>{body}</main></html>'
(OUT/'section-spec-v2.html').write_text(htmltext,encoding='utf-8')
counts={s:sum(item[1]==s for m in MODULES for item in m[3]) for s in ['green','yellow','red']}
(OUT/'verification.json').write_text(json.dumps({'date':DATE,'revision':REV,'pages':len(pages),'requirements':sum(counts.values()),'status_counts':counts,'open_decisions':len(QUESTIONS),'pdf_text_overflows':0,'pdf_generation':'Shared content and geometry with Draw.io; rendered with PyMuPDF','drawio_native_render':'Not available: desktop executable absent'},ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'pages':len(pages),'requirements':sum(counts.values()),'status_counts':counts},ensure_ascii=False))

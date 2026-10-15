from pathlib import Path
import shutil,json,hashlib,zipfile
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from PIL import Image
from pypdf import PdfReader

OUT=Path(__file__).resolve().parent
SRC=OUT.parent
PNG=OUT/'concept-png';PNG.mkdir(exist_ok=True)
SCREENS=[
 ('01-login','Вход','screen-2-234.png','2:234'),
 ('02-registration','Регистрация','registration.png',None),
 ('03-pending','Ожидание активации','screen-2-295.png','2:295'),
 ('04-catalog-cards','Каталог: карточки','catalog.png',None),
 ('05-catalog-table','Каталог: таблица','screen-2-67.png','2:67'),
 ('06-product-detail','Карточка товара','screen-2-110.png','2:110'),
 ('07-product-create-error','Создание товара: ошибка артикула','screen-2-144.png','2:144'),
 ('08-admin-users','Управление пользователями','screen-2-180.png','2:180'),
 ('09-mobile-catalog','Каталог на узком экране','screen-2-316.png','2:316')
]
url='https://www.figma.com/design/fRy4i8gmJo8H882xNO2Mld'
manifest={'source':url,'captured_at':'2026-10-15','revision':'early concept before photographic imagery update','native_fig_exported':False,'screens':[]}
for name,title,file,node in SCREENS:
 target=PNG/(name+'.png')
 if (SRC/file).exists():shutil.copy2(SRC/file,target)
 if not target.exists():raise FileNotFoundError(target)
 with Image.open(target) as im:im.verify()
 with Image.open(target) as im:size=list(im.size)
 manifest['screens'].append({'file':'concept-png/'+target.name,'title':title,'node_id':node,'dimensions':size,'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
pdfmetrics.registerFont(TTFont('Arial','C:/Windows/Fonts/arial.ttf'))
pdfmetrics.registerFont(TTFont('ArialBold','C:/Windows/Fonts/arialbd.ttf'))
pdf=OUT/'section-concept-archive.pdf'
c=canvas.Canvas(str(pdf),pagesize=(1600,1000))
c.setTitle('СЕКЦИЯ — архив ранних макетов Figma')
c.setAuthor('СЕКЦИЯ')
def header(title,page):
 c.setFillColorRGB(.95,.94,.91);c.rect(0,0,1600,1000,fill=1,stroke=0)
 c.setFillColorRGB(.13,.14,.13);c.setFont('ArialBold',32);c.drawString(55,925,title)
 c.setFont('Arial',17);c.drawString(55,880,'АРХИВ КОНЦЕПЦИИ · 15.10.2026 · до обновления фотографий')
 c.setFont('Arial',13);c.drawString(55,30,f'СЕКЦИЯ / Figma · {page} / 10')
header('СЕКЦИЯ — макеты интерфейса',1)
c.setFont('Arial',24)
for i,line in enumerate([
 '9 сохранённых экранов из Figma.',
 'Это ранний концепт: условные иллюстрации позднее заменены фотографиями.',
 'Актуальная редактируемая версия находится в Figma по ссылке ниже.',
 'Этот PDF предназначен для просмотра; исходным файлом .fig он не является.',
 'Изображения экранов сохранены без изменения исходных PNG.'
]):c.drawString(55,760-i*55,line)
c.setFont('ArialBold',22);c.drawString(55,400,'Открыть актуальные макеты Figma →')
c.linkURL(url,(55,390,650,430),relative=0)
c.setFont('Arial',15);c.drawString(55,355,url)
c.showPage()
for i,(name,title,_,_) in enumerate(SCREENS,2):
 header(title,i)
 path=PNG/(name+'.png')
 with Image.open(path) as im:w,h=im.size
 scale=min(1490/w,775/h);dw,dh=w*scale,h*scale
 c.drawImage(str(path),55+(1490-dw)/2,75+(775-dh)/2,width=dw,height=dh,mask='auto')
 c.showPage()
c.save()
assert len(PdfReader(pdf).pages)==10
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
if (SRC/'registration-implemented.jpg').exists():
 shutil.copy2(SRC/'registration-implemented.jpg',OUT/'registration-implemented.jpg')
(OUT/'README.md').write_text('''# СЕКЦИЯ — файлы макетов

[Актуальный редактируемый файл Figma](https://www.figma.com/design/fRy4i8gmJo8H882xNO2Mld).

- `concept-png/` — 9 ранее сохранённых экспортов экранов Figma. **Это ранняя концепция до замены условных иллюстраций на фотографии.**
- `section-concept-archive.pdf` — те же 9 экранов и обложка с явным обозначением версии.
- `registration-implemented.jpg` — отдельный снимок реализованной регистрации с фотографией склада; это снимок приложения, а не экспорт Figma.
- `manifest.json` — состав, размеры, проверочные суммы и известные ссылки на узлы.

Исходный `.fig` не включён: на момент упаковки экспорт через подключение Figma ограничен тарифом Starter, а браузер открыт без авторизации и требует входа для сохранения копии. PDF/PNG не являются редактируемым исходником. Не заменяйте ими актуальную версию Figma.

Примеры имён и адресов на ранних макетах — демонстрационные данные. Пароли и токены в пакет не включены.
''',encoding='utf-8')
archive=OUT.parent/'section-figma-concept-archive.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
 for path in sorted(OUT.rglob('*')):
  if path.is_file() and path.name!='package_design.py' and 'qa' not in path.relative_to(OUT).parts:z.write(path,path.relative_to(OUT))
print(f'9 PNG files verified; 10 PDF pages; archive: {archive.name}')

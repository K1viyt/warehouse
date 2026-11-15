# СЕКЦИЯ

React-клиент и Rails API работают на одном адресе. Rails отдаёт собранный интерфейс и использует существующие сессии и CSRF-защиту.

## Запуск интерфейса

В корне проекта, с Node.js 22.12+ и настроенным подключением Rails к PostgreSQL:

```sh
npm --prefix frontend ci
npm --prefix frontend run build
bin/rails db:migrate
bin/rails server
```

Откройте http://localhost:3000. При разработке `npm --prefix frontend run dev` пересобирает клиент при изменении исходников. Обновите страницу в браузере, чтобы увидеть правки.

Dockerfile собирает React на этапе сборки образа. Фото товаров хранятся через Active Storage. При использовании локального диска в контейнере подключите постоянный том к `/rails/storage`.

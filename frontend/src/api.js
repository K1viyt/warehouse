const messages = {
  "Invalid email or password": "Неверная почта или пароль.",
  "Your access has been blocked": "Доступ к аккаунту заблокирован.",
  "Authentication required": "Войдите в аккаунт.",
  "Account is pending activation": "Заявка ожидает одобрения.",
  "Administrator access required": "Действие доступно администратору.",
  "Select an accessible warehouse": "Выберите склад, к которому у вас есть доступ.",
  "A product with this article number already exists.": "Товар с таким артикулом уже есть.",
  "Product not found": "Товар не найден.",
  "Email address has already been taken": "Такой адрес уже зарегистрирован.",
  "Email address is invalid": "Проверьте формат почты.",
  "Password confirmation doesn't match Password": "Пароли не совпадают.",
  "Sku has already been taken": "Товар с таким артикулом уже есть.",
  "Name can't be blank": "Укажите имя или наименование.",
  "Sku can't be blank": "Укажите артикул.",
  "Unit is not included in the list": "Выберите единицу измерения «шт» или «кг».",
  "User not found": "Пользователь не найден.",
  "User is already active": "Пользователь уже активен.",
  "User is already blocked": "Пользователь уже заблокирован."
};

export class ApiError extends Error {
  constructor(status, data) {
    const errors = data?.errors ?? (data?.error ? [data.error] : []);
    const fallback = status === 429 ? "Письмо уже запрошено. Повторите через минуту." : "Запрос не выполнен. Попробуйте снова.";
    super(errors.map(message => messages[message] ?? message).join(" ") || fallback);
    this.status = status;
  }
}

async function read(response) {
  const type = response.headers.get("Content-Type") ?? "";
  const body = type.includes("application/json") ? await response.text() : "";
  const data = body ? JSON.parse(body) : null;
  if (!response.ok) throw new ApiError(response.status, data);
  return data;
}

export async function request(path, { method = "GET", body, signal } = {}) {
  const headers = { Accept: "application/json" };
  if (method !== "GET") {
    const tokenResponse = await fetch("/interface/csrf", { headers, credentials: "same-origin", signal });
    const { csrf_token } = await read(tokenResponse);
    headers["X-CSRF-Token"] = csrf_token;
  }
  if (body && !(body instanceof FormData)) {
    headers["Content-Type"] = "application/json";
    body = JSON.stringify(body);
  }
  return read(await fetch(path, { method, headers, body, credentials: "same-origin", signal }));
}

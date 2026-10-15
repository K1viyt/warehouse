const messages = {
  "Invalid email or password": "Неверная почта или пароль.",
  "Authentication required": "Войдите в систему, чтобы продолжить.",
  "Account is pending activation": "Аккаунт ожидает активации администратором.",
  "Your access has been blocked": "Доступ заблокирован. Обратитесь к администратору.",
  "Administrator access required": "Этот раздел доступен администратору.",
  "Email address has already been taken": "Пользователь с такой почтой уже есть в системе.",
  "Email address can't be blank": "Укажите почту.",
  "Name can't be blank": "Укажите название или имя.",
  "Sku can't be blank": "Укажите артикул.",
  "Sku has already been taken": "Товар с таким артикулом уже существует.",
  "Unit can't be blank": "Выберите единицу измерения.",
  "Unit is not included in the list": "Доступны только единицы «шт» и «кг».",
  "Password can't be blank": "Укажите пароль.",
  "Password confirmation doesn't match Password": "Пароли не совпадают.",
  "A product with this article number already exists.": "Товар с таким артикулом уже существует.",
  "User not found": "Пользователь не найден. Обновите список.",
  "User is already active": "Пользователь уже активирован.",
  "User is already blocked": "Пользователь уже заблокирован.",
  "Administrator accounts cannot be blocked": "Аккаунт администратора нельзя заблокировать.",
  "Pending user must be activated first": "Сначала активируйте пользователя.",
  "Blocked user must be unblocked first": "Сначала разблокируйте пользователя."
}

export function errorMessage(error) {
  const values = error.body?.errors || (error.body?.error ? [error.body.error] : [])
  if (values.length) return values.map(value => messages[value] || value).join(" ")
  return ({ 400: "Проверьте заполнение формы.", 401: "Сессия завершена. Войдите снова.",
    403: "Недостаточно прав для этого действия.", 404: "Запись не найдена.",
    409: "Данные уже изменились. Обновите список.", 422: "Проверьте поля формы." })[error.status]
    || "Не удалось выполнить действие. Повторите попытку."
}

export const escapeHtml = value => String(value ?? "").replace(/[&<>"']/g, char =>
  ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[char])

export function productImage(product, images) {
  const sku = product.sku?.trim()
  const known = { "BOLT-M8": "bolt", "DOWEL-8": "dowel", "SCR-4.5": "screw" }
  return images[known[sku]] || images.generic
}

export const statusLabel = status => ({ pending: "Ожидает", active: "Активен", blocked: "Заблокирован" })[status] || status
export const roleLabel = role => role === "admin" ? "Администратор" : "Оператор"

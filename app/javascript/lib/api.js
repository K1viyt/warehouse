export class ApiError extends Error {
  constructor(status, body) {
    super(body?.error || "Request failed")
    this.status = status
    this.body = body
  }
}

export async function request(path, { method = "GET", body, signal } = {}) {
  let response
  try {
    // A blocked session or another tab can rotate the session after HTML was loaded.
    // Obtain the token for the current cookie before any mutation.
    let token
    if (method !== "GET") {
      const session = await fetch("/interface/csrf", {
        credentials: "same-origin", cache: "no-store", headers: { Accept: "application/json" }
      })
      if (!session.ok) throw new Error("Cannot refresh session token")
      token = (await session.json()).csrf_token
    }
    response = await fetch(path, {
      method, signal, credentials: "same-origin",
      headers: {
        Accept: "application/json",
        ...(body ? { "Content-Type": "application/json" } : {}),
        ...(method !== "GET" ? { "X-CSRF-Token": token } : {})
      },
      ...(body ? { body: JSON.stringify(body) } : {})
    })
  } catch (error) {
    if (error.name === "AbortError") throw error
    throw new ApiError(0, { error: "Не удалось связаться с сервером. Проверьте соединение и повторите попытку." })
  }
  const csrf = response.headers.get("X-CSRF-Token")
  if (csrf) document.querySelector('meta[name="csrf-token"]').content = csrf
  if (response.status === 204) return null
  const isJson = response.headers.get("content-type")?.includes("application/json")
  const data = isJson ? await response.json() : null
  if (!response.ok) throw new ApiError(response.status, data)
  if (!isJson) throw new ApiError(502, { error: "Сервер вернул неожиданный ответ. Повторите попытку." })
  return data
}

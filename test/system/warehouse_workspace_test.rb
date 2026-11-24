require "test_helper"
require "action_dispatch/system_test_case"

class WarehouseWorkspaceTest < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 900 ]

  test "operator creates a catalog card, posts a receipt and reads the warehouse journal" do
    user = create_user(name: "Оператор", email_address: "ui-flow@example.test", password: "secret123", status: "active")
    visit "/"
    fill_in "Электронная почта", with: user.email_address
    find("input[name=password]").set("secret123")
    click_button "Войти"
    click_button "Новый товар"
    fill_in "Наименование", with: "Крепёж тестовый"
    fill_in "Артикул", with: "UI-FLOW"
    click_button "Создать карточку"
    assert_text "Карточка «Крепёж тестовый» создана."
    click_button "Складской учёт"
    click_button "Новая операция"
    select "Крепёж тестовый · UI-FLOW", from: "Товар"
    fill_in "Количество", with: "12"
    fill_in "Основание", with: "Тестовая поставка"
    click_button "Провести"
    assert_text "Проведён"
    assert_selector ".stock-item dd", text: "12 шт"
    click_button "Журнал", exact: true
    assert_text "Тестовая поставка"
    click_button "Документы", exact: true
    assert_text "Проведён"
    find("summary", text: "История документа").click
    assert_text user.name
    click_button "Профиль"
    assert_text user.email_address
    click_button "Выйти"
    assert_button "Войти"
  end
end

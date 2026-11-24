require "test_helper"
require "action_dispatch/system_test_case"

class WarehouseWorkspaceTest < ActionDispatch::SystemTestCase
  if ENV["SELENIUM_REMOTE_URL"].present?
    Capybara.server_host = "127.0.0.1"
    Capybara.app_host = ENV.fetch("CAPYBARA_APP_HOST")
    Capybara.always_include_port = true
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 900 ],
      options: { browser: :remote, url: ENV.fetch("SELENIUM_REMOTE_URL") }
  else
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 900 ]
  end

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
  test "transfer approval and physical delivery follow warehouse assignments" do
    destination = warehouses(:one)
    company = destination.organization
    source = company.warehouses.create!(name: "Северная база")
    requester = create_user(name: "Заказчик", email_address: "requester@example.test", password: "secret123", status: "active")
    requester.warehouse_memberships.sole.update!(role: "warehouse_manager")
    sender = company.users.create!(name: "Кладовщик", email_address: "sender@example.test", password: "secret123", status: "active")
    sender.warehouse_memberships.create!(organization: company, warehouse: source, status: "active", role: "warehouse_manager")
    product = company.products.create!(name: "Анкер", sku: "TRANSFER-UI", unit: "шт")
    source.stock_balances.create!(product: product, quantity: 20)

    using_session(:destination) do
      open_stock(requester)
      click_button "Новая операция"
      select "Перемещение", from: "Вид операции"
      select source.name, from: "Склад-источник"
      select "Анкер · TRANSFER-UI", from: "Товар"
      fill_in "Количество", with: "7"
      fill_in "Основание", with: "Установка ворот"
      click_button "Оформить заявку"
      assert_text "На согласовании"
      click_button "Документы", exact: true
      assert_text "Установка ворот"
      assert_no_button "Одобрить"
    end
    using_session(:source) do
      open_stock(sender)
      click_button "Документы", exact: true
      click_button "Одобрить"
      click_button "Отправить", exact: true
      assert_text "В пути"
      assert_no_button "Принять"
    end
    using_session(:destination) do
      click_button "Остатки", exact: true
      click_button "Документы", exact: true
      click_button "Принять"
      assert_text "Принят"
      click_button "Остатки", exact: true
      assert_selector ".stock-item dd", text: "7 шт"
    end
  end

  private

  def open_stock(user)
    visit "/"
    fill_in "Электронная почта", with: user.email_address
    find("input[name=password]").set("secret123")
    click_button "Войти"
    click_button "Складской учёт"
  end
end

require "test_helper"

class ProductPhotosTest < ActionDispatch::IntegrationTest
  test "creates a product with a photo and replaces the photo within its organization" do
    sign_in(create_user(name: "Photo operator", email_address: "photos@example.com",
      password: "secret123", status: "active"))

    post "/products", params: { product: { sku: "PHOTO-1", name: "Болт", unit: "шт", photo: upload("bolt") } }
    assert_response :created
    product = Product.find(response.parsed_body.fetch("id"))
    original_url = response.parsed_body.fetch("photo_url")
    assert_equal 0, product.stock_balances.sole.quantity

    get original_url
    assert_response :ok
    assert_equal "image/webp", response.media_type
    assert_equal Rails.root.join("app/assets/images/section/bolt.webp").binread, response.body.b

    put product_photo_path(product), params: { photo: upload("dowel") }
    assert_response :ok
    replacement_url = response.parsed_body.fetch("photo_url")
    assert_not_equal original_url, replacement_url
    get replacement_url
    assert_response :ok
    assert_equal Rails.root.join("app/assets/images/section/dowel.webp").binread, response.body.b

    invalid = Rack::Test::UploadedFile.new(StringIO.new("not an image"), "image/webp", original_filename: "fake.webp")
    put product_photo_path(product), params: { photo: invalid }
    assert_response :unprocessable_entity
    assert_equal "dowel.webp", product.reload.photo.filename.to_s

    delete "/session"
    get replacement_url
    assert_response :unauthorized

    outsider = User.create!(organization: Organization.create!(name: "Other company"), name: "Other admin",
      email_address: "other-photos@example.com", password: "secret123", status: "active", role: "admin")
    sign_in(outsider)
    get replacement_url
    assert_response :not_found
    put product_photo_path(product), params: { photo: upload("bolt") }
    assert_response :not_found
  end

  private

  def upload(name)
    Rack::Test::UploadedFile.new(Rails.root.join("app/assets/images/section/#{name}.webp"), "image/webp")
  end

  def sign_in(user)
    post "/session", params: { login: { email_address: user.email_address, password: "secret123" } }, as: :json
    assert_response :ok
  end
end

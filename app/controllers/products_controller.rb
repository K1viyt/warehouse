class ProductsController < ApplicationController
  PHOTO_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_PHOTO_SIZE = 5.megabytes

  before_action :require_active_user
  before_action :find_product, only: [ :show, :photo, :update_photo, :destroy, :archive, :update ]

  before_action :require_edit_access, only: [ :update, :update_photo, :archive, :destroy ]

  def index
    products = current_organization.products.with_attached_photo.order(:id)
    render json: products.map { |product| product_json(product) }
  end

  def show
    render json: product_json(@product)
  end
  def create
    attributes = params.expect(product: [ :sku, :name, :unit, :photo ])
    upload = attributes.delete(:photo)
    warehouses = current_user.accessible_warehouses
    warehouse = if params[:warehouse_id].present?
      warehouses.find_by(id: params[:warehouse_id])
    elsif warehouses.limit(2).count == 1
      warehouses.first
    end
    unless warehouse
      return render json: { errors: [ "Select an accessible warehouse" ] }, status: :unprocessable_entity
    end
    return render_invalid_photo if upload && !valid_photo?(upload)

    product = current_organization.products.new(attributes)
    product.photo = upload if upload
    ProductCreation.call(product, warehouse: warehouse)
    render json: product_json(product), status: :created
  rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages },
         status: :unprocessable_entity

  rescue ActiveRecord::RecordNotUnique
    render json: { errors: [ "A product with this article number already exists." ] }, status: :conflict
  end

  def update
    @product.with_lock { @product.update!(params.expect(product: [ :name, :sku ])) }
    render json: product_json(@product)
  end

  def archive
    retire(delete: false)
  end

  def destroy
    retire(delete: true)
  end

  def photo
    return head :not_found unless @product.photo.attached?

    response.headers["Cache-Control"] = "private, no-store"
    send_data @product.photo.download, type: @product.photo.content_type,
      disposition: "inline", filename: @product.photo.filename.to_s
  end

  def update_photo
    upload = params[:photo]
    return render_invalid_photo unless valid_photo?(upload)

    @product.with_lock { @product.update!(photo: upload) }
    render json: product_json(@product)
  rescue ActiveRecord::RecordInvalid => error
    render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def require_edit_access
    head :forbidden unless current_user.accessible_warehouses.exists?
  end

  def retire(delete:)
    @product.with_lock do
      lines = WarehouseLine.where(product: @product)
      busy = @product.stock_balances.where.not(quantity: 0).exists? ||
        lines.joins(:warehouse_document).where(warehouse_documents: { state: %w[pending approved shipped] }).exists?
      history = delete && (@product.stock_movements.exists? || lines.exists?)
      if busy || history
        return render json: { error: "Есть остаток, документы или движения. Для завершённой истории используйте архив." }, status: :conflict
      end
      if delete
        @product.stock_balances.delete_all
        @product.destroy!
      else
        @product.update!(archived_at: Time.current)
      end
    end
    head :no_content
  end

  def find_product
    @product = current_organization.products.with_attached_photo.find_by(id: params[:id])
    render json: { error: "Product not found" }, status: :not_found unless @product
  end

  def product_json(product)
    product.as_json.merge(photo_url: product.photo.attached? ? product_photo_path(product, v: product.photo.blob.id) : nil)
  end

  def valid_photo?(upload)
    upload.is_a?(ActionDispatch::Http::UploadedFile) &&
      upload.size.between?(1, MAX_PHOTO_SIZE) &&
      PHOTO_TYPES.include?(Marcel::MimeType.for(upload.tempfile))
  end

  def render_invalid_photo
    render json: { errors: [ "Загрузите фотографию JPEG, PNG или WebP размером до 5 МБ." ] }, status: :unprocessable_entity
  end
end

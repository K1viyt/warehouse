class WarehouseWorkflow
  class Invalid < StandardError; end
  class Conflict < StandardError; end

  def initialize(actor)
    @actor = actor
    @company = actor.organization
  end

  def create(data)
    key = data[:request_key].to_s
    raise Invalid, "Обновите форму операции" unless key.match?(/\A[\da-f]{8}-(?:[\da-f]{4}-){3}[\da-f]{12}\z/i)
    kind = data[:kind]
    raise Invalid, "Неизвестный документ" unless %w[issue receipt transfer purchase].include?(kind)
    destination = @actor.accessible_warehouses.find(data[:warehouse_id])
    source = @company.warehouses.find(data[:source_id]) if kind == "transfer"
    raise Invalid, "Выберите разные склады" if source == destination
    rows = data[:lines]
    raise Invalid, "Добавьте от 1 до 100 позиций" unless rows.is_a?(Array) && rows.size.between?(1, 100)
    WarehouseDocument.transaction do
      # Serialize retries from the same operator before reading their request key.
      @actor.lock!
      raise Pundit::NotAuthorizedError unless StockWarehousePolicy.new(@actor, destination).operate?
      quantities = Hash.new(0)
      rows.sort_by { |row| row[:product_id].to_i }.each do |row|
        product = @company.products.lock("FOR SHARE").find(row[:product_id])
        quantity = BigDecimal(row[:quantity].to_s, exception: false)
        unless quantity&.finite? && quantity.positive? && quantity <= 999_999_999 && quantity.round(3) == quantity && (product.unit != "шт" || quantity.frac.zero?)
          raise Invalid, "Укажите целые штуки или килограммы с точностью до 0,001"
        end
        quantities[product.id] += quantity
        raise Invalid, "Слишком большое количество" if quantities[product.id] > 999_999_999
      end
      attrs = { organization: @company, warehouse: destination, source: source, kind: kind, reason: data[:reason].to_s.strip }
      doc = WarehouseDocument.find_or_initialize_by(user: @actor, request_key: key)
      if doc.persisted?
        unless attrs.all? { |k, v| doc.public_send(k) == v } && doc.warehouse_lines.pluck(:product_id, :quantity).to_h == quantities
          raise Conflict, "Этот запрос уже использован для другого документа"
        end
      else
        doc.assign_attributes(attrs)
        raise Invalid, "Архивный товар недоступен" if @company.products.where(id: quantities.keys).where.not(archived_at: nil).exists?
        doc.save!
        quantities.each { |id, q| doc.warehouse_lines.create!(organization: @company, product_id: id, quantity: q) }
        if %w[issue receipt].include?(kind)
          post_lines(doc, destination, kind)
          doc.update!(state: "posted")
        end
        record(doc)
      end
      doc
    end
  end

  def advance(doc, action)
    doc.with_lock do
      raise Pundit::NotAuthorizedError unless doc.actions(@actor).include?(action)
      next_state = case action
      when "approve"
        reserve(doc, 1) if doc.source
        "approved"
      when "reject" then "rejected"
      when "cancel"
        reserve(doc, -1) if doc.source && doc.state == "approved"
        "cancelled"
      when "ship"
        reserve(doc, -1)
        post_lines(doc, doc.source, "issue")
        "shipped"
      when "receive"
        post_lines(doc, doc.warehouse, "receipt")
        "received"
      end
      doc.update!(state: next_state)
      record(doc)
    end
    doc
  end

  private

  def record(doc)
    doc.document_events.create!(organization_id: @company.id, user: @actor, state: doc.state)
  end

  def each_balance(doc, warehouse)
    doc.warehouse_lines.order(:product_id).each do |line|
      balance = warehouse.stock_balances.lock.find_by(product_id: line.product_id)
      unless balance
        StockBalance.insert_all([ { organization_id: @company.id, warehouse_id: warehouse.id, product_id: line.product_id, quantity: 0 } ], unique_by: [ :warehouse_id, :product_id ])
        balance = warehouse.stock_balances.lock.find_by!(product_id: line.product_id)
      end
      yield line, balance
    end
  end

  def reserve(doc, direction)
    each_balance(doc, doc.source) do |line, balance|
      require_available(balance, line.quantity) if direction == 1
      balance.update!(reserved: balance.reserved + direction * line.quantity)
    end
  end

  def require_available(balance, amount)
    available = balance.quantity - balance.reserved
    raise Conflict, "Недостаточно товара. Доступно #{available.to_s('F')}." if available < amount
  end

  def post_lines(doc, warehouse, type)
    each_balance(doc, warehouse) do |line, balance|
      require_available(balance, line.quantity) if type == "issue"
      result = balance.quantity + (type == "issue" ? -line.quantity : line.quantity)
      raise Invalid, "Превышен максимальный остаток" if result >= 1_000_000_000
      balance.update!(quantity: result)
      StockMovement.create!(organization: @company, user: @actor, product_id: line.product_id, warehouse: warehouse,
        quantity: line.quantity, movement_type: type, reason: doc.reason, warehouse_document_id: doc.id)
    end
  end
end

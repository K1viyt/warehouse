class MembershipChange
  def self.call(actor:, membership:, attributes:)
    membership.user.with_lock do
      actor.reload
      membership.reload if membership.persisted?
      Pundit.authorize(actor, membership, :update?)
      if attributes[:status] == "active" && membership.user.blocked?
        raise CredentialChange::StaleRequest, "Сначала разблокируйте учётную запись сотрудника."
      end
      membership.assign_attributes(attributes)
      membership.save!
      membership.user.active! if membership.active? && membership.user.pending?
      AccessEvent.create!(organization: membership.organization, actor: actor, user: membership.user,
        action: "warehouse_membership_changed", details: { warehouse_id: membership.warehouse_id,
          role: membership.role, status: membership.status })
    end
    membership
  end
end

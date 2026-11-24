# Every entry point uses the same user lock and transaction.
class CredentialChange
  class StaleRequest < StandardError; end
  class InvalidProof < StandardError; end

  def self.call(user:, password:, password_confirmation:, expected_version:, actor: nil,
    recovery_request: nil, token: nil, current_password: nil, temporary: false)
    user.with_lock do
      raise StaleRequest, "Данные уже изменились. Начните восстановление заново." unless user.credentials_version == expected_version
      if temporary
        actor.reload
        Pundit.authorize(actor, user, :reset_password?)
        recovery_request.reload
        unless recovery_request.user_id == user.id && recovery_request.actionable?
          raise StaleRequest, "Заявка уже обработана или устарела."
        end
      elsif token
        verified = User.find_by_token_for(:account_recovery, token)
        raise InvalidProof, "Ссылка недействительна или просрочена." unless verified&.id == user.id && user.email_verified?
      else
        raise InvalidProof, "Текущий пароль неверен." unless user.authenticate(current_password.to_s)
        raise InvalidProof, "Доступ заблокирован." if user.blocked?
      end
      if password.blank? || password_confirmation.blank?
        user.errors.add(:password, "и подтверждение обязательны")
        raise ActiveRecord::RecordInvalid, user
      end
      if user.authenticate(password)
        user.errors.add(:password, "должен отличаться от текущего")
        raise ActiveRecord::RecordInvalid, user
      end
      user.update!(password: password, password_confirmation: password_confirmation,
        password_change_required: temporary)
      user.password_recovery_requests.pending.update_all(status: "superseded", handled_at: Time.current, updated_at: Time.current)
      recovery_request&.update!(status: "completed", handled_by: actor, handled_at: Time.current)
      AccessEvent.create!(organization: user.organization, user: user, actor: actor || user,
        action: temporary ? "password_reset_by_admin" : "password_changed")
    end
    if user.email_verified?
      ActiveRecord.after_all_transactions_commit do
        PasswordRecoveryMailer.changed(user).deliver_later
      end
    end
    user
  end
end

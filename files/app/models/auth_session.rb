class AuthSession < ActiveRecord::Base
  belongs_to :user

  validates :user, :credentials, presence: true

  after_create 'AuthSession.prune_old_sessions'

  def self.authenticated_user(user_id, credentials)
    return nil unless user_id.present? && credentials.present?
    User.joins(:auth_sessions).where(:'auth_sessions.credentials' => credentials).find_by(id: user_id)
  end

  def self.prune_old_sessions(age=30)
    date = age.days.ago.utc.beginning_of_day.to_date
    AuthSession.where('updated_at < ?', date).delete_all
  end
end

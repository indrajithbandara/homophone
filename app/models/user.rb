class User < ActiveRecord::Base
  has_secure_password

  validates_uniqueness_of :email
  validates_presence_of :email

  validates :password, presence: true,
            length: { minimum: 5, maximum: 40 },
            confirmation: true

  validates_confirmation_of :password
end

# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  name                   :string(255)
#  email                  :string(255)
#  gender                 :string(255)      default("F")
#  dob                    :date
#  admin                  :boolean          default(FALSE)
#  location               :string(255)
#  lat                    :float
#  lng                    :float
#  password_digest        :string(255)
#  remember_token         :string(255)
#  password_reset_token   :string(255)
#  password_reset_sent_at :datetime
#  created_at             :datetime
#  updated_at             :datetime
#

class User < ActiveRecord::Base
  has_secure_password validations: false

  has_many :invites, dependent: :destroy
  has_many :invited_events, through: :invites, source: :event
  
  has_many :events

  has_many :attendances, -> { where cancel: false }, dependent: :destroy                     
  has_many :attended_events, -> { where "attendances.cancel" => false },
                             through: :attendances, source: :event

  has_many :relationships, foreign_key: "sharer_id", dependent: :destroy
  has_many :reverse_relationships, foreign_key: "sharee_id",
                                   class_name:  "Relationship", dependent: :destroy
  has_many :sharees, through: :relationships
  has_many :sharers, through: :reverse_relationships
                    
  before_save { self.email = email.downcase.strip }
  before_save :create_remember_token

  validates :name, presence: true, length: { maximum: 50 }
  validates :password, length: { minimum: 6 }, on: :create
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validates :email, presence: true, 
                    format: { with: VALID_EMAIL_REGEX }, 
                    uniqueness: { case_sensitive: false }

  # name formatting
  def first_name
    if %w[mr mr. dr dr. ms ms. mrs mrs.].include? self.name.split(' ').first.downcase
      self.name.split(' ')[1]
    else
      self.name.split(' ').first
    end
  end
  def last_name
    if %w[jr jr. sr sr. ii iii iv v].include? self.name.split(' ').last.downcase
      self.name.split(' ')[-2]
    else
      self.name.split(' ').last
    end
  end  
      
  # invites
  def invited? (event)
    self.invites.find_by_event_id(event.id)
  end
  def invite! (event)
    self.invites.create!(event_id: event.id)
  end
  def uninvite! (event)
    self.invites.find_by_event_id(event.id).destroy
  end

  # attendances
  def attending? (event)
    self.attendances.find_by_event_id(event.id)
  end
  def attend! (event)
    if attd = self.attendances.find_by_event_id(event.id)
      attd.update_attribute(:cancel, false)
    else
      self.attendances.create!(event_id: event.id, iCalUID: "#{SecureRandom.uuid.split('-')[4]}@palendar")
    end
  end
  def not_attending! (event)
    self.attendances.find_by_event_id(event.id).update_attribute(:cancel, true)
  end

  # Check to see if @user is sharing with current user
  def shared? (other_user)
    self.reverse_relationships.find_by_sharer_id(other_user.id)
  end
  # Check to see if current user is sharing with @user
  def sharing? (other_user)
    self.relationships.find_by_sharee_id(other_user.id)
  end
  def share! (other_user)
    if !self.relationships.find_by_sharee_id_and_sharer_id(other_user.id, self.id)
      self.relationships.create!(sharee_id: other_user.id)
    end
  end
  def unshare! (other_user)
    self.relationships.find_by_sharee_id(other_user.id).destroy
  end

  # password reset
  def send_password_reset
    generate_token(:password_reset_token)
    self.password_reset_sent_at = Time.zone.now
    save!
    UserMailer.password_reset(self).deliver
  end
  def generate_token(column)
    begin
      self[column] = SecureRandom.urlsafe_base64
    end while User.exists?(column => self[column])
  end

  private
    def create_remember_token
      self.remember_token = SecureRandom.urlsafe_base64
    end
end



class User < ActiveRecord::Base
  ALLOW_LOGIN_CHARS_REGEXP = /\A[A-Za-z0-9\-\_\.]+\z/
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :async, authentication_keys: [:login]
  devise :omniauthable, omniauth_providers: [:github]

  act_as_liker
  has_many :like_movies, through: "likees", source: :likee, source_type: "Movie"
  has_many :like_articles, through: "likees", source: :likee, source_type: "Article"
  has_many :like_softs, through: "likees", source: :likee, source_type: "Soft"

  has_many :articles

  validate :validate_username
  validates :username, format: { with: ALLOW_LOGIN_CHARS_REGEXP, message: '只允许数字、大小写字母和下划线' },
                       length: { in: 3..20 }, presence: true,
                       uniqueness: { case_sensitive: true }

  mount_uploader :avatar, AvatarUploader

  def self.from_omniauth(auth)
    ap auth.extra.raw_info.login
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = "from_github_#{auth.info.email}"
      user.username = auth.extra.raw_info.login
      user.password = Devise.friendly_token[0, 20]
    end
  end

  def letter_avatar_url(size)
    avatar_url || LetterAvatar.generate(Pinyin.t(self.username), size).sub('public/', '/')
  end

  def validate_username
    if User.where(email: username).exists?
      errors.add(:username, :invalid)
    end
  end

  def self.serialize_from_session(key, salt)
    Rails.cache.fetch "current_user_#{key}" do
      super
    end
  end

  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      where(conditions.to_hash).where(['lower(username) = :value OR lower(email) = :value', { value: login.downcase }]).first
    elsif conditions.key?(:username) || conditions.key?(:email)
      where(conditions.to_hash).first
    end
  end

  def self.random_like
    self.find_each do |user|
      articles = Article.limit(rand(Article.count))
      articles.each do |article|
        user.like article
        article.update_like_count
      end

      movies = Movie.limit(rand(Movie.count))
      movies.each do |movie|
        user.like movie
        movie.update_like_count
      end

      softs = Soft.limit(rand(Soft.count))
      softs.each do |soft|
        user.like soft
        soft.update_like_count
      end
    end
  end

  def hello_name
    self.nickname || self.username
  end

  def signature_name
    self.company_name.present? ? "#{self.position} @ #{self.company_name}" : self.position
  end

  attr_writer :login

  def login
    @login || self.username || self.email
  end

  def super_admin?
    Settings.admin_emails.include?(email)
  end
end

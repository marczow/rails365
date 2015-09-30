require "babosa"
class Article < ActiveRecord::Base
  include PgSearch
  pg_search_scope :search_by_title_or_body, :against => [:title, :body]
  acts_as_taggable
  ActsAsTaggableOn.remove_unused_tags = true
  extend FriendlyId
  friendly_id :title, use: [:slugged, :finders]
  belongs_to :group, counter_cache: true
  scope :published, -> { where(published: true) }
  validates :title, :body, presence: true
  validates :title, uniqueness: true

  def normalize_friendly_id(input)
    PinYin.of_string(input).to_s.to_slug.normalize.to_s
  end

  def should_generate_new_friendly_id?
    title_changed?
  end

  def tag_list
    super.join(", ")
  end
end

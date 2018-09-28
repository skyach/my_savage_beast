class Forum < ActiveRecord::Base
  acts_as_list

  validates_presence_of :name

  has_many :moderatorships, :dependent => :delete_all
  has_many :moderators, :through => :moderatorships, :source => :user

  has_many :topics, -> { order('sticky desc, replied_at desc') }, :dependent => :delete_all
  has_one  :recent_topic, -> { order('sticky desc, replied_at desc') }, :class_name => 'Topic'

  # this is used to see if a forum is "fresh"... we can't use topics because it puts
  # stickies first even if they are not the most recently modified
  has_many :recent_topics, -> { order('replied_at DESC') }, :class_name => 'Topic'
  has_one  :recent_topic, -> { order('replied_at DESC') },  :class_name => 'Topic'

  has_many :posts, -> { order("#{Post.table_name}.created_at DESC") }, :dependent => :delete_all
  has_one  :recent_post, -> { order("#{Post.table_name}.created_at DESC") }, :class_name => 'Post'

  format_attribute :description
  
  # retrieves forums ordered by position
  def self.find_ordered(options = {})
    # find :all, options.update(:order => 'position')
    all.order('position')
  end
end

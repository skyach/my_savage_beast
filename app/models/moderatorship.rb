class Moderatorship < ActiveRecord::Base
  belongs_to :forum
  belongs_to :user
  # before_create { |r| count(:id, :conditions => ['forum_id = ? and user_id = ?', r.forum_id, r.user_id]).zero? }
  before_create { |r| where('forum_id = ? and user_id = ?', r.forum_id, r.user_id).count.zero? }

end

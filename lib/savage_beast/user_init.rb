
module SavageBeast

  module UserInit

    def self.included(base)
      base.class_eval do

				has_many :moderatorships, :dependent => :destroy
				has_many :forums, -> { order("#{Forum.table_name}.name") }, :through => :moderatorships

				has_many :posts
				has_many :topics
				has_many :monitorships
				has_many :monitored_topics, -> {where("#{Monitorship.table_name}.active = ?", true).order("#{Topic.table_name}.replied_at desc")}, :through => :monitorships, :source => :topic


				#implement in your user model 
				def display_name
					"Foo Diddly"
				end
				
				#implement in your user model 
				def admin?
					false
				end
				
        def moderator_of?(forum)
          moderatorships.where('forum_id = ?', (forum.is_a?(Forum) ? forum.id : forum)).count == 1
        end

        def to_xml(options = {})
          options[:except] ||= []
          super
        end
      end
      base.extend(ClassMethods)
    end

    module ClassMethods			
			#implement in your user model 
			def currently_online
				false
			end
			
			def search(query, options = {})
				where(build_search_conditions(query)) do
					options[:page] ||= nil
					paginate options
				end
			end
			
			#implmement to build search coondtitions
			def build_search_conditions(query)
				# query && ['LOWER(display_name) LIKE :q OR LOWER(login) LIKE :q', {:q => "%#{query}%"}]
				query
			end
			
			def moderator_of?(forum)
				# moderatorships.count("#{Moderatorship.table_name}.id", :conditions => ['forum_id = ?', (forum.is_a?(Forum) ? forum.id : forum)]) == 1
				moderatorships.where('forum_id = ?', (forum.is_a?(Forum) ? forum.id : forum)).count == 1
			end
			
			def to_xml(options = {})
				options[:except] ||= []
				options[:except] << :email << :login_key << :login_key_expires_at << :password_hash << :openid_url << :activated << :admin
				super
			end
			
			def update_posts_count
				self.class.update_posts_count id
			end
			
			def update_posts_count(id)
				# User.update_all ['posts_count = ?', Post.count(:id, :conditions => {:user_id => id})],   ['id = ?', id]
				User.where('id = ?', id).update_all(posts_count: Post.where(:user_id => id).count)
			end
			
    end
      
  end
end
class PostsController < ApplicationController
  before_action :find_post,      :except => [:index, :create, :monitored, :search]
  before_action :login_required, :except => [:index, :monitored, :search, :show]

	# @WBH@ TODO: This uses the caches_formatted_page method.  In the main Beast project, this is implemented via a Config/Initializer file.  Not
	# sure what analogous place to put it in this plugin.  It don't work in the init.rb
  #caches_formatted_page :rss, :index, :monitored
  cache_sweeper :posts_sweeper, :only => [:create, :update, :destroy]

  def index
    conditions = []
    [:user_id, :forum_id, :topic_id].each { |attr| conditions << Post.send(:sanitize_sql, ["#{Post.table_name}.#{attr} = ?", params[attr]]) if params[attr] }
    conditions = conditions.empty? ? nil : conditions.collect { |c| "(#{c})" }.join(' AND ')
    @posts = Post.select_and_join_data.where(conditions).order(post_order).paginate(page: params[:page])
    @users = User.select('distinct *').where('id in (?)', @posts.collect(&:user_id).uniq).index_by(&:id)
    render_posts_or_xml
  end

  def search		
    conditions = params[:q].blank? ? nil : Post.send(:sanitize_sql, ["LOWER(#{Post.table_name}.body) LIKE ?", "%#{params[:q]}%"])
    @posts = Post.select_and_join_data.where(conditions).order(post_order).paginate(page: params[:page])
    @users = User.select('distinct *').where('id in (?)', @posts.collect(&:user_id).uniq).index_by(&:id)
    render_posts_or_xml :index
  end

  def monitored
    @user = User.find params[:user_id]
    query = "#{Monitorship.table_name}.user_id = #{params[:user_id]} and #{Post.table_name}.user_id != #{@user.id} and #{Monitorship.table_name}.active = #{true}"
    join  = " inner join #{Monitorship.table_name} on #{Monitorship.table_name}.topic_id = #{Topic.table_name}.id"
    @posts = Post.select_and_join_data(join).where(query).order(post_order).paginate(page: params[:page])
    render_posts_or_xml
  end

  def show
    respond_to do |format|
      format.html { redirect_to forum_topic_path(@post.forum_id, @post.topic_id) }
      format.xml  { render :xml => @post.to_xml }
    end
  end

  def create
    @topic = Topic.find_by(id: params[:topic_id], fourm_id: params[:forum_id])
    if @topic.locked?
      respond_to do |format|
        format.html do
          flash[:notice] = 'This topic is locked.'[:locked_topic]
          redirect_to(forum_topic_path(:forum_id => params[:forum_id], :id => params[:topic_id]))
        end
        format.xml do
          render :text => 'This topic is locked.'[:locked_topic], :status => 400
        end
      end
      return
    end
    @forum = @topic.forum
    @post  = @topic.posts.build(params[:post])
    @post.user = current_user
    @post.save!
    respond_to do |format|
      format.html do
        redirect_to forum_topic_path(:forum_id => params[:forum_id], :id => params[:topic_id], :anchor => @post.dom_id, :page => params[:page] || '1')
      end
      format.xml { head :created, :location => post_url(:forum_id => params[:forum_id], :topic_id => params[:topic_id], :id => @post, :format => :xml) }
    end
  rescue ActiveRecord::RecordInvalid
    flash[:bad_reply] = 'Please post something at least...'[:post_something_message]
    respond_to do |format|
      format.html do
        redirect_to forum_topic_path(:forum_id => params[:forum_id], :id => params[:topic_id], :anchor => 'reply-form', :page => params[:page] || '1')
      end
      format.xml { render :xml => @post.errors.to_xml, :status => 400 }
    end
  end
  
  def edit
    respond_to do |format| 
      format.html
      format.js
    end
  end
  
  def update
    @post.attributes = params[:post]
    @post.save!
  rescue ActiveRecord::RecordInvalid
    flash[:bad_reply] = 'An error occurred'[:error_occured_message]
  ensure
    respond_to do |format|
      format.html do
        redirect_to forum_topic_path(:forum_id => params[:forum_id], :id => params[:topic_id], :anchor => @post.dom_id, :page => params[:page] || '1')
      end
      format.js
      format.xml { head 200 }
    end
  end

  def destroy
    @post.destroy
    flash[:notice] = "Post of '{title}' was deleted."[:post_deleted_message, @post.topic.title]
    respond_to do |format|
      format.html do
        redirect_to(@post.topic.frozen? ? 
          forum_path(params[:forum_id]) :
          forum_topic_path(:forum_id => params[:forum_id], :id => params[:topic_id], :page => params[:page]))
      end
      format.xml { head 200 }
    end
  end

  protected
    def authorized?
      action_name == 'create' || @post.editable_by?(current_user)
    end
    
    def post_order
      "#{Post.table_name}.created_at#{params[:forum_id] && params[:topic_id] ? nil : " desc"}"
    end
    
    def find_post			
			@post = Post.find_by(id: params[:id], topic_id: params[:topic_id], forum_id: params[:forum_id]) || raise(ActiveRecord::RecordNotFound)
    end
    
    def render_posts_or_xml(template_name = action_name)
      respond_to do |format|
        format.html { render :action => template_name }
        format.rss  { render :action => template_name, :layout => false }
        format.xml  { render :xml => @posts.to_xml }
      end
    end
end

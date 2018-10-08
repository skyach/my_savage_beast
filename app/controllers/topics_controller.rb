class TopicsController < ApplicationController
  before_action :find_forum_and_topic, :except => :index
  before_action :login_required, :only => [:new, :create, :edit, :update, :destroy]

	# @WBH@ TODO: This uses the caches_formatted_page method.  In the main Beast project, this is implemented via a Config/Initializer file.  Not
	# sure what analogous place to put it in this plugin.  It don't work in the init.rb  
  #caches_formatted_page :rss, :show
  cache_sweeper :posts_sweeper, :only => [:create, :update, :destroy]

  def index
    respond_to do |format|
      format.html { redirect_to forum_path(params[:forum_id]) }
      format.xml do
        @topics = Topic.where(forum_id: params[:forum_id]).order('sticky desc, replied_at desc').paginate(:page => params[:page])
        render :xml => @topics.to_xml
      end
    end
  end

  def new
    @topic = Topic.new
  end
  
  def show
    respond_to do |format|
      format.html do
        # see notes in application.rb on how this works
        update_last_seen_at
        # keep track of when we last viewed this topic for activity indicators
        (session[:topics] ||= {})[@topic.id] = Time.now.utc if logged_in?
        # authors of topics don't get counted towards total hits
        @topic.hit! unless logged_in? and @topic.user == current_user
        @posts = @topic.posts.paginate(:page => params[:page])
        User.where('id IN (?)', @posts.collect { |p| p.user_id }.uniq) unless @posts.blank?
        @post   = Post.new
      end
      format.xml do
        render :xml => @topic.to_xml
      end
      format.rss do
        @posts = @topic.posts.order('created_at desc').limit(25)
        render :action => 'show', :layout => false
      end
    end
  end
  
  def create
    topic_saved, post_saved = false, false
		# this is icky - move the topic/first post workings into the topic model?
    Topic.transaction do
	    @topic  = @forum.topics.build(topic_params)
      assign_protected
      @post       = @topic.posts.build(post_params)
      @post.topic = @topic
      @post.user  = current_user
      # only save topic if post is valid so in the view topic will be a new record if there was an error
      @topic.body = @post.body # incase save fails and we go back to the form
      topic_saved = @topic.save if @post.valid?
      post_saved = @post.save
    end
		
		if topic_saved && post_saved
			respond_to do |format| 
				format.html { redirect_to forum_topic_path(@forum, @topic) }
				format.xml  { head :created, :location => topic_url(:forum_id => @forum, :id => @topic, :format => :xml) }
			end
		else
			render :action => "new"
		end
  end
  
  def update
    @topic.attributes = topic_params
    assign_protected
    @topic.save!
    respond_to do |format|
      format.html { redirect_to forum_topic_path(@forum, @topic) }
      format.xml  { head 200 }
    end
  end
  
  def destroy
    @topic.destroy
    flash[:notice] = t(:topic_deleted_message,title: @topic.title)
    respond_to do |format|
      format.html { redirect_to forum_path(@forum) }
      format.xml  { head 200 }
    end
  end

  private

  def topic_params
    params.require(:topic).permit(:title, :sticky, :locked, :body, :forum_id)
  end


  def post_params
    params.require(:topic).permit(:body)
  end
  
  protected
    def assign_protected
      @topic.user     = current_user if @topic.new_record?
      # admins and moderators can sticky and lock topics
      return unless admin? or current_user.moderator_of?(@topic.forum)
      @topic.sticky, @topic.locked = params[:topic][:sticky], params[:topic][:locked] 
      # only admins can move
      return unless admin?
      @topic.forum_id = params[:topic][:forum_id] if params[:topic][:forum_id]
    end
    
    def find_forum_and_topic
      @forum = Forum.find(params[:forum_id])
      @topic = @forum.topics.find(params[:id]) if params[:id]
    end
    
    def authorized?
      %w(new create).include?(action_name) || @topic.editable_by?(current_user)
    end
end

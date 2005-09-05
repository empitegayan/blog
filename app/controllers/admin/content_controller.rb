class Admin::ContentController < Admin::BaseController
  cache_sweeper :blog_sweeper

  def index
    list
    render_action 'list'
  end

  def list
    @articles_pages, @articles = paginate :article, :per_page => 15, :order_by => "created_at DESC", :parameter => 'id'
    @categories = Category.find(:all)
    @article = Article.new(params[:article])
    @article.text_filter = config[:text_filter]
  end

  def show
    @article = Article.find(params[:id])
    @categories = Category.find(:all, :order => 'name')
    @resources = Resource.find(:all, :order => 'created_at DESC')
  end

  def new
    @article = Article.new(params[:article])
    @article.author = session[:user].login
    @article.allow_comments ||= config[:default_allow_comments]
    @article.allow_pings ||= config[:default_allow_pings]
    @article.text_filter ||= TextFilter.find_by_name(config[:text_filter])
    @article.user = session[:user]
    update_html(@article)
    
    @categories = Category.find(:all, :order => 'UPPER(name)')
    if request.post?
      @article.categories.clear
      @article.categories << Category.find(params[:categories]) if params[:categories]

      params[:attachments].each do |k,v|
        a = attachment_save(params[:attachments][k])
        @article.resources << a unless a.nil?
      end unless params[:attachments].nil?

      if @article.save 
        flash[:notice] = 'Article was successfully created.'
        redirect_to :action => 'show', :id => @article.id
      end
    end
  end

  def edit
    @article = Article.find(params[:id])
    @article.attributes = params[:article]
    @categories = Category.find(:all, :order => 'UPPER(name)')
    @selected = @article.categories.collect { |cat| cat.id.to_i }
    if request.post? 
      @article.categories.clear
      @article.categories << Category.find(params[:categories]) if params[:categories]
      update_html(@article)
      
      params[:attachments].each do |k,v|
        a = attachment_save(params[:attachments][k])        
        @article.resources << a unless a.nil?
      end unless params[:attachments].nil?

      if @article.save 
        flash[:notice] = 'Article was successfully updated.'
        redirect_to :action => 'show', :id => @article.id
      end
    end      
  end

  def destroy
    @article = Article.find(params[:id])
    if request.post?
      @article.destroy
      redirect_to :action => 'list'
    end
  end
  
  def category_add
    @article = Article.find(params[:id])
    @category = Category.find(params[:category_id])
    @categories = Category.find(:all)
    @article.categories << @category
    @article.save
    render :partial => 'show_categories'
  end

  def category_remove
    @article = Article.find(params[:id])
    @category = Category.find(params[:category_id])
    @categories = Category.find(:all)
    @article.categories.delete(@category)
    @article.save
    render :partial => 'show_categories'
  end
  
  def preview
    @headers["Content-Type"] = "text/html; charset=utf-8"
    @article = Article.new
    @article.attributes = params[:article]
    update_html(@article)
    render :layout => false
  end
  
  def resource_add
    @article = Article.find(params[:id])
    @resource = Resource.find(params[:resource_id])
    @resources = Resource.find(:all, :order => 'created_at DESC')
    @article.resources << @resource
    @article.save
    render :partial => 'show_resources'
  end

  def resource_remove
    @article = Article.find(params[:id])
    @resource = Resource.find(params[:resource_id])
    @resources = Resource.find(:all, :order => 'created_at DESC')
    @article.resources.delete(@resource)
    @article.save
    render :partial => 'show_resources'
  end

  def attachment_box_add
    render :partial => 'admin/content/attachment', :locals => { :attachment_num => params[:id] }
  end

  def attachment_box_remove
    render :inline => "<%= javascript_tag 'document.getElementById(\"attachments\").removeChild(document.getElementById(\"attachment_#{params[:id]}\")); return false;' -%>", :layout => false
  end

  def attachment_save(attachment)
    begin
      up = Resource.create(:filename => attachment.original_filename, :mime => attachment.content_type.chomp, :created_at => Time.now)
      up.write_to_disk(attachment)
      up
    rescue => e
      logger.info(e.message)
      nil
    end
  end

  private
  def update_html(article)
    article.body_html = nil
    article.extended_html = nil
  end
  
end

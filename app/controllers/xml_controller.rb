class XmlController < ContentController
  caches_action_with_params :feed
  session :off

  NORMALIZED_FORMAT_FOR = {'atom' => 'atom03', 'rss' => 'rss20',
    'atom03' => 'atom03', 'atom10' => 'atom10', 'rss20' => 'rss20'}

  CONTENT_TYPE_FOR = { 'rss20' => 'application/xml',
    'atom03' => 'application/atom+xml', 'atom10' => 'application/atom+xml' }


  def feed
    @items = Array.new
    @format = params[:format]

    @feed_title = this_blog.blog_name
    @link = url_for({:controller => "articles"},{:only_path => false})

    @format = NORMALIZED_FORMAT_FOR[@format]

    if not @format
      render :text => 'Unsupported format', :status => 404
      return
    end

    @headers["Content-Type"] = "#{CONTENT_TYPE_FOR[@format]}; charset=utf-8"

    if respond_to?("prep_#{params[:type]}")
      self.send("prep_#{params[:type]}")
    else
      render :text => 'Unsupported action', :status => 404
      return
    end

    render :action => "#{@format}_feed"
  end

  def itunes
    @feed_title = "#{this_blog.blog_name} Podcast"
    @items = Resource.find(:all, :order => 'created_at DESC',
      :conditions => ['itunes_metadata = ?', true], :limit => this_blog.limit_rss_display)
    render :action => "itunes_feed"
  end

  def articlerss
    redirect_to :action => 'feed', :format => 'rss20', :type => 'article', :id => params[:id]
  end

  def commentrss
    redirect_to :action => 'feed', :format => 'rss20', :type => 'comments'
  end
  def trackbackrss
    redirect_to :action => 'feed', :format => 'rss20', :type => 'trackbacks'
  end

  def rsd
  end

  protected

  def fetch_items(association, order='created_at DESC', limit=nil)
    if association.instance_of?(Symbol)
      association = this_blog.send(association)
    end
    limit ||= this_blog.limit_rss_display
    @items = association.find_already_published(:all, :limit => limit, :order => order)
  end

  def prep_feed
    fetch_items(:articles)
  end

  def prep_comments
    fetch_items(:comments)
    @feed_title << " comments"
  end

  def prep_trackbacks
    fetch_items(:trackbacks)
    @feed_title << " trackbacks"
  end

  def prep_article
    article = this_blog.articles.find(params[:id])
    fetch_items(article.comments, 'created_at DESC', 25)
    @items.unshift(article)
    @feed_title << ": #{article.title}"
    @link = article_url(article, false)
  end

  def prep_category
    category = Category.find_by_permalink(params[:id])
    fetch_items(category.articles)
    @feed_title << ": Category #{category.name}"
    @link = url_for({:controller => "articles", :action => "category", :id => category.permalink},
                    {:only_path => false})
  end

  def prep_tag
    tag = Tag.find_by_name(params[:id])
    fetch_items(tag.articles)
    @feed_title << ": Tag #{tag.display_name}"
    @link = url_for({:controller => "articles_controller.rb", :action => 'tag', :tag => tag.name},
                    {:only_path => false})
  end
end

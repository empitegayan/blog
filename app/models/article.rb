require 'uri'
require 'net/http'

class Article < Content
  include TypoGuid

  content_fields :body, :extended
  
  has_many :pings, :dependent => true, :order => "created_at ASC"
  has_many :comments, :dependent => true, :order => "created_at ASC"
  has_many :trackbacks, :dependent => true, :order => "created_at ASC"
  has_many :resources, :order => "created_at DESC",
           :class_name => "Resource", :foreign_key => 'article_id'
  has_and_belongs_to_many :categories, :foreign_key => 'article_id'
  has_and_belongs_to_many :tags, :foreign_key => 'article_id'
  belongs_to :user
  
  after_destroy :fix_resources
  
  def stripped_title
    self.title.gsub(/<[^>]*>/,'').to_url
  end
  
  def html_urls
    urls = Array.new
    
    html(:all).gsub(/<a [^>]*>/) do |tag|
      if(tag =~ /href="([^"]+)"/)
        urls.push($1)
      end
    end
    
    urls
  end
  
  def send_pings(articleurl, urllist)
    return unless config[:send_outbound_pings]
    
    ping_urls = config[:ping_urls].gsub(/ +/,'').split(/[\n\r]+/)
    ping_urls += self.html_urls
    ping_urls += urllist.to_a
    
    ping_urls.uniq.each do |url|            
      begin
        unless pings.collect { |p| p.url }.include?(url.strip) 
          ping = pings.build("url" => url)

          ping.send_ping(articleurl)
          ping.save
        end
        
      rescue
        # in case the remote server doesn't respond or gives an error, 
        # we should throw an xmlrpc error here.
      end      
    end
  end
  
  def next
    Article.find(:first, :conditions => ['created_at > ?', created_at], :order => 'created_at asc')
  end

  def previous
    Article.find(:first, :conditions => ['created_at < ?', created_at], :order => 'created_at desc')
  end

  # Count articles on a certain date
  def self.count_by_date(year, month = nil, day = nil, limit = nil)  
    from, to = self.time_delta(year, month, day)
    Article.count(["#{Article.table_name}.created_at BETWEEN ? AND ? AND #{Article.table_name}.published != 0", from, to])
  end
  
  # Find all articles on a certain date
  def self.find_all_by_date(year, month = nil, day = nil)
    from, to = self.time_delta(year, month, day)
    Article.find(:all, :conditions => ["#{Article.table_name}.created_at BETWEEN ? AND ? AND #{Article.table_name}.published != 0", from, to], :order => "#{Article.table_name}.created_at DESC")
  end

  # Find one article on a certain date
  def self.find_by_date(year, month, day)  
    find_all_by_date(year, month, day).first
  end
  
  # Finds one article which was posted on a certain date and matches the supplied dashed-title
  def self.find_by_permalink(year, month, day, title)
    from, to = self.time_delta(year, month, day)
    find(:first, :conditions => [ %{
      permalink = ?
      AND #{Article.table_name}.created_at BETWEEN ? AND ?
      AND #{Article.table_name}.published != 0
    }, title, from, to ])
  end
  
  def self.find_published_by_category_permalink(category_permalink, options = {})
    category = Category.find_by_permalink(category_permalink)
    return [] unless category
    
    Article.find(:all, 
      { :conditions => [%{ published != 0 
        AND #{Article.table_name}.id = articles_categories.article_id
        AND articles_categories.category_id = ? }, category.id], 
      :joins => ", #{Article.table_name_prefix}articles_categories#{Article.table_name_suffix} articles_categories",
      :order => "created_at DESC", :readonly => false}.merge(options))
  end

  def self.find_published_by_tag_name(tag_name, options = {})
    tag = Tag.find_by_name(tag_name)
    return [] unless tag

    Article.find(:all, 
      { :conditions => [%{ published != 0 
        AND #{Article.table_name}.id = articles_tags.article_id
        AND articles_tags.tag_id = ? }, tag.id], 
      :joins => ", #{Article.table_name_prefix}articles_tags#{Article.table_name_suffix} articles_tags",
      :order => "created_at DESC", :readonly => false}.merge(options))
  end

  # Fulltext searches the body of published articles
  def self.search(query)
    if !query.to_s.strip.empty?
      tokens = query.split.collect {|c| "%#{c.downcase}%"}
      find_by_sql(["SELECT * FROM #{Article.table_name} WHERE #{Article.table_name}.published != 0 AND #{ (["(LOWER(body) LIKE ? OR LOWER(extended) LIKE ? OR LOWER(title) LIKE ?)"] * tokens.size).join(" AND ") } AND published != 0 AND type = 'Article' ORDER by created_at DESC", *tokens.collect { |token| [token] * 3 }.flatten])
    else
      []
    end
  end
  
  def keywords_to_tags
    Article.transaction do
      tags.clear
      keywords.to_s.split.uniq.each do |tagword|
        tags << Tag.get(tagword)
      end
    end
  end
  
  def send_notifications(controller)
    users = User.find(:all).to_a.select{ |u| u.notify_on_new_articles?}
    
    users.each do |u|
      send_notification_to_user(controller, u)
    end
  end
  
  def send_notification_to_user(controller, user)
    if user.notify_via_email? 
      EmailNotify.send_article(controller, self, user)
    end
    
    if user.notify_via_jabber?
      JabberNotify.send_message(user, "New post", "A new message was posted to #{config[:blog_name]}",article.body_html)
    end
  end
  
  protected  

  before_save :set_defaults, :create_guid
  before_create :add_notifications
  
  def set_defaults
    begin
      schema_info=Article.connection.select_one("select * from schema_info limit 1")
      schema_version=schema_info["version"].to_i
    rescue
      # The test DB doesn't currently support schema_info.
      schema_version=25
    end

    self.published ||= 1
    
    if schema_version >= 7
      self.permalink = self.stripped_title if self.attributes.include?("permalink") and self.permalink.blank?
    end

    if schema_version >= 10
      keywords_to_tags
    end
  end
  
  def add_notifications
    # Grr, how do I do :conditions => 'notify_on_new_articles = true' when on MySQL boolean DB tables
    # are integers, Postgres booleans are booleans, and sqlite is basically just a string?
    #
    # I'm punting for now and doing the test in Ruby.  Feel free to rewrite.
    
    self.notify_users = User.find(:all).to_a.select{ |u| u.notify_on_new_articles?}
    self.notify_users << self.user if self.user and self.user.notify_watch_my_articles?
    self.notify_users.uniq!
  end
  
  def default_text_filter_config_key
    'text_filter'
  end
  
  def self.time_delta(year, month = nil, day = nil)
    from = Time.mktime(year, month || 1, day || 1)
    
    to   = from + 1.year
    to   = from + 1.month unless month.blank?    
    to   = from + 1.day   unless day.blank?
    to   = to.tomorrow    unless month.blank?
    return [from, to]
  end
  

  validates_uniqueness_of :guid
  validates_presence_of :title

  private
  def fix_resources
    Resource.find(:all, :conditions => "article_id = #{id}").each do |fu|
      fu.article_id = nil
      fu.save
    end
  end
end

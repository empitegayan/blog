class Blog < ActiveRecord::Base
  include ConfigManager

  has_many :contents
  has_many :trackbacks
  has_many :articles
  has_many :pages, :order => "id DESC"
  has_many(:published_articles, :class_name => "Article",
           :conditions => ["published = ?", true],
           :include => [:categories, :tags],
           :order => "contents.created_at DESC") do
    def before(date = Time.now)
      find(:all, :conditions => ["contents.created_at < ?", date])
    end

    def size(date = nil)
      if date.nil?
        Article.count
      else
        Article.count ["created_at < ?", date]
      end
    end
  end

  has_many :pages
  has_many :comments

  serialize :settings, Hash

  # Description
  setting :blog_name,                  :string, 'My Shiny Weblog!'
  setting :blog_subtitle,              :string, ''
  setting :geourl_location,            :string, ''

  # Spam
  setting :sp_global,                  :boolean, false
  setting :sp_article_auto_close,      :integer, 0
  setting :sp_allow_non_ajax_comments, :boolean, true
  setting :sp_url_limit,               :integer, 0

  # Podcasting
  setting :itunes_explicit,            :boolean, false
  setting :itunes_author,              :string, ''
  setting :itunes_subtitle,            :string, ''
  setting :itunes_summary,             :string, ''
  setting :itunes_owner,               :string, ''
  setting :itunes_email,               :string, ''
  setting :itunes_name,                :string, ''
  setting :itunes_copyright,           :string, ''

  # Mostly Behaviour
  setting :text_filter,                :string, ''
  setting :comment_text_filter,        :string, ''
  setting :limit_article_display,      :integer, 10
  setting :limit_rss_display,          :integer, 10
  setting :default_allow_pings,        :boolean, false
  setting :default_allow_comments,     :boolean, true
  setting :link_to_author,             :boolean, false
  setting :show_extended_on_rss,       :boolean, true
  setting :theme,                      :string, 'azure'
  setting :use_gravatar,               :boolean, false
  setting :ping_urls,                  :string, "http://rpc.technorati.com/rpc/ping\nhttp://ping.blo.gs/\nhttp://rpc.weblogs.com/RPC2"
  setting :send_outbound_pings,        :boolean, true
  setting :email_from,                 :string, 'typo@example.com'

  # Jabber config
  setting :jabber_address,             :string, ''
  setting :jabber_password,            :string, ''

  def find_already_published(content_type)
    self.send(content_type).find_already_published
  end

  def ping_article!(settings)
    settings[:blog_id] = self.id
    article_id = settings[:id]
    settings.delete(:id)
    published_articles.find(article_id).trackbacks.create!(settings)
  end


  def is_ok?
    settings.has_key?('blog_name')
  end

  def [](key)
    self.send(key)
  end

  def []=(key, value)
    self.send("#{key}=", value)
  end

  def has_key?(key)
    self.class.fields.has_key?(key.to_s)
  end

  def initialize(*args)
    super
    self.settings ||= { }
  end

  def self.default
    find(:first, :order => 'id')
  end

  @@controller_stack = []
  cattr_accessor :controller_stack

  def self.before(controller)
    controller_stack << controller
  end

  def self.after(controller)
    unless controller_stack.last == controller
      raise "Controller stack got out of kilter!"
    end
    controller_stack.pop
  end

  def controller
    controller_stack.last
  end

  def current_theme_path
    Theme.themes_root + "/" + theme
  end

  def current_theme
    Theme.theme_from_path(current_theme_path)
  end

  def url_for(options = {}, *extra_params)
    case options
    when String then options
    when Hash
      options.reverse_merge!(:only_path => true, :controller => '/articles',
                             :action => 'permalink')
      url = ActionController::UrlRewriter.new(request, {})
      url.rewrite(options)
    else
      options.location(*extra_params)
    end
  end

  def article_url(article, only_path = true, anchor = nil)
    url_for(:year => article.created_at.year,
            :month => sprintf("%.2d", article.created_at.month),
            :day => sprintf("%.2d", article.created_at.day),
            :title => article.permalink, :anchor => anchor,
            :only_path => only_path)
  end

  def server_url
    controller.send :url_for, :only_path => false, :controller => "/"
  end

  private

  def request
    controller.request rescue ActionController::TestRequest.new
  end
end


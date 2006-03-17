# The filters added to this controller will be run for all controllers in the application.
# Likewise will all the methods added be available for all controllers.
class ContentController < ApplicationController
  class ExpiryFilter
    def before(controller)
      @request_time = Time.now
    end

    def after(controller)
       future_article =
         Article.find(:first,
                      :conditions => ['published = ? AND created_at > ?', true, @request_time],
                      :order =>  "created_at ASC" )
       if future_article
         delta = future_article.created_at - Time.now
         controller.response.lifetime = (delta <= 0) ? 0 : delta
       end
    end
  end

  include LoginSystem
  model :user

  before_filter :auto_discovery_defaults
  before_filter { $blog = nil; $blog = this_blog }
  after_filter :flush_the_blog_object

  def self.caches_action_with_params(*actions)
    super
    around_filter ExpiryFilter.new, :only => actions
  end

  def self.cache_page(content, path)
    begin
      # Don't cache the page if there are any questionmark characters in the url
      unless path =~ /\?\w+/ or path =~ /page\d+$/
        super(content,path)
        PageCache.create(:name => page_cache_file(path))
      end
    rescue # if there's a caching error, then just return the content.
      content
    end
  end

  def self.expire_page(path)
    if cache = PageCache.find(:first, :conditions => ['name = ?', path])
      cache.destroy
    end
  end

  def auto_discovery_defaults
    @auto_discovery_url_rss =
        @request.instance_variable_get(:@auto_discovery_url_rss)
    @auto_discovery_url_atom =
         @request.instance_variable_get(:@auto_discovery_url_atom)
    unless @auto_discovery_url_rss && @auto_discovery_url_atom
      auto_discovery_feed(:type => 'feed')
      @request.instance_variable_set(:@auto_discovery_url_rss,
                                      @auto_discovery_url_rss)
      @request.instance_variable_set(:@auto_discovery_url_atom,
                                      @auto_discovery_url_atom)
    end
  end

  def flush_the_blog_object
    $blog = nil
    true
  end

  def auto_discovery_feed(options)
    options = {:only_path => false, :action => 'feed', :controller => 'xml'}.merge options
    @auto_discovery_url_rss = url_for(({:format => 'rss20'}.merge options))
    @auto_discovery_url_atom = url_for(({:format => 'atom10'}.merge options))
  end

  def cache
    $cache ||= SimpleCache.new 1.hour
  end

  def theme_layout
    Theme.current.layout
  end

  helper_method :contents
  def contents
    if @articles
      @articles
    elsif @article
      [@article]
    elsif @page
      [@page]
    else
      []
    end
  end

  protected

  def self.include_protected(*modules)
    modules.reverse.each do |mod|
      included_methods = mod.public_instance_methods.reject do |meth|
        self.method_defined?(meth)
      end
      self.send(:include, mod)
      included_methods.each do |meth|
        protected meth
      end
    end
  end

  include_protected ActionView::Helpers::TagHelper, ActionView::Helpers::TextHelper

end

require_dependency 'controllers/textfilter_controller'

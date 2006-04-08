class Plugins::Sidebars::FlickrController < Sidebars::ComponentPlugin
  def self.display_name
    "Flickr"
  end

  def self.description
    'Pictures from <a href="http://www.flickr.com">flickr.com</a>'
  end

  def self.default_config
    {'count'=>4,'format'=>'rectangle'}
  end

  def content
    begin
      response.lifetime = 1.hour
      @flickr=check_cache(FlickrAggregation, @sb_config['feed'])
    rescue Exception => e
      logger.info e
      nil
    end
  end

  def configure
  end
end

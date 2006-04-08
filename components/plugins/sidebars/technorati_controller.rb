class Plugins::Sidebars::TechnoratiController < Sidebars::ComponentPlugin
  def self.display_name
    "Technorati"
  end

  def self.description
    'Display a <a href="http://www.technorati.com">Technorati</a> Watchlist'
  end

  def self.default_config
    {'name'=>'Watchlist','feed'=>'http://www.technorati.com/watchlists/rss.html?wid=WATCHLISTID','count'=>4}
  end

  def content
    response.lifetime = 1.hour
    @cosmos = check_cache(Technorati, @sb_config['feed']) rescue nil
  end

  def configure
  end
end

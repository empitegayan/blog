class Plugins::Sidebars::TagController < Sidebars::Plugin
  def self.display_name
    "Tags"
  end

  def self.description
    "Show most popular tags for this blog"
  end

  def content
    @tags = Tag.find_all_with_article_counters.sort_by {|t| -t.article_counter.to_i}.slice(0..20).sort_by {|t| t.name}
    total=@tags.inject(1) {|total,tag| total += tag.article_counter.to_i }
    @font_multiplier = @tags.size*100.0/total
  end
end

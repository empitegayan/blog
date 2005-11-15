require File.dirname(__FILE__) + '/../test_helper'

require 'http_mock'

class ArticleTest < Test::Unit::TestCase
  fixtures :contents, :settings, :articles_tags, :tags, :resources, :categories, :articles_categories
  
  def setup
    config.reload
  end
  
  def test_create
    a = Article.new
    a.user_id = 1
    a.body = "Foo"
    a.title = "Zzz"
    a.categories = [Category.find(1)]
    assert_equal 1, a.categories.size
    assert a.save
    
    b = Article.find(a.id)
    assert_equal 1, b.categories.size 
  end
  
  def test_permalink
    assert_equal contents(:article3), Article.find_by_date(2004,06,01)
    assert_equal [contents(:article2), contents(:article1)], Article.find_all_by_date(Time.now.year)  
  end

  def test_permalink_with_title
    assert_equal contents(:article3), Article.find_by_permalink(2004, 06, 01, "article-3")  
    assert_nil Article.find_by_permalink(2005, 06, 01, "article-5")  
  end
  
  def test_strip_title
    assert_equal "article-3", "Article-3".to_url
    assert_equal "article-3", "Article 3!?#".to_url
    assert_equal "there-is-sex-in-my-violence", "There is Sex in my Violence!".to_url
    assert_equal "article", "-article-".to_url
    assert_equal "lorem-ipsum-dolor-sit-amet-consectetaur-adipisicing-elit", "Lorem ipsum dolor sit amet, consectetaur adipisicing elit".to_url
    assert_equal "my-cats-best-friend", "My Cat's Best Friend".to_url
  end
  
  def test_perma_title
    assert_equal "article-1", contents(:article1).stripped_title
    assert_equal "article-2", contents(:article2).stripped_title
    assert_equal "article-3", contents(:article3).stripped_title
  end
  
  def test_html_title
    a = Article.new
    a.title = "This <i>is</i> a <b>test</b>"
    assert a.save
    
    assert_equal 'this-is-a-test', a.permalink
  end
  
  def test_urls
    urls = contents(:article4).html_urls
    assert_equal ["http://www.example.com/public"], urls
  end
  
  def test_send_pings
#    contents(:article1).send_pings("example.com", "http://localhost/post/5?param=1")
#    ping = Net::HTTP.pings.last
#    assert_equal "localhost",ping.host
#    assert_equal 80, ping.port
#    assert_equal "/post/5?param=1", ping.query
#    assert_equal "title=Article%201!&excerpt=body&url=example.com&blog_name=test%20blog", ping.post_data
  end

  def test_send_multiple_pings
    contents(:article1).send_pings("example.com", ["http://localhost/post/5?param=1", "http://127.0.0.1/article/5"])
    assert_equal 4, contents(:article1).pings.size
    assert_equal 4, Net::HTTP.pings.size # we don't actually ping example.com domains
    
    ping = Net::HTTP.pings[0]
    assert_equal "ping.example.com",ping.host

    ping = Net::HTTP.pings[1]
    assert_equal "alsoping.example.com",ping.host

    ping = Net::HTTP.pings[2]
    assert_equal "localhost",ping.host
    assert_equal 80, ping.port
    assert_equal "/post/5?param=1", ping.query
    assert_equal "title=Article%201!&excerpt=body&url=example.com&blog_name=test%20blog", ping.post_data

    ping = Net::HTTP.pings[3]
    assert_equal "127.0.0.1",ping.host
    assert_equal 80, ping.port
    assert_equal "/article/5?", ping.query
    assert_equal "title=Article%201!&excerpt=body&url=example.com&blog_name=test%20blog", ping.post_data
  end
  
  def test_tags
    a = Article.new(:title => 'Test tag article',
                    :keywords => 'test tag tag stuff');

    assert_kind_of Article, a
    assert_equal 0, a.tags.size

    a.keywords_to_tags
    
    assert_equal 3, a.tags.size
    assert_equal ["test", "tag", "stuff"].sort , a.tags.collect {|t| t.name}.sort
    assert a.save

    a.keywords = 'tag bar stuff foo'
    a.keywords_to_tags

    assert_equal 4, a.tags.size
    assert_equal ["foo", "bar", "tag", "stuff"].sort , a.tags.collect {|t| t.name}.sort
    
    a.keywords='tag bar'
    a.keywords_to_tags
    
    assert_equal 2, a.tags.size
    
    a.keywords=''
    a.keywords_to_tags
    
    assert_equal 0, a.tags.size

    b = Article.new(:title => 'Tag Test 2',
                    :keywords => 'tag test article one two three')

    assert_kind_of Article,b
    assert_equal 0, b.tags.size
  end

  def test_find_published_by_tag_name
    articles = Article.find_published_by_tag_name(tags(:foo_tag).name)

    assert_equal 2, articles.size
    assert_equal [contents(:article2), contents(:article1)], articles
  end
  
  def test_find_published_by_category
    articles = Article.find_published_by_category_permalink('personal')
    assert_equal 3, articles.size
    assert articles.include?(contents(:article1))
    assert articles.include?(contents(:article2))
    assert articles.include?(contents(:article3))
    
    articles = Article.find_published_by_category_permalink('foobar')
    assert_equal 0, articles.size

    articles = Article.find_published_by_category_permalink('software')
    assert_equal 1, articles.size
    assert articles.include?(contents(:article1))

    articles = Article.find_published_by_category_permalink('personal', :limit => 1)
    assert_equal 1, articles.size
    assert articles.include?(contents(:article2))

    articles = Article.find_published_by_category_permalink('personal', :limit => 1, :order => 'created_at ASC')
    assert_equal 1, articles.size
    assert articles.include?(contents(:article3))
  end

  def test_destroy_file_upload_associations
    assert_equal 2, contents(:article1).resources.size
    contents(:article1).resources << resources(:resource1) << resources(:resource2)
    assert_equal 4, contents(:article1).resources.size
    contents(:article1).destroy
    assert_equal 0, Resource.find(:all, :conditions => "article_id = #{contents(:article1).id}").size
  end
end

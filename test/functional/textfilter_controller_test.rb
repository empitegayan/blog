require File.dirname(__FILE__) + '/../test_helper'
require 'textfilter_controller'

require 'flickr_mock'

# Re-raise errors caught by the controller.
class TextfilterController; def rescue_action(e) raise e end; end

class TextfilterControllerTest < Test::Unit::TestCase
  fixtures :text_filters

  def setup
    @controller = TextfilterController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller.request = @request
    @controller.response = @response
    @controller.assigns ||= []
  end
  
  def test_unknown
    text = @controller.filter_text('*foo*',[:unknowndoesnotexist])
    assert_equal '*foo*', text
  end
  
  def test_smartypants
    text = @controller.filter_text('"foo"',[:smartypants])
    assert_equal '&#8220;foo&#8221;', text
  end

  def test_markdown
    text = @controller.filter_text('*foo*',[:markdown])
    assert_equal '<p><em>foo</em></p>', text

    text = @controller.filter_text("foo\n\nbar",[:markdown])
    assert_equal "<p>foo</p>\n\n<p>bar</p>", text
  end

  def test_filterchain
    assert_equal '<p><em>&#8220;foo&#8221;</em></p>', 
      @controller.filter_text('*"foo"*',[:markdown,:smartypants])

    assert_equal '<p><em>&#8220;foo&#8221;</em></p>', 
      @controller.filter_text('*"foo"*',[:doesntexist1,:markdown,"doesn't exist 2",:smartypants,:nopenotmeeither])
      
    assert_equal '<p>foo</p>', 
      @controller.filter_text('<p>foo</p>',[],{},false)
      
    assert_equal '&lt;p&gt;foo&lt;/p&gt;', 
      @controller.filter_text('<p>foo</p>',[],{},true)
  end
  
  def test_amazon
    text = @controller.filter_text('<a href="amazon:097669400X" title="Rails">Rails book</a>',
      [:amazon],
      'amazon-affiliateid' => 'scottstuff-20')
    assert_equal "<a href=\"http://www.amazon.com/exec/obidos/ASIN/097669400X/scottstuff-20\" title=\"Rails\">Rails book</a>",
      text

    text = @controller.filter_text('[Rails book](amazon:097669400X)',
      [:markdown,:amazon],
      'amazon-affiliateid' => 'scottstuff-20')
    assert_equal "<p><a href=\"http://www.amazon.com/exec/obidos/ASIN/097669400X/scottstuff-20\">Rails book</a></p>",
      text

    text = @controller.filter_text("Foo\n\n[Rails book](amazon:097669400X)",
      [:markdown,:amazon],
      'amazon-affiliateid' => 'scottstuff-20')
    assert_equal "<p>Foo</p>\n\n<p><a href=\"http://www.amazon.com/exec/obidos/ASIN/097669400X/scottstuff-20\">Rails book</a></p>",
          text
  end

  def test_flickr
    assert_equal "<div style=\"float:left\" class=\"flickrplugin\"><a href=\"http://www.flickr.com/photo_zoom.gne?id=31366117&size=sq\"><img src=\"http://photos23.flickr.com/31366117_b1a791d68e_s.jpg\" width=\"75\" height=\"75\" alt=\"Matz\" title=\"Matz\"/></a><p class=\"caption\" style=\"width:75px\">This is Matz, Ruby's creator</p></div>",
      @controller.filter_text('<typo:flickr img="31366117" size="Square" style="float:left"/>',
        [:macropre,:macropost],
        'flickr-user' => 'scott@sigkill.org')

    # Test default image size
    assert_equal "<div style=\"\" class=\"flickrplugin\"><a href=\"http://www.flickr.com/photo_zoom.gne?id=31366117&size=sq\"><img src=\"http://photos23.flickr.com/31366117_b1a791d68e_s.jpg\" width=\"75\" height=\"75\" alt=\"Matz\" title=\"Matz\"/></a><p class=\"caption\" style=\"width:75px\">This is Matz, Ruby's creator</p></div>",
      @controller.filter_text('<typo:flickr img="31366117"/>',
        [:macropre,:macropost],
        'flickr-user' => 'scott@sigkill.org')

    # Test with caption=""
    assert_equal "<div style=\"\" class=\"flickrplugin\"><a href=\"http://www.flickr.com/photo_zoom.gne?id=31366117&size=sq\"><img src=\"http://photos23.flickr.com/31366117_b1a791d68e_s.jpg\" width=\"75\" height=\"75\" alt=\"Matz\" title=\"Matz\"/></a></div>",
      @controller.filter_text('<typo:flickr img="31366117" caption=""/>',
        [:macropre,:macropost],
        'flickr-user' => 'scott@sigkill.org')
  end

  def test_sparkline
    tag = @controller.filter_text('<typo:sparkline foo="bar"/>',[:macropre,:macropost])
    # url_for returns query params in hash order, which isn't stable, so we can't just compare
    # with a static string.  Yuck.
    assert tag =~ %r{^<img  src="http://test.host/plugins/filters/sparkline/plot\?(data=|foo=bar|&)+"/>$}

    assert_equal "<img  title=\"aaa\" src=\"http://test.host/plugins/filters/sparkline/plot?data=\"/>",
      @controller.filter_text('<typo:sparkline title="aaa"/>',[:macropre,:macropost])

    assert_equal "<img  style=\"bbb\" src=\"http://test.host/plugins/filters/sparkline/plot?data=\"/>",
      @controller.filter_text('<typo:sparkline style="bbb"/>',[:macropre,:macropost])

    assert_equal "<img  alt=\"ccc\" src=\"http://test.host/plugins/filters/sparkline/plot?data=\"/>",
      @controller.filter_text('<typo:sparkline alt="ccc"/>',[:macropre,:macropost])
      
    assert_equal "<img  src=\"http://test.host/plugins/filters/sparkline/plot?data=1%2C2%2C3%2C4&type=smooth\"/>",
      @controller.filter_text('<typo:sparkline type="smooth" data="1 2 3 4"/>',[:macropre,:macropost])
      
    assert_equal "<img  src=\"http://test.host/plugins/filters/sparkline/plot?data=1%2C2%2C3%2C4%2C5%2C6\"/>",
      @controller.filter_text('<typo:sparkline>1 2 3 4 5 6</typo:sparkline>',[:macropre,:macropost])
  end
      
  def test_sparkline_plot
    get 'public_action', :filter => 'sparkline', :public_action => 'plot', :data => '1,2,3'
    assert_response :success
    
    get 'public_action', :filter => 'sparkline', :public_action => 'plot2', :data => '1,2,3'
    assert_response :missing
  end
  
  def test_code
    assert_equal %{<div class="typocode"><pre><code class="typocode_default ">foo-code</code></pre></div>},
      @controller.filter_text('<typo:code>foo-code</typo:code>',[:macropre,:macropost])

    assert_equal %{<div class="typocode"><pre><code class="typocode_ruby "><span class="ident">foo</span><span class="punct">-</span><span class="ident">code</span></code></pre></div>},
      @controller.filter_text('<typo:code lang="ruby">foo-code</typo:code>',[:macropre,:macropost])

    assert_equal %{<div class="typocode"><pre><code class="typocode_ruby "><span class="ident">foo</span><span class="punct">-</span><span class="ident">code</span></code></pre></div> blah blah <div class="typocode"><pre><code class="typocode_xml ">zzz</code></pre></div>},
      @controller.filter_text('<typo:code lang="ruby">foo-code</typo:code> blah blah <typo:code lang="xml">zzz</typo:code>',[:macropre,:macropost])
  end
  
  def test_code_multiline
    assert_equal %{\n<div class="typocode"><pre><code class="typocode_ruby "><span class="keyword">class </span><span class="class">Foo</span>\n  <span class="keyword">def </span><span class="method">bar</span>\n    <span class="attribute">@a</span> <span class="punct">=</span> <span class="punct">&quot;</span><span class="string">zzz</span><span class="punct">&quot;</span>\n  <span class="keyword">end</span>\n<span class="keyword">end</span></code></pre></div>\n},
      @controller.filter_text(%{
<typo:code lang="ruby">
class Foo
  def bar
    @a = "zzz"
  end
end
</typo:code>
},[:macropre,:macropost])
  end

  def test_named_filter
    assert_equal '<p><em>&#8220;foo&#8221;</em></p>', 
      @controller.filter_text_by_name('*"foo"*','markdown smartypants')
  end
end

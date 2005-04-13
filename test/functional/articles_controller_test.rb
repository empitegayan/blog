require File.dirname(__FILE__) + '/../test_helper'
require 'articles_controller'

# Re-raise errors caught by the controller.
class ArticlesController; def rescue_action(e) raise e end; end

class ArticlesControllerTest < Test::Unit::TestCase
  fixtures :articles, :categories, :settings

  def setup
    @controller = ArticlesController.new
    @request, @response = ActionController::TestRequest.new, ActionController::TestResponse.new

    # Complete settings fixtures
  end

  # Category subpages
  def test_category
    get :category, :id => "Software"
    assert_success
    assert_rendered_file "index"
  end
  
  # Main index
  def test_index
    get :index
    assert_success
    assert_rendered_file "index"
  end
  
  # Posts for given day
  def test_find_by_date
    get :find_by_date, :year => 2005, :month => 01, :day => 01
    assert_success
    assert_rendered_file "index"
  end
  
  def test_no_settings
    Setting.find_all.each { |setting|
      setting.destroy
    }
    
    assert Setting.find_all.empty?
    
    # save this because the AWS stuff needs it later
    old_config = $config
    $config = nil
    
    get :index
    
    assert_redirect
    assert_redirected_to :controller => "settings", :action => "install"
    
    # reassing so the AWS stuff doesn't barf
    $config = old_config
  end
  
  def test_no_users_exist
    User.find_all.each { |user|
      user.destroy
    }
  
    assert User.find_all.empty?
    
    get :index
    assert_redirect
    assert_redirected_to :controller => "accounts", :action => "signup"
  end
  
  def Xtest_setup_after_signup
    User.find_all.each { |user|
      user.destroy
    }
    
    assert User.find_all.empty?
    
    post :signup, :user => { :login => "newbob", :password => "newpassword", :password_confirmation => "newpassword" }
    assert_session_has :user
    
    assert_redirect
    assert_redirected_to :controller => "settings", :action => "install"
  end
  
  def test_disable_signup_after_user_exists
    # FIXME: write
  end
end

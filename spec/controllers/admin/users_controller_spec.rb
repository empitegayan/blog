require File.dirname(__FILE__) + '/../../../test/test_helper'
require File.dirname(__FILE__) + '/../../spec_helper'
require 'admin/users_controller'

# Re-raise errors caught by the controller.
class Admin::UsersController; def rescue_action(e) raise e end; end

describe Admin::UsersController, "rough port of the old functional test" do
  integrate_views

  before(:each) do
    request.session = { :user => users(:tobi).id }
  end

  def test_index
    get :index
    assert_template 'index'
    assert_template_has 'users'
  end

  def test_list
    get :list
    assert_template 'index'
    assert_template_has 'users'
  end

  def test_new
    get :new
    assert_template 'new'

    post :new, :user => { :login => 'errand', :email => 'corey@test.com',
      :password => 'testpass', :password_confirmation => 'testpass', :profile_id => 1 }
    assert_response :redirect, :action => 'index'
    follow_redirect
    assert_template 'index'
  end

  def test_edit
    user_id = users(:tobi).id
    get :edit, :id => user_id
    assert_template 'edit'
    assert_valid assigns(:user)

    post :edit, :id => user_id, :user => { :login => 'errand',
      :email => 'corey@test.com', :password => 'testpass',
      :password_confirmation => 'testpass' }
    assert_response :redirect, :action => 'index'
    follow_redirect
    assert_template 'index'
  end

  def test_destroy
    user_count = User.count
    get :destroy, :id => users(:bob).id
    assert_template 'destroy'
    assert_valid assigns(:user)

    assert_equal user_count, User.count
    post :destroy, :id => users(:bob).id
    assert_response :redirect, :action => 'list'
    follow_redirect
    assert_template 'index'
    assert_equal user_count - 1, User.count
  end
end

require File.expand_path('test_helper', File.dirname(__FILE__))

class User
  extend ActiveModel::Naming
end

class AccountsController < InheritedResources::Base
end

class UsersController < AccountsController
  respond_to :html, :xml
  respond_to :js, :only => [:create, :update, :destroy]
  attr_reader :scopes_applied

  def self.name
    "UsersController"
  end

  protected

  def apply_scopes(object)
    @scopes_applied = true
    object
  end
end

module UserTestHelper
  def setup
    @controller_class    = Class.new(UsersController)
    @controller          = @controller_class.new
    @controller.request  = @request = new_request
    @controller.response = @response = new_response
    @controller.stubs(:user_url).returns("/")
  end

  protected

  def new_request
    return ActionController::TestRequest.new if ActionPack::VERSION::MAJOR < 5
    if ActionPack::VERSION::MAJOR == 5 && ActionPack::VERSION::MINOR < 1
      ActionController::TestRequest.new({}, ActionController::TestSession.new)
    else
      ActionController::TestRequest.create(UsersController)
    end
  end

  def new_response
    ActionPack::VERSION::MAJOR < 5 ? ActionController::TestResponse.new : ActionDispatch::TestResponse.create
  end

  def mock_user(expectations={})
    @mock_user ||= begin
      user = mock(expectations.except(:errors))
      user.stubs(:class).returns(User)
      user.stubs(:errors).returns(expectations.fetch(:errors, {}))
      user.singleton_class.class_eval do
        def method_missing(symbol, *arguments, &block)
          raise NoMethodError.new('this is expected by Array#flatten') if symbol == :to_ary
          super
        end
      end
      user
    end
  end
end

class IndexActionBaseTest < ActionController::TestCase
  include UserTestHelper

  def test_expose_all_users_as_instance_variable
    User.expects(:scoped).returns([mock_user])
    get :index
    assert_equal [mock_user], assigns(:users)
  end

  def test_apply_scopes_if_method_is_available
    User.expects(:scoped).returns([mock_user])
    get :index
    assert @controller.scopes_applied
  end

  def test_controller_should_render_index
    User.stubs(:scoped).returns([mock_user])
    get :index
    assert_response :success
    assert_equal 'Index HTML', @response.body.strip
  end

  def test_render_all_users_as_xml_when_mime_type_is_xml
    @request.accept = 'application/xml'
    User.expects(:scoped).returns(collection = [mock_user])
    collection.expects(:to_xml).returns('Generated XML')
    get :index
    assert_response :success
    assert_equal 'Generated XML', @response.body
  end

  def test_scoped_is_called_only_when_available
    User.stubs(:all).returns([mock_user])
    get :index
    assert_equal Array, assigns(:users).class
  end
end

class ShowActionBaseTest < ActionController::TestCase
  include UserTestHelper

  def test_expose_the_requested_user
    User.expects(:find).with('42').returns(mock_user)
    get :show, request_params(:id => '42')
    assert_equal mock_user, assigns(:user)
  end

  def test_controller_should_render_show
    User.stubs(:find).returns(mock_user)
    get :show
    assert_response :success
    assert_equal 'Show HTML', @response.body.strip
  end

  def test_render_exposed_user_as_xml_when_mime_type_is_xml
    @request.accept = 'application/xml'
    User.expects(:find).with('42').returns(mock_user)
    mock_user.expects(:to_xml).returns("Generated XML")

    get :show, request_params(:id => '42')
    assert_response :success
    assert_equal 'Generated XML', @response.body
  end
end

class NewActionBaseTest < ActionController::TestCase
  include UserTestHelper

  def test_expose_a_new_user
    User.expects(:new).returns(mock_user)
    get :new
    assert_equal mock_user, assigns(:user)
  end

  def test_controller_should_render_new
    User.stubs(:new).returns(mock_user)
    get :new
    assert_response :success
    assert_equal 'New HTML', @response.body.strip
  end

  def test_render_exposed_a_new_user_as_xml_when_mime_type_is_xml
    @request.accept = 'application/xml'
    User.expects(:new).returns(mock_user)
    mock_user.expects(:to_xml).returns("Generated XML")

    get :new
    assert_response :success
    assert_equal 'Generated XML', @response.body
  end
end

class EditActionBaseTest < ActionController::TestCase
  include UserTestHelper

  def test_expose_the_requested_user
    User.expects(:find).with('42').returns(mock_user)
    get :edit, request_params(:id => '42')
    assert_response :success
    assert_equal mock_user, assigns(:user)
  end

  def test_controller_should_render_edit
    User.stubs(:find).returns(mock_user)
    get :edit
    assert_response :success
    assert_equal 'Edit HTML', @response.body.strip
  end
end

class CreateActionBaseTest < ActionController::TestCase
  include UserTestHelper

  def test_expose_a_newly_create_user_when_saved_with_success
    User.expects(:new).with({'these' => 'params'}).returns(mock_user(:save => true))
    post :create, request_params(:user => {:these => 'params'})
    assert_equal mock_user, assigns(:user)
  end

  def test_expose_a_newly_create_user_when_saved_with_success_and_role_setted
    @controller.class.send(:with_role, :admin)
    User.expects(:new).with({'these' => 'params'}, {:as => :admin}).returns(mock_user(:save => true))
    post :create, request_params(:user => {:these => 'params'})
    assert_equal mock_user, assigns(:user)
  end

  def test_expose_a_newly_create_user_when_saved_with_success_and_without_protection_setted
    @controller.class.send(:without_protection, true)
    User.expects(:new).with({'these' => 'params'}, {:without_protection => true}).returns(mock_user(:save => true))
    post :create, request_params(:user => {:these => 'params'})
    assert_equal mock_user, assigns(:user)
  end

  def test_redirect_to_the_created_user
    User.stubs(:new).returns(mock_user(:save => true))
    @controller.expects(:resource_url).returns('http://test.host/')
    post :create, format: :html
    assert_redirected_to 'http://test.host/'
  end

  def test_show_flash_message_when_success
    User.stubs(:new).returns(mock_user(:save => true))
    post :create
    assert_equal flash[:notice], 'User was successfully created.'
  end

  def test_show_flash_message_with_javascript_request_when_success
    User.stubs(:new).returns(mock_user(:save => true))
    post :create, :format => :js
    assert_equal flash[:notice], 'User was successfully created.'
  end

  def test_render_new_template_when_user_cannot_be_saved
    User.stubs(:new).returns(mock_user(:save => false, :errors => {:some => :error}))
    post :create
    assert_response :success
    assert_equal "New HTML", @response.body.strip
  end

  def test_dont_show_flash_message_when_user_cannot_be_saved
    User.stubs(:new).returns(mock_user(:save => false, :errors => {:some => :error}))
    post :create
    assert flash.empty?
  end
end

class UpdateActionBaseTest < ActionController::TestCase
  include UserTestHelper

  def test_update_the_requested_object
    User.expects(:find).with('42').returns(mock_user)
    mock_user.expects(:update_attributes).with({'these' => 'params'}).returns(true)
    put :update, request_params(:id => '42', :user => {:these => 'params'})
    assert_equal mock_user, assigns(:user)
  end

  def test_update_the_requested_object_when_setted_role
    @controller.class.send(:with_role, :admin)
    User.expects(:find).with('42').returns(mock_user)
    mock_user.expects(:update_attributes).with({'these' => 'params'}, {:as => :admin}).returns(true)
    put :update, request_params(:id => '42', :user => {:these => 'params'})
    assert_equal mock_user, assigns(:user)
  end

  def test_update_the_requested_object_when_setted_without_protection
    @controller.class.send(:without_protection, true)
    User.expects(:find).with('42').returns(mock_user)
    mock_user.expects(:update_attributes).with({'these' => 'params'}, {:without_protection => true}).returns(true)
    put :update, request_params(:id => '42', :user => {:these => 'params'})
    assert_equal mock_user, assigns(:user)
  end

  def test_redirect_to_the_updated_user
    User.stubs(:find).returns(mock_user(:update_attributes => true))
    @controller.expects(:resource_url).returns('http://test.host/')
    put :update
    assert_redirected_to 'http://test.host/'
  end

  def test_redirect_to_the_users_list_if_show_undefined
    @controller.class.send(:actions, :all, :except => :show)
    User.stubs(:find).returns(mock_user(:update_attributes => true))
    @controller.expects(:collection_url).returns('http://test.host/')
    put :update
    assert_redirected_to 'http://test.host/'
  end

  def test_show_flash_message_when_success
    User.stubs(:find).returns(mock_user(:update_attributes => true))
    put :update
    assert_equal flash[:notice], 'User was successfully updated.'
  end

  def test_show_flash_message_with_javascript_request_when_success
    User.stubs(:find).returns(mock_user(:update_attributes => true))
    post :update, :format => :js
    assert_equal flash[:notice], 'User was successfully updated.'
  end

  def test_render_edit_template_when_user_cannot_be_saved
    User.stubs(:find).returns(mock_user(:update_attributes => false, :errors => {:some => :error}))
    put :update
    assert_response :success
    assert_equal "Edit HTML", @response.body.strip
  end

  def test_dont_show_flash_message_when_user_cannot_be_saved
    User.stubs(:find).returns(mock_user(:update_attributes => false, :errors => {:some => :error}))
    put :update
    assert flash.empty?
  end
end

class DestroyActionBaseTest < ActionController::TestCase
  include UserTestHelper

  def test_the_requested_user_is_destroyed
    User.expects(:find).with('42').returns(mock_user)
    mock_user.expects(:destroy).returns(true)
    delete :destroy, request_params(:id => '42')
    assert_equal mock_user, assigns(:user)
  end

  def test_show_flash_message_when_user_can_be_deleted
    User.stubs(:find).returns(mock_user(:destroy => true))
    delete :destroy
    assert_equal flash[:notice], 'User was successfully destroyed.'
  end

  def test_show_flash_message_with_javascript_request_when_user_can_be_deleted
    User.stubs(:find).returns(mock_user(:destroy => true))
    delete :destroy, :format => :js
    assert_equal flash[:notice], 'User was successfully destroyed.'
  end

  def test_show_flash_message_when_user_cannot_be_deleted
    User.stubs(:find).returns(mock_user(:destroy => false, :errors => { :fail => true }))
    delete :destroy
    assert_equal flash[:alert], 'User could not be destroyed.'
  end

  def test_show_flash_message_with_javascript_request_when_user_cannot_be_deleted
    User.stubs(:find).returns(mock_user(:destroy => false, :errors => { :fail => true }))
    delete :destroy, :format => :js
    assert_equal flash[:alert], 'User could not be destroyed.'
  end

  def test_redirects_to_users_list
    User.stubs(:find).returns(mock_user(:destroy => true))
    @controller.expects(:collection_url).returns('http://test.host/')
    delete :destroy
    assert_redirected_to 'http://test.host/'
  end

  def test_redirects_to_the_resource_if_cannot_be_destroyed
    User.stubs(:find).returns(mock_user(:destroy => false))
    @controller.expects(:collection_url).returns('http://test.host/')
    delete :destroy
    assert_redirected_to 'http://test.host/'
  end
end


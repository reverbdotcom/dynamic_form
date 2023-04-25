require 'test_helper'
require "action_view/test_case"

class DynamicFormTest < ActionView::TestCase
  tests ActionView::Helpers::DynamicForm

  def form_for(*)
    @output_buffer = super
  end

  silence_warnings do
    class Post < Struct.new(:title, :author_name, :body, :secret, :written_on)
      extend ActiveModel::Naming
      include ActiveModel::Conversion
    end

    class User < Struct.new(:email)
      extend ActiveModel::Naming
      include ActiveModel::Conversion
    end

    class Column < Struct.new(:type, :name, :human_name)
      extend ActiveModel::Naming
      include ActiveModel::Conversion
    end
  end

  class DirtyPost
    class Errors
      def empty?
        false
      end

      def count
        1
      end

      def full_messages
        ["Author name can't be <em>empty</em>"]
      end

      def [](field)
        ["can't be <em>empty</em>"]
      end
    end

    def errors
      Errors.new
    end
  end

  def setup_post
    @post = Post.new
    def @post.errors
      Class.new {
        def [](field)
          case field.to_s
          when "author_name"
            ["can't be empty"]
          when "body"
            ['foo']
          else
            []
          end
        end
        def empty?() false end
        def count() 1 end
        def full_messages() [ "Author name can't be empty" ] end
      }.new
    end

    def @post.persisted?() false end
    def @post.to_param() nil end

    def @post.column_for_attribute(attr_name)
      Post.content_columns.select { |column| column.name == attr_name }.first
    end

    silence_warnings do
      def Post.content_columns() [ Column.new(:string, "title", "Title"), Column.new(:text, "body", "Body") ] end
    end

    @post.title       = "Hello World"
    @post.author_name = ""
    @post.body        = "Back to the hill and over it again!"
    @post.secret = 1
    @post.written_on  = Date.new(2004, 6, 15)
  end

  def setup_user
    @user = User.new
    def @user.errors
      Class.new {
        def [](field) field == "email" ? ['nonempty'] : [] end
        def empty?() false end
        def count() 1 end
        def full_messages() [ "User email can't be empty" ] end
      }.new
    end

    def @user.new_record?() true end
    def @user.to_param() nil end

    def @user.column_for_attribute(attr_name)
      User.content_columns.select { |column| column.name == attr_name }.first
    end

    silence_warnings do
      def User.content_columns() [ Column.new(:string, "email", "Email") ] end
    end

    @user.email = ""
  end

  def protect_against_forgery?
    @protect_against_forgery ? true : false
  end
  attr_accessor :request_forgery_protection_token, :form_authenticity_token

  def setup
    super
    setup_post
    setup_user

    @response = ActionDispatch::TestResponse.new
  end

  def url_for(options)
    options = options.symbolize_keys
    [options[:action], options[:id].to_param].compact.join('/')
  end

  def test_error_messages_for_escapes_html
    @dirty_post = DirtyPost.new
    assert_dom_equal %(<div class="error_explanation" id="error_explanation"><h2>1 error prohibited this dirty post from being saved</h2><p>There were problems with the following fields:</p><ul><li>Author name can't be &lt;em&gt;empty&lt;/em&gt;</li></ul></div>), error_messages_for("dirty_post")
  end

  def test_error_messages_for_handles_nil
    assert_equal "", error_messages_for("notthere")
  end

  def test_error_message_on_escapes_html
    @dirty_post = DirtyPost.new
    assert_dom_equal "<div class=\"formError\">can't be &lt;em&gt;empty&lt;/em&gt;</div>", error_message_on(:dirty_post, :author_name)
  end

  def test_error_message_on_handles_nil
    assert_equal "", error_message_on("notthere", "notthere")
  end

  def test_error_message_on
    assert_dom_equal "<div class=\"formError\">can't be empty</div>", error_message_on(:post, :author_name)
  end

  def test_error_message_on_no_instance_variable
    other_post = @post
    assert_dom_equal "<div class=\"formError\">can't be empty</div>", error_message_on(other_post, :author_name)
  end

  def test_error_message_on_with_options_hash
    assert_dom_equal "<div class=\"differentError\">beforecan't be emptyafter</div>", error_message_on(:post, :author_name, :css_class => 'differentError', :prepend_text => 'before', :append_text => 'after')
  end

  def test_error_message_on_with_tag_option_in_options_hash
    assert_dom_equal "<span class=\"differentError\">beforecan't be emptyafter</span>", error_message_on(:post, :author_name, :html_tag => "span", :css_class => 'differentError', :prepend_text => 'before', :append_text => 'after')
  end

  def test_error_message_on_handles_empty_errors
    assert_equal "", error_message_on(@post, :tag)
  end

  def test_error_messages_for_many_objects
    assert_dom_equal %(<div class="error_explanation" id="error_explanation"><h2>2 errors prohibited this post from being saved</h2><p>There were problems with the following fields:</p><ul><li>Author name can't be empty</li><li>User email can't be empty</li></ul></div>), error_messages_for("post", "user")

    # reverse the order, error order changes and so does the title
    assert_dom_equal %(<div class="error_explanation" id="error_explanation"><h2>2 errors prohibited this user from being saved</h2><p>There were problems with the following fields:</p><ul><li>User email can't be empty</li><li>Author name can't be empty</li></ul></div>), error_messages_for("user", "post")

    # add the default to put post back in the title
    assert_dom_equal %(<div class="error_explanation" id="error_explanation"><h2>2 errors prohibited this post from being saved</h2><p>There were problems with the following fields:</p><ul><li>User email can't be empty</li><li>Author name can't be empty</li></ul></div>), error_messages_for("user", "post", :object_name => "post")

    # symbols work as well
    assert_dom_equal %(<div class="error_explanation" id="error_explanation"><h2>2 errors prohibited this post from being saved</h2><p>There were problems with the following fields:</p><ul><li>User email can't be empty</li><li>Author name can't be empty</li></ul></div>), error_messages_for(:user, :post, :object_name => :post)

    # any default works too
    assert_dom_equal %(<div class="error_explanation" id="error_explanation"><h2>2 errors prohibited this monkey from being saved</h2><p>There were problems with the following fields:</p><ul><li>User email can't be empty</li><li>Author name can't be empty</li></ul></div>), error_messages_for(:user, :post, :object_name => "monkey")

    # should space object name
    assert_dom_equal %(<div class="error_explanation" id="error_explanation"><h2>2 errors prohibited this chunky bacon from being saved</h2><p>There were problems with the following fields:</p><ul><li>User email can't be empty</li><li>Author name can't be empty</li></ul></div>), error_messages_for(:user, :post, :object_name => "chunky_bacon")

    # hide header and explanation messages with nil or empty string
    assert_dom_equal %(<div class="error_explanation" id="error_explanation"><ul><li>User email can't be empty</li><li>Author name can't be empty</li></ul></div>), error_messages_for(:user, :post, :header_message => nil, :message => "")

    # override header and explanation messages
    header_message = "Yikes! Some errors"
    message = "Please fix the following fields and resubmit:"
    assert_dom_equal %(<div class="error_explanation" id="error_explanation"><h2>#{header_message}</h2><p>#{message}</p><ul><li>User email can't be empty</li><li>Author name can't be empty</li></ul></div>), error_messages_for(:user, :post, :header_message => header_message, :message => message)
  end

  def test_error_messages_for_non_instance_variable
    actual_user = @user
    actual_post = @post
    @user = nil
    @post = nil

  #explicitly set object
    assert_dom_equal %(<div class="error_explanation" id="error_explanation"><h2>1 error prohibited this post from being saved</h2><p>There were problems with the following fields:</p><ul><li>Author name can't be empty</li></ul></div>), error_messages_for("post", :object => actual_post)

  #multiple objects
    assert_dom_equal %(<div class="error_explanation" id="error_explanation"><h2>2 errors prohibited this user from being saved</h2><p>There were problems with the following fields:</p><ul><li>User email can't be empty</li><li>Author name can't be empty</li></ul></div>), error_messages_for("user", "post", :object => [actual_user, actual_post])

  #nil object
    assert_equal '', error_messages_for('user', :object => nil)
  end

  def test_error_messages_for_model_objects
    error = error_messages_for(@post)
    assert_dom_equal %(<div class="error_explanation" id="error_explanation"><h2>1 error prohibited this post from being saved</h2><p>There were problems with the following fields:</p><ul><li>Author name can't be empty</li></ul></div>),
      error

    error = error_messages_for(@user, @post)
    assert_dom_equal %(<div class="error_explanation" id="error_explanation"><h2>2 errors prohibited this user from being saved</h2><p>There were problems with the following fields:</p><ul><li>User email can't be empty</li><li>Author name can't be empty</li></ul></div>),
      error
  end

  def test_error_messages_without_prefixed_attribute_name
    error = error_messages_for(@post)
    assert_dom_equal %(<div class="error_explanation" id="error_explanation"><h2>1 error prohibited this post from being saved</h2><p>There were problems with the following fields:</p><ul><li>Author name can't be empty</li></ul></div>),
      error
  end
end

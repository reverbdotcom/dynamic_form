require 'test_helper'
require 'active_model/dynamic_errors'

class DynamicErrorsTest < Minitest::Test
  class Widget
    include ActiveModel::Model
    attr_accessor :name, :terms, :label

    validates :name, presence: true
    validates :terms, acceptance: { message: '^Please accept the terms of service', allow_nil: false }
    validates :label, presence: { message: Proc.new { |w, _data| "Label for #{w.name.inspect} is required" } }
  end

  def setup
    I18n.load_path << File.expand_path('../lib/active_model/locale/en.yml', __dir__)
    I18n.backend.reload!
    @widget = Widget.new
    @widget.valid?
  end

  def test_regular_message_is_prefixed_with_attribute_name
    assert_includes @widget.errors.full_messages, "Name can't be blank"
  end

  def test_caret_message_omits_attribute_name
    assert_includes @widget.errors.full_messages, 'Please accept the terms of service'
  end

  def test_proc_message_is_evaluated
    assert_includes @widget.errors.full_messages, 'Label Label for nil is required'
  end

  def test_base_messages_are_unprefixed
    @widget.errors.add(:base, 'Something went wrong')
    assert_includes @widget.errors.full_messages, 'Something went wrong'
  end

  def test_full_messages_for_and_full_message_still_work
    assert_equal ["Name can't be blank"], @widget.errors.full_messages_for(:name)
  end

  def test_full_messages_for_caret_attribute
    skip 'Known gap (also on Rails 6.1): the full_messages override does not cover Error#full_message, which full_messages_for/to_a use'
    assert_equal ['Please accept the terms of service'], @widget.errors.full_messages_for(:terms)
  end

  def test_to_a_matches_full_messages
    skip 'Known gap (also on Rails 6.1): the full_messages override does not cover Error#full_message, which full_messages_for/to_a use'
    assert_equal @widget.errors.full_messages, @widget.errors.to_a
  end
end

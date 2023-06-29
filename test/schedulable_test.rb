require 'test_helper'
require 'database_cleaner'

class SchedulableTest < ActiveSupport::TestCase
  DatabaseCleaner.clean_with(:truncation)
  DatabaseCleaner.start

  event = FactoryBot.create(:event)
  puts event.name

  test "truth" do
    assert_kind_of Module, Schedulable
  end
end

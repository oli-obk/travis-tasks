ENV['RAILS_ENV'] = ENV['ENV'] = 'test'

RSpec.configure do |c|
  c.before(:each) { Time.now.utc.tap { | now| Time.stubs(:now).returns(now) } }
end

require 'travis/task'
require 'travis/addons'
require 'travis/support/testing/webmock'
require 'travis/testing'
require 'travis/config'
require 'payloads'

ActionMailer::Base.delivery_method = :test

require 'mocha'
require 'gh'

include Mocha::API

RSpec.configure do |c|
  c.mock_with :mocha
  c.alias_example_to :fit, :focused => true
  c.filter_run :focused => true
  c.run_all_when_everything_filtered = true
  c.backtrace_clean_patterns.clear

  c.include Travis::Support::Testing::Webmock

  c.before :each do
    Travis.config.oauth2 ||= {}
    Travis.config.oauth2.scope = 'public_repo,user'
    GH.reset
  end
end

RSpec::Matchers.define :deliver_to do |expected|
  match do |email|
    actual = (email.to || []).map(&:to_s)

    description { "be delivered to #{expected.inspect}" }
    failure_message_for_should { "expected #{email.inspect} to deliver to #{expected.inspect}, but it delivered to #{actual.inspect}" }
    failure_message_for_should_not { "expected #{email.inspect} not to deliver to #{expected.inspect}, but it did" }

    actual.sort == Array(expected).sort
  end
end

RSpec::Matchers.define :include_lines do |lines|
  match do |text|
    lines   = lines.split("\n").map { |line| line.strip }
    missing = lines.reject { |line| text.include?(line) }

    failure_message_for_should do
      "expected\n\n#{text}\n\nto include the lines\n\n#{lines.join("\n")}\n\nbut could not find the lines\n\n#{missing.join("\n")}"
    end

    missing.empty?
  end
end

module Kernel
  def capture_stdout
    out = StringIO.new
    $stdout = out
    yield
    return out.string
  ensure
    $stdout = STDOUT
  end
end

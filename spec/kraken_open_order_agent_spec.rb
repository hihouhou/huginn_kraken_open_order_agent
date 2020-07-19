require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::KrakenOpenOrderAgent do
  before(:each) do
    @valid_options = Agents::KrakenOpenOrderAgent.new.default_options
    @checker = Agents::KrakenOpenOrderAgent.new(:name => "KrakenOpenOrderAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end

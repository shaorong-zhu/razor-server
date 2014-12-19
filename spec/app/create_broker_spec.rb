# -*- encoding: utf-8 -*-
require_relative '../spec_helper'
require_relative '../../app'

require 'pathname'

describe Razor::Command::CreateBroker do
  include Razor::Test::Commands

  let(:app) { Razor::App }

  before :each do
    authorize 'fred', 'dead'
  end

  context "/api/commands/create-broker" do
    before :each do
      header 'content-type', 'application/json'

      Razor.config['broker_path'] =
        (Pathname(__FILE__).dirname.parent + 'fixtures' + 'brokers').realpath.to_s
    end

    let :command_hash do
      { 'name'        => Faker::Commerce.product_name,
        'broker-type' => 'test'
      }
    end

    it_behaves_like "a command"

    def create_broker(params)
      command 'create-broker', params
      params
    end

    it "should reject bad JSON" do
      post '/api/commands/create-broker', '{"json": "not really..."'
      last_response.status.should == 400
      JSON.parse(last_response.body)["error"].should == 'unable to parse JSON'
    end

    ["foo", 100, 100.1, -100, true, false].map(&:to_json).each do |input|
      it "should reject non-object inputs (like: #{input.inspect})" do
        post '/api/commands/create-broker', input
        last_response.status.should == 400
      end
    end

    it "should fail if the named broker does not actually exist" do
      create_broker command_hash.merge 'broker-type' => 'no-such-broker-for-me'

      last_response.status.should == 404
      last_response.json['error'].should ==
        "broker-type must be the name of an existing broker type, but is 'no-such-broker-for-me'"
    end

    it "should fail cleanly if 'configuration' is a string" do
      command_hash['configuration'] = '{"arg1": "value1"}'
      create_broker command_hash

      last_response.status.should == 422
      last_response.json['error'].should == "configuration should be a object, but was actually a string"
    end
    # Successful creation
    it "should return 202, and the URL of the broker" do
      command = create_broker command_hash

      last_response.status.should == 202
      last_response.json?.should be_true
      last_response.json.keys.should =~ %w[name id spec]

      name = URI.escape(command['name'])
      last_response.json["id"].should =~ %r'/api/collections/brokers/#{name}\Z'
    end

    it "should create an broker record in the database" do
      command = create_broker command_hash

      Razor::Data::Broker[:name => command['name']].should be_an_instance_of Razor::Data::Broker
    end
    # Successful creation
    it "should return 202 when repeated with the same parameters" do
      command = create_broker command_hash
      command = create_broker command_hash

      last_response.status.should == 202
      last_response.json['id'].should =~ %r'/api/collections/brokers/#{URI.escape(command_hash['name'])}\Z'
    end
  end
end

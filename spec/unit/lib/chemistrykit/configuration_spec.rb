# Encoding: utf-8

require 'spec_helper'
require 'chemistrykit/configuration'

describe ChemistryKit::Configuration do

  VALID_BASE_URL = 'http://google.com'
  VALID_CONCURRENCY = 1
  VALID_RETRIES_ON_FAILURE = 1
  VALID_CONFIG_FILE = 'config.yaml'
  VALID_REPORTING_PATH = 'test_output'

  before(:each) do
    @valid_selenium_connect_hash = { log: 'evidence', host: 'localhost' }
    @valid_config_hash = {
      base_url: VALID_BASE_URL,
      concurrency: VALID_CONCURRENCY,
      selenium_connect: @valid_selenium_connect_hash,
      retries_on_failure: VALID_RETRIES_ON_FAILURE
    }
  end

  def validate_config(config)
    config.screenshot_on_fail.should eq false
    config.concurrency.should eq VALID_CONCURRENCY
    config.retries_on_failure.should eq VALID_RETRIES_ON_FAILURE
    config.base_url.should eq VALID_BASE_URL

    # reporting configurations
    config.reporting.path.should eq VALID_REPORTING_PATH

    # selenium connect configurations
    config.selenium_connect.should eq @valid_selenium_connect_hash

    # basic auth configurations

    # a/b testing configurations
  end

  it 'should initialize with sane defaults' do
    config = ChemistryKit::Configuration.new({})
    config.concurrency.should eq VALID_CONCURRENCY
    config.retries_on_failure.should eq VALID_RETRIES_ON_FAILURE
    config.reporting.path.should eq VALID_REPORTING_PATH
    config.selenium_connect.should eq({ log: VALID_REPORTING_PATH })
    config.basic_auth.should be_nil
    config.split_testing.should be_nil
  end

  it 'should initialize with a hash of configurations' do
    validate_config ChemistryKit::Configuration.new(@valid_config_hash)
  end

  it 'can be initialized staticlly with a yaml file' do
    yaml_file = File.join(Dir.pwd, 'spec', 'support', VALID_CONFIG_FILE)
    validate_config ChemistryKit::Configuration.initialize_with_yaml yaml_file
  end

  it 'should throw an exception for unsupported config variable' do
    expect do
      ChemistryKit::Configuration.new bad: 'config-value'
    end.to raise_error ArgumentError, 'The config key: "bad" is unknown!'
  end

  it 'selenium_connect log should default to the main log' do
    config =  ChemistryKit::Configuration.new({})
    config.selenium_connect.should eq({ log: VALID_REPORTING_PATH })
  end

  it 'mainlog should not overide selenium_connect log' do
    config =  ChemistryKit::Configuration.new selenium_connect: { log: 'sc-log' }
    config.selenium_connect.should eq({ log: 'sc-log' })
  end

  it 'should allow pass through of sauce options' do
    config =  ChemistryKit::Configuration.new selenium_connect: { log: 'sc-log', sauce_opts: { job_name: 'test' } }
    config.selenium_connect.should eq log: 'sc-log', sauce_opts: { job_name: 'test' }
  end

  it 'should return the basic auth object if it is set' do
    config =  ChemistryKit::Configuration.new basic_auth: { username: 'user' }
    config.basic_auth.should be_an_instance_of ChemistryKit::Config::BasicAuth
    config.basic_auth.username.should eq 'user'
  end

  it 'should pass the base url to the auth object' do
    yaml_file = File.join(Dir.pwd, 'spec', 'support', VALID_CONFIG_FILE)
    config = ChemistryKit::Configuration.initialize_with_yaml yaml_file
    config.basic_auth.http_url.should eq 'http://user:pass@google.com/basic'
  end

  it 'should return the split testing object if it is set' do
    yaml_file = File.join(Dir.pwd, 'spec', 'support', VALID_CONFIG_FILE)
    config = ChemistryKit::Configuration.initialize_with_yaml yaml_file
    config.split_testing.should be_an_instance_of ChemistryKit::Config::SplitTesting
    config.split_testing.base_url.should eq VALID_BASE_URL
  end
end

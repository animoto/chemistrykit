# Encoding: utf-8

require_relative 'selenium_connect/job'
require 'selenium/server'
require_relative 'selenium_connect/configuration'
#require 'sauce/sauce_facade'
require_relative 'selenium_connect/report/report_factory'

# Selenium Connect main module
class SeleniumConnect

  attr_reader :config

  # initializes and returns a new SeleniumConnect object
  def self.start(config)
    report_factory = SeleniumConnect::Report::ReportFactory.new
    new config, report_factory
  end

  def initialize(config, report_factory)
    raise ArgumentError, 'Instance of SeleniumConnect::Configuration expected.' unless config.is_a? SeleniumConnect::Configuration
    @config         = config
    @report_factory = report_factory
    server_start
  end

  def create_job(opts = {})
    SeleniumConnect::Job.new @config, @report_factory
  end

  def finish
    @server.stop unless @server.nil?
    # returning empty report for now
    @report_factory.build :main, {}
  end

  private

  def server_start
    if @config.host == 'localhost'
      root_path =  File.dirname(File.expand_path(__FILE__))
      jar = File.join(root_path, 'bin','selenium-server-standalone-3.5.2.jar')

      @server = Selenium::Server.new(jar,
                                     :background => true, :timeout => 10)
      @server << "-Dwebdriver.chrome.driver=#{File.join(root_path, 'bin','chromedriver')}"
      @server << "-Dwebdriver.gecko.driver=#{File.join(root_path, 'bin','geckodriver')}"
      if config.log
        @server.log  = File.join(Dir.getwd, config.log, 'server.log')
        @server << "-Dwebdriver.chrome.logfile=#{File.join(Dir.getwd, config.log, 'chrome.log')}"
        @server << "-Dwebdriver.gecko.logfile=#{File.join(Dir.getwd, config.log, 'firefox.log')}"
      end
      @server.start
    else
      @server = nil
    end
  end
end

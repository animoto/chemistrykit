# Encoding: utf-8

require_relative 'runners/firefox'
require_relative 'runners/ie'
require_relative 'runners/chrome'
require_relative 'runners/safari'
require_relative 'runners/phantomjs'
require_relative 'runners/no_browser'
#require_relative 'runners/ios'
#require_relative 'runners/saucelabs'
#require_relative 'runners/android'
#require_relative 'runners/testdroid'
#require_relative 'runners/appium_lib'
require_relative 'runners/browserstack'

# selenium connect
class SeleniumConnect
  # Initializes the driver
  class Runner
    attr_reader :driver, :config

    def initialize(config)
      @config = config
      @driver = init_driver
    end

    private

    def set_server_url
      if config.port.nil?
        "http://#{config.host}/wd/hub"
      else
        "http://#{config.host}:#{config.port}/wd/hub"
      end
    end
    driver = nil

    def init_driver
     if config.host == 'browserstack'
        driver = BrowserStack.new(config).launch
      else
        driver = Selenium::WebDriver.for(
          :remote,
          url: set_server_url,
          desired_capabilities: get_browser
        )
      end
      driver
    end

    def get_browser
      browser = browsers.find { |found_browser| found_browser.match? }
      browser.launch
    end

    def browsers
      firefox     = Firefox.new(config)
      ie          = InternetExplorer.new(config)
      chrome      = Chrome.new(config)
      safari      = Safari.new(config)
      phantomjs   = PhantomJS.new(config)
      no_browser  = NoBrowser.new(config)
      [firefox, ie, chrome, safari, phantomjs, no_browser]
    end

  end # Runner
end # SeleniumConnect

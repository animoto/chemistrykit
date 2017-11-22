# Encoding: utf-8
# selenium connect

require 'selenium/webdriver'
require 'selenium/webdriver/remote/http/persistent'


class SeleniumConnect
  # Runner
  class Runner
    # Browserstack runner
    class BrowserStack
      attr_reader :config

      def initialize(config)
        @config = config
      end

      def launch
        init_browser
      end

      private

      def init_browser
        config.browserstack_opts[:'browserstack.debug'] = 'true'
        config.browserstack_opts[:'browserstack.video'] = 'true'
        config.browserstack_opts[:resolution]           = '1920x1080'
        config.browserstack_opts[:'browserstack.idleTimeout'] = 300000
        config.browserstack_opts[:project] = 'TSW'
        config.browserstack_opts[:'browserstack.selenium_version'] = '3.5.2'
        if config.browserstack_opts[:tunnel]
          config.browserstack_opts[:'browserstack.local'] = true
        end

        [:os,
         :os_version,
         :browser,
         :browser_version
        ].each do |attr|
          config.browserstack_opts[attr] = config.send attr
        end

        config.browserstack_opts.delete(:chromeOptions) if config.browser = 'firefox'

        client = Selenium::WebDriver::Remote::Http::Persistent.new
        driver = Selenium::WebDriver.for(
          :remote,
          url: "http://#{config.browserstack_username}:#{config.browserstack_api_key}@hub.browserstack.com/wd/hub",
          desired_capabilities: config.browserstack_opts,
          http_client: client
        )
      end

    end # BrowserStack
  end # Runner
end # SeleniumConnect

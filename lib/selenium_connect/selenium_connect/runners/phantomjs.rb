# Encoding: utf-8

class SeleniumConnect
  # Runner
  class Runner
    # PhantomJS browser runner
    class PhantomJS
      attr_reader :config

      def initialize(config)
        @config = config
      end

      def match?
        config.browser == 'phantomjs'
      end

      def launch
        init_browser
      end

      private

      def get_executable_path
        current_dir_path = File.join(File.dirname(File.expand_path(__FILE__)))
        current_dir_path + '/../../../bin/phantomjs'
      end

      def config_browser
        executable_path = get_executable_path
        browser = Selenium::WebDriver::Remote::Capabilities.phantomjs
        browser['phantomjs.binary.path'] = executable_path
        browser
      end

      def init_browser
        config_browser
      end

    end # Chrome
  end # Runner
end # SeleniumConnect

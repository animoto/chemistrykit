# Encoding: utf-8

class SeleniumConnect
  # Runner
  class Runner
    # IE Browser Runner
    class InternetExplorer
      attr_reader :config

      def initialize(config)
        @config = config
      end

      def match?
        config.browser == 'ie'
      end

      def launch
        init_browser
      end

      private

      def init_browser
        config.browser.to_sym
      end

    end # InternetExplorer
  end # Runner
end # SeleniumConnect

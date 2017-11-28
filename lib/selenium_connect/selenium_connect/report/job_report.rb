# Encoding: utf-8

# selenium connect
class SeleniumConnect
  module Report
    # report for a specific job
    class JobReport

      attr_reader :data

      def initialize(data)
        @data = data
      end

    end
  end
end

# Encoding: utf-8

require 'rspec/core/formatters/base_formatter'

# An RSpec formatter for generating a useful failure summary
module ChemistryKit
  module RSpec
    class RetryFormatter < ::RSpec::Core::Formatters::BaseFormatter

      # rspec formatter methods we care about

      def initialize(output)
        super output
        @fails = []
      end

      def example_failed(example)
        @fails << example.example_group.file_path
      end

      def dump_summary(duration, example_count, failure_count, pending_count)
        return if failure_count == 0
        beakers = @fails.uniq

        ckit_cmd = "ckit brew -b #{beakers.join(' ')}"

        jenkins_url = ['http://ci.animoto.com',
                       '/job/test_selenium_web_configurable_job',
                       '/buildWithParameters?token=animoto',
                       "&params=-b+#{beakers.join('+')}"].join


        msg = <<-MSG.gsub(/^ {10}/, '')

          ####################
          Some beakers failed.
          ####################

          CKit command to rerun these beakers (from test repo root):
            #{ckit_cmd}

          Run Jenkins configurable job with these beakers (if test_selenium_web):
            #{jenkins_url}
        MSG
        output.puts msg
      end

    end
  end
end

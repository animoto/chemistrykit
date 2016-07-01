# Encoding: utf-8

require 'thor'
require 'rspec'
require 'rspec/retry'
require 'chemistrykit/cli/new'
require 'chemistrykit/cli/formula'
require 'chemistrykit/cli/beaker'
require 'chemistrykit/cli/helpers/formula_loader'
require 'chemistrykit/catalyst'
require 'chemistrykit/formula/base'
require 'chemistrykit/formula/formula_lab'
require 'chemistrykit/chemist/repository/csv_chemist_repository'
require 'selenium_connect'
require 'chemistrykit/configuration'
require 'chemistrykit/rspec/j_unit_formatter'
require 'chemistrykit/rspec/retry_formatter'

require 'rspec/core/formatters/html_formatter'
require 'chemistrykit/rspec/html_formatter'

require 'chemistrykit/reporting/html_report_assembler'
require 'chemistrykit/split_testing/provider_factory'

require 'allure-rspec'

require 'rubygems'
require 'logging'
require 'rspec/logging_helper'

require 'fileutils'
require 'rbconfig'

module ChemistryKit
  module CLI
    # Main Chemistry Kit CLI Class
    class CKitCLI < Thor

      register(ChemistryKit::CLI::New, 'new', 'new [NAME]', 'Creates a new ChemistryKit project')

      check_unknown_options!
      default_task :help

      desc 'brew', 'Run ChemistryKit'
      method_option :params, type: :hash
      method_option :tag, type: :array
      method_option :config, default: 'config.yaml', aliases: '-c', desc: 'Supply alternative config file.'
      method_option :beakers, aliases: '-b', type: :array
      method_option :retry, default: false, aliases: '-x', desc: 'How many times should a failing test be retried.'
      method_option :all, default: false, aliases: '-a', desc: 'Run every beaker.', type: :boolean

      def brew
        config = load_config options['config']
        # TODO: perhaps the params should be rolled into the available
        # config object injected into the system?
        pass_params if options['params']

        # TODO: expand this to allow for more overrides as needed
        config.retries_on_failure = options['retry'].to_i if options['retry']

        load_page_objects

        # get those beakers that should be executed
        beakers = options['beakers'] ? options['beakers'] : Dir.glob(File.join(Dir.getwd, 'beakers/**/*')).select { |file| !File.directory?(file) }

        # if tags are explicity defined, apply them to all beakers
        setup_tags(options['tag'])

        # open a tunnel if sauce connect is specified
        tunnel_id = tunnel(config)

        # configure rspec
        rspec_config(config)

        # based on concurrency parameter run tests
        if config.concurrency > 1
          exit_code = run_parallel beakers, config.concurrency
        else
          exit_code = run_rspec beakers
        end
      
        # close tunnel if sauce connect is specified
        kill_tunnel(tunnel_id) unless tunnel_id.nil?

        process_html
        exit_code
      end

      protected

      def process_html
        results_folder = File.join(Dir.getwd, 'evidence')
        output_file    = File.join(Dir.getwd, 'evidence', 'final_results.html')
        assembler      = ChemistryKit::Reporting::HtmlReportAssembler.new(results_folder, output_file)
        assembler.assemble
      end

      def pass_params
        options['params'].each_pair do |key, value|
          ENV[key] = value
        end
      end

      def load_page_objects
        loader = ChemistryKit::CLI::Helpers::FormulaLoader.new
        loader.get_formulas(File.join(Dir.getwd, 'formulas')).each { |file| require file }
      end

      def load_config(file_name)
        config_file = File.join(Dir.getwd, file_name)
        ChemistryKit::Configuration.initialize_with_yaml config_file
      end

      def setup_tags(selected_tags)
        @tags = {}
        selected_tags.each do |tag|
          filter_type = tag.start_with?('~') ? :exclusion_filter : :filter

          name, value = tag.gsub(/^(~@|~|@)/, '').split(':')
          name        = name.to_sym

          value       = true if value.nil?

          @tags[filter_type]       ||= {}
          @tags[filter_type][name] = value
        end unless selected_tags.nil?
      end
    
      def tunnel(config)
        sc_config = config.selenium_connect.dup

        if sc_config[:sauce_opts][:tunnel]
          local_path = File.join(File.dirname(File.expand_path(__FILE__)))

          # Determine binary to run based on OS (Mac vs. Linux)
          host_os = RbConfig::CONFIG['host_os']
          sc_bin_path = case host_os
            when /darwin|mac os/
              local_path + '/../../../bin/sc-mac'
            when /linux/
              local_path + '/../../../bin/sc-linux'
            else
              raise "incompatible os: #{host_os.inspect}"
          end
          tunnel_id = sc_config[:sauce_opts][:tunnel_identifier].nil? ? SecureRandom.uuid : sc_config[:sauce_opts][:tunnel_identifier]
          puts tunnel_id
          sc_path = "'" + sc_bin_path + "'" + " -i #{tunnel_id} -f #{local_path}/sauce.connect -u #{sc_config[:sauce_username]} -k #{sc_config[:sauce_api_key]}"

          sauce_connect = spawn sc_path

          start_time = Time.now

          puts "Checking for sc touching file sauce.connect"
          until File.exists?( "#{local_path}/sauce.connect" )
            # Timeout: 60sec
            raise "Timed out attempting to start sauce_connect tunnel. Aborting." if Time.now - start_time > 60
            puts "Untouched file sauce.connect"
            sleep(2)
          end
          puts "Touched file sauce.connect. Continuing with tests."
          sc_config[:sauce_opts][:tunnel_identifier] = tunnel_id
          sauce_connect
        end
      end

      def kill_tunnel(tunnel_id)
        puts "KILLING SAUCE_CONNECT TUNNEL #{tunnel_id}"
        Process.kill("INT", tunnel_id)
      end

      # rubocop:disable MethodLength
      def rspec_config(config)
        ::AllureRSpec.configure do |c|
          c.output_dir = "results"
        end

        ::RSpec.configure do |c|
          log = Logging.logger['test steps']
          c.capture_log_messages

          c.include AllureRSpec::Adaptor
          c.treat_symbols_as_metadata_keys_with_true_values = true
          unless options[:all]
            c.filter_run @tags[:filter] unless @tags[:filter].nil?
            c.filter_run_excluding @tags[:exclusion_filter] unless @tags[:exclusion_filter].nil?
          end
          c.before(:all) do
            @config         = config
            ENV['BASE_URL'] = @config.base_url # assign base url to env variable for formulas
          end

          c.around(:each) do |example|
            # create the beaker name from the example data
            beaker_name     = example.metadata[:example_group][:description_args].first.downcase.strip.gsub(' ', '_').gsub(/[^\w-]/, '')
            test_name       = example.metadata[:full_description].downcase.strip.gsub(' ', '_').gsub(/[^\w-]/, '')

            # override log path with be beaker sub path
            sc_config       = @config.selenium_connect.dup
            sc_config[:log] += "/#{beaker_name}"
            beaker_path     = File.join(Dir.getwd, sc_config[:log])

            # Current parallelization causes mkdir to still fail sometimes
            begin
              Dir.mkdir beaker_path unless File.exists?(beaker_path)
            rescue Errno::EEXIST
            end

            sc_config[:log] += "/#{test_name}"
            test_path       = File.join(Dir.getwd, sc_config[:log])
            FileUtils.rm_rf(test_path) if File.exists?(test_path)
            Dir.mkdir test_path

            log.add_appenders(
                Logging.appenders.stdout(
                    :layout => Logging.layouts.pattern(pattern:"%x %c: %m\n"
                    )
                ),
                Logging.appenders.file('test_log',
                                       :filename => test_path + '/test_steps.log',
                                       :layout   => Logging.layouts.pattern(pattern:"%m\n"))
            )
            Logging.ndc.push(test_name)

            # set the tags and permissions if sauce
            if sc_config[:host] == 'saucelabs' || sc_config[:host] == 'appium'
              tags       = example.metadata.reject do |key, value|
                [:example_group, :example_group_block, :description_args, :caller, :execution_result, :full_description].include? key
              end
              sauce_opts = {}
              sauce_opts.merge!(public: tags.delete(:public)) if tags.key?(:public)
              sauce_opts.merge!(tags: tags.map { |key, value| "#{key}:#{value}" }) unless tags.empty?

              if sc_config[:sauce_opts]
                sc_config[:sauce_opts].merge!(sauce_opts) unless sauce_opts.empty?
              else
                sc_config[:sauce_opts] = sauce_opts unless sauce_opts.empty?
              end
            end

            # configure and start sc
            configuration      = SeleniumConnect::Configuration.new sc_config
            @sc                = SeleniumConnect.start configuration
            @job               = @sc.create_job # create a new job
            @driver            = @job.start name: test_name

            # TODO: this is messy, and could be refactored out into a static on the lab
            chemist_data_paths = Dir.glob(File.join(Dir.getwd, 'chemists', '*.csv'))
            repo               = ChemistryKit::Chemist::Repository::CsvChemistRepository.new chemist_data_paths
            # make the formula lab available
            @formula_lab       = ChemistryKit::Formula::FormulaLab.new @driver, repo, File.join(Dir.getwd, 'formulas')
            example.run
            Logging.ndc.pop
          end
          c.before(:each) do
            if @config.basic_auth
              @driver.get(@config.basic_auth.http_url) if @config.basic_auth.http?
              @driver.get(@config.basic_auth.https_url) if @config.basic_auth.https?
            end

            if config.split_testing
              ChemistryKit::SplitTesting::ProviderFactory.build(config.split_testing).split(@driver)
            end
          end

          c.after(:each) do |x|
            test_name = example.description.downcase.strip.gsub(' ', '_').gsub(/[^\w-]/, '')
            if example.exception.nil? == false
              @job.finish failed: true, failshot: @config.screenshot_on_fail
              Dir[@job.get_evidence_folder+"/*"].each do |filename|
                next if File.directory? filename
                x.attach_file filename.split('/').last, File.new(filename)
              end
            else
              @job.finish passed: true
            end
            @sc.finish
          end

          unless options[:all]
            c.filter_run @tags[:filter] unless @tags[:filter].nil?
            c.filter_run_excluding @tags[:exclusion_filter] unless @tags[:exclusion_filter].nil?
          end

          c.treat_symbols_as_metadata_keys_with_true_values = true
          c.order                                           = 'random'
          c.output_stream                                   = $stdout
          # for rspec-retry
          c.verbose_retry                                   = true
          c.default_retry_count                             = config.retries_on_failure

          c.add_formatter 'progress'
          c.add_formatter(ChemistryKit::RSpec::RetryFormatter)

          html_log_name = "results.html"
          Dir.glob(File.join(Dir.getwd, config.reporting.path, "results*")).each { |f| File.delete(f) }
          c.add_formatter(ChemistryKit::RSpec::HtmlFormatter, File.join(Dir.getwd, config.reporting.path, html_log_name))

          junit_log_name = "junit.xml"
          Dir.glob(File.join(Dir.getwd, config.reporting.path, "junit*")).each { |f| File.delete(f) }
          c.add_formatter(ChemistryKit::RSpec::JUnitFormatter, File.join(Dir.getwd, config.reporting.path, junit_log_name))
        end
      end

      # rubocop:enable MethodLength

      def run_parallel(beakers, concurrency)
        require 'parallel_split_test/runner'
        args = beakers + ['--parallel-test', concurrency.to_s]
        ::ParallelSplitTest::Runner.run(args)
      end

      def run_rspec(beakers)
        ::RSpec::Core::Runner.run(beakers)
      end
    end # CkitCLI
  end # CLI
end # ChemistryKit

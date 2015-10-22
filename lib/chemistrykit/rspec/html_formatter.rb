# Encoding: utf-8

require 'rspec/core/formatters/base_text_formatter'
require 'nokogiri'
require 'erb'
require 'rspec/core/formatters/snippet_extractor'
require 'pygments'
require 'securerandom'

module ChemistryKit
  module RSpec
    class HtmlFormatter < ::RSpec::Core::Formatters::BaseTextFormatter
      include ERB::Util # for the #h method
      def initialize(output)
        super(output)
        @testcases_data = {}
      end

      def start(example_count)
        super(example_count)
        @output_html = ''
      end

      def example_group_started(example_group)
        @testcases_data[slugify(example_group.description)] = ['passing', '']
      end

      def example_group_finished(example_group)
        beaker = slugify(example_group.description)
        unless @testcases_data[beaker][1] == ''
          @output_html << build_fragment do |doc|
            status = @testcases_data[beaker][0]
            show = status == 'passing' ? 'show' : ''
            doc.div(class: "row example-group #{status} #{show}") do
              doc.div(class: 'large-12 columns') do
                doc.h3 do
                  doc.i(class: 'icon-beaker')
                  doc.text ' ' + example_group.description
                end
                doc.div(class: 'examples') do
                  doc << @testcases_data[beaker][1]
                end
              end
            end
          end
        end
      end

      def example_started(example)
        super(example)
        @process = ENV['TEST_ENV_NUMBER']
        if @process == nil
          @process = 0
        end
      end

      def example_passed(example)
        super(example)
        beaker = root_group_name_for(example)
        example_folder = slugify(beaker + '_' + example.description)
        log_path = File.join(Dir.getwd, 'evidence', beaker, example_folder, 'test_steps.log')
        if (File.exist?(log_path) && !File.zero?(log_path))
          @testcases_data[beaker][1] += render_example('passing', example) do |doc|
            doc.a(href: log_path) { doc.text 'Test Steps' }
          end
        else
          @testcases_data[beaker][1] += render_example('passing', example) {}
        end
      end

      def example_pending(example)
        super(example)
          beaker = root_group_name_for(example)
          @testcases_data[beaker][1] += render_example('pending', example) do |doc|
          doc.div(class: 'row exception') do
            doc.div(class: 'large-12 columns') do
              doc.pre do
                doc.text "PENDING: #{example.metadata[:execution_result][:pending_message]}"
              end
            end
          end
        end
      end

      def example_failed(example)
        super(example)
        beaker = root_group_name_for(example)
        exception = example.metadata[:execution_result][:exception]
        @testcases_data[beaker][0] = 'failing'
        @testcases_data[beaker][1] += render_example('failing', example) do |doc|
          doc.div(class: 'row exception') do
            doc.div(class: 'large-12 columns') do
              doc.pre do
                message = exception.message if exception
                doc.text message
              end
            end
          end
          doc.div(class: 'row code-snippet') do
            doc.div(class: 'large-12 columns') do
              doc << render_code(exception)
            end
          end
          doc << render_extra_content(example)
        end
      end

      def dump_summary(duration, example_count, failure_count, pending_count)
        unless example_count == 0
          output = build_fragment do |doc|
            doc.div(
              class: 'results',
              'data-count' => example_count.to_s,
              'data-duration' => duration.to_s,
              'data-failures' => failure_count.to_s,
              'data-pendings' => pending_count.to_s
              ) { doc << @output_html }
          end
          results_path = @output.path.split(".html").first + '_' + @process.to_s + ".html"
          results_output = File.exists?(results_path) ? File.open(results_path, "w") : File.new(results_path, "w")
          results_output.puts output
          #@output.puts output
        end
      end

      # TODO: put the right methods private, or better yet, pull this stuff out into its own
      # set of classes
      def root_group_name_for(example)
        group_hierarchy = []
        current_example_group = example.metadata[:example_group]
        until current_example_group.nil?
          group_hierarchy.unshift current_example_group
          current_example_group = current_example_group[:example_group]
        end
        slugify group_hierarchy.first[:description]
      end

      def render_extra_content(example)
        build_fragment do |doc|
          doc.div(class: 'row extra-content') do
            doc.div(class: 'large-12 columns') do
              doc.div(class: 'section-container auto', 'data-section' => '') do
                doc << render_failshot_if_found(example)
                doc << render_video_if_found(example)
                doc << render_stack_trace(example)
                doc << render_log_if_found(example, 'test_steps.log')
                doc << render_log_if_found(example, 'server.log')
                doc << render_log_if_found(example, 'chromedriver.log')
                doc << render_log_if_found(example, 'firefox.log')
                doc << render_log_if_found(example, 'sauce_job.log')

                doc << render_dom_html_if_found(example)
              end
            end
          end
        end
      end

      def render_dom_html_if_found(example)
        # TODO: pull out the common code for checking if the log file exists
        beaker = root_group_name_for(example)
        example_folder = slugify(beaker + '_' + example.description)
        paths = Dir.glob(File.join(Dir.getwd, 'evidence', beaker, example_folder, 'dom_*.html'))
        number = 0
        sections = ''
        paths.each do |path|
          if File.exist?(path)
            sections << render_section("Dom HTML #{number}") do |doc|
              doc << Pygments.highlight(File.read(path), lexer: 'html')
            end
            number += 1
          end
        end
        sections
      end

      # TODO: replace the section id with a uuid or something....
      def render_failshot_if_found(example)
        beaker = root_group_name_for(example)
        example_folder = slugify(beaker + '_' + example.description)

        path = File.join(Dir.getwd, 'evidence', beaker, example_folder, 'failshot.png')
        if File.exist?(path)
          render_section('Failure Screenshot') do |doc|
            relative_path = File.join(beaker, example_folder, 'failshot.png')
            doc.img(src: relative_path)
          end
        end
      end

      def render_video_if_found(example)
        beaker = root_group_name_for(example)
        example_folder = slugify(beaker + '_' + example.description)

        path = File.join(Dir.getwd, 'evidence', beaker, example_folder, 'video.flv')
        if File.exist?(path)
          render_section('Failure Video') do |doc|
            relative_path = File.join(beaker, example_folder, 'video.flv')
            doc.a(href: relative_path) { doc.text relative_path }
          end
        end
      end

      def render_log_if_found(example, log)
        beaker = root_group_name_for(example)
        example_folder = slugify(beaker + '_' + example.description)
        log_path = File.join(Dir.getwd, 'evidence', beaker, example_folder, log)
        if File.exist?(log_path)
          render_section(log.capitalize) do |doc|
            doc.pre do
              doc.text File.open(log_path, 'rb') { |file| file.read }
            end
          end
        end
      end

      def slugify(string)
        string.downcase.strip.gsub(' ', '_').gsub(/[^\w-]/, '')
      end

      def render_stack_trace(example)
        exception = example.metadata[:execution_result][:exception]
        render_section('Stack Trace') do |doc|
          doc.pre do
            doc.text format_backtrace(exception.backtrace, example).join("\n")
          end
        end
      end

      def render_code(exception)
        backtrace = exception.backtrace.map { |line| backtrace_line(line) }
        backtrace.compact!
        @snippet_extractor ||= ::RSpec::Core::Formatters::SnippetExtractor.new
        "<pre class=\"ruby\"><code>#{@snippet_extractor.snippet(backtrace)}</code></pre>"
      end

      def render_section(title)
        panel_id = SecureRandom.uuid
        build_fragment do |doc|
          doc.section do
            doc.p(class: 'title', 'data-section-title' => '') do
              doc.a(href: "#panel#{panel_id}") { doc.text title }
            end
            doc.div(class: 'content', 'data-section-content' => '') do
              yield doc
            end
          end
        end
      end

      def render_example(status, example)
        time = example.execution_result[:run_time]
        if (time / 60).to_i > 0
          time_str = (time / 60).to_i.to_s + 'm ' + (time % 60).round.to_s + 's'
        else
          time_str = time.round.to_s + 's'
        end
        build_fragment do |doc|
          doc.div(class: "row example #{status}") do
            doc.div(class: 'large-12 columns') do
              doc.div(class: 'row example-heading') do
                doc.div(class: 'large-9 columns') do
                  doc.p { doc.text example.description.capitalize }
                end
                doc.div(class: 'large-3 columns text-right') do
                  doc.p { doc.text time_str }
                  end
              end
              doc.div(class: 'row example-body') do
                doc.div(class: 'large-12 columns') { yield doc }
              end
            end
          end
        end
      end

      def build_fragment
        final = Nokogiri::HTML::DocumentFragment.parse ''
        Nokogiri::HTML::Builder.with(final) do |doc|
          yield doc
        end
        final.to_html
      end
    end
  end
end

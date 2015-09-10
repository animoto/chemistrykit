# Encoding: utf-8

require 'nokogiri'

module ChemistryKit
  module Reporting
    class HtmlReportAssembler
      # TODO: Refactor to remove this cop exception
      # rubocop:disable MethodLength, ParameterLists
      def initialize(results_path, output_file)
        @results_path = results_path
        @output_file = output_file
        @groups = []
        @total_reactions = 0
        @total_failures = 0
        @total_duration = 0
        @total_pending = 0
      end

      def assemble
        result_files = Dir.glob(File.join(@results_path, 'results_*.html'))

        result_files.each do |file|
          doc = Nokogiri.HTML(open(file))

          doc.css('.results').each do |element|
            @total_reactions += element['data-count'].to_i
            @total_failures += element['data-failures'].to_i
            @total_pending += element['data-pendings'].to_i
            @total_duration += element['data-duration'].to_f
          end

          doc.css('.example-group').each do |group|
            @groups << group
          end
        end

        status = @total_failures > 0 ? 'failing' : 'passing'

        File.open(@output_file, 'w') do |file|

          file.write '<!DOCTYPE html>'
          file.write '<!--[if IE 8]>         <html class="no-js lt-ie9" lang="en" > <![endif]-->'
          file.write '<!--[if gt IE 8]><!--> <html class="no-js" lang="en" > <!--<![endif]-->'

            file.write get_report_head status
          file.write '<body>'
            file.write get_report_header
            file.write '<div class="report">'
              file.write get_report_summary status, @groups.count, @total_reactions, @total_failures, @total_pending, @total_duration

          @groups.each do |group|
            file.write group
          end

          file.write '</div>' # closes .report

          file.write get_report_endscripts
          file.write '</body>'
          file.write '</html>'

        end

      end

      def get_report_head(state)
        build_fragment do |doc|
          doc.head do
            doc.meta(charset: 'utf-8')
            doc.meta(name: 'viewport', content: 'width=device-width')
            doc.title { doc.text "ChemistryKit - #{state.capitalize}" }
            doc.style(type: 'text/css') do
              doc.text load_from_file(File.join(File.dirname(File.expand_path(__FILE__)), '../../../report/', 'stylesheets', 'app.css'))
            end
            doc.link(href: 'http://netdna.bootstrapcdn.com/font-awesome/3.2.1/css/font-awesome.css', rel: 'stylesheet')
            doc.script do
              doc.text load_from_file(File.join(File.dirname(File.expand_path(__FILE__)), '../../../report/', 'javascripts', 'vendor', 'custom.modernizr.js'))
            end
          end
        end
      end

      def get_report_header
        build_fragment do |doc|
          doc.header(class: 'row') do
            doc.div(class: 'large-12 columns') do
              doc.h2 { doc.text 'ChemistryKit Brew Results' }
            end
          end
        end
      end

      def get_report_summary(status, beakers, reactions, failures, pendings, duration)
        if status == 'passing'
          icon = 'icon-ok-sign'
          message = ' Brew Passing'
        else
          icon = 'icon-warning-sign'
          message = ' Brew Failing'
        end
        build_fragment do |doc|
          doc.div(class: 'summary') do
            doc.div(class: "row status #{status}") do
              doc.div(class: 'large-9 columns') do
                doc.h1 do
                  doc.i(class: icon)
                  doc.text message
                end
              end
              doc.div(class: 'large-3 columns top-row') do
                %w[passing failing pending].each do | type |
                  doc.div(class: 'row switch-row') do
                    doc.div(class: 'large-6 columns switch-label') do
                      doc.text type.capitalize
                    end
                    doc.div(class: 'large-6 columns') do
                      doc.div(class: "#{type}-switch") do
                        opts = { onclick: "toggle#{type.capitalize}();", name: "switch-show-#{type}", type: 'radio' }
                        top = opts.merge(id: "show-#{type}")
                        bot = opts.merge(id: "show-#{type}1")
                        top.merge!(checked: 'checked') unless type == 'passing'
                        bot.merge!(checked: 'checked') if type == 'passing'
                        doc.input(top)
                        doc.label(for: "show-#{type}") { doc.text 'Hide' }
                        doc.input(bot)
                        doc.label(for: "show-#{type}1") { doc.text 'Show' }
                        doc.span
                      end
                    end
                  end
                end
              end
            end
            doc.div(class: 'row details') do
              doc.div(class: 'large-12 columns') do
                doc.ul(class: 'large-block-grid-5') do
                  doc.li do
                    doc.i(class: 'icon-beaker passing-color')
                    doc.p { doc.text "#{beakers.to_s} Beakers" }
                  end
                  doc.li do
                    doc.i(class: 'icon-tint reaction-color')
                    doc.p { doc.text "#{reactions.to_s} Reactions" }
                  end
                  doc.li do
                    doc.i(class: 'icon-warning-sign failing-color')
                    doc.p { doc.text "#{failures.to_s} Failures" }
                  end
                  doc.li do
                    doc.i(class: 'icon-question-sign pending-color')
                    doc.p { doc.text "#{pendings.to_s} Pending" }
                  end
                  doc.li do
                    doc.i(class: 'icon-time')
                    doc.p { doc.text "#{ sprintf("%.1i", duration / 60) }m Duration" }
                  end
                end
              end
            end
          end
        end
      end

      def get_report_endscripts
        build_fragment do |doc|
          doc.script do
            doc.text load_from_file(File.join(File.dirname(File.expand_path(__FILE__)), '../../../report/', 'javascripts', 'vendor', 'jquery.js'))
          end
          doc.script do
            doc.text load_from_file(File.join(File.dirname(File.expand_path(__FILE__)), '../../../report/', 'javascripts', 'foundation', 'foundation.js'))
          end
          doc.script do
            doc.text load_from_file(File.join(File.dirname(File.expand_path(__FILE__)), '../../../report/', 'javascripts', 'foundation', 'foundation.section.js'))
          end
          doc.script { doc.text '$(document).foundation();' }
          doc.script do
            doc.text "
              function togglePassing() {
                console.log('passing')
                $('.example.passing').toggle();
                $('.example-group.passing').toggle();
              }

              function toggleFailing() {
                console.log('failing')
                $('.example.failing').toggle();
                $('.example-group.failing').toggle();
              }

              function togglePending() {
                console.log('pending')
                $('.example.pending').toggle();
                $('.example-group.pending').toggle();
              }"
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

      def load_from_file(path)
        File.open(path, 'rb') { |file| file.read }
      end
      # rubocop:enable MethodLength, ParameterLists
    end
  end
end

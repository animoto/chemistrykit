# Encoding: utf-8

require 'spec_helper'
require 'chemistrykit/reporting/html_report_assembler'

describe ChemistryKit::Reporting::HtmlReportAssembler do

  before(:each) do
    results_folder = File.join(Dir.pwd, 'spec', 'support', 'test_output')
    output_file = File.join(Dir.pwd, 'build', 'tmp', 'final_results.html')
    @assembler = ChemistryKit::Reporting::HtmlReportAssembler.new(results_folder, output_file)
  end

  it 'should correctly assemble the files' do
    @assembler.assemble
  end

end

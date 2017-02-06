# Encoding: utf-8

require 'spec_helper'
require 'chemistrykit/config/reporting'

describe ChemistryKit::Config::Reporting do

  VALID_REPORTS_PATH = 'test_output'

  before(:each) do
    @reporting =  ChemistryKit::Config::Reporting.new
  end

  it 'should be initialized with no arguments' do
    @reporting.should be_an_instance_of ChemistryKit::Config::Reporting
  end

  it 'should return "evidence" for the log path' do
    @reporting.path.should eq VALID_REPORTS_PATH
  end
end

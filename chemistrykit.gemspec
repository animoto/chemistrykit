# Encoding: utf-8

Gem::Specification.new do |s|
  s.name          = 'chemistrykit'
  s.version       = '3.10.0'
  s.platform      = Gem::Platform::RUBY
  s.authors       = ['Dave Haeffner', 'Jason Fox']
  s.email         = ['dave@arrgyle.com', 'jason@arrgyle.com']
  s.homepage      = 'https://github.com/arrgyle/chemistrykit'
  s.summary       = 'A simple and opinionated web testing framework for Selenium that follows convention over configuration.'
  s.description   = 'Merged various pull requests including subfolders in beaker directory'
  s.license       = 'MIT'

  s.files         = `git ls-files`.split($/)
  s.files.reject! { |file| file.include? '.jar' }
  s.test_files    = s.files.grep(%r{^(scripts|spec|features)/})
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.require_paths = ['lib']


  s.add_dependency 'thor', '~> 0.17.0'
  s.add_dependency 'rspec', '~> 2.14.1'
  s.add_dependency 'allure-rspec'
  s.add_dependency 'builder', '~> 3.0'
  s.add_dependency 'selenium-webdriver', '3.5.2'
  s.add_dependency 'rest-client', '~> 1.7'
  s.add_dependency 'parallel_split_test'
  s.add_dependency 'parallel'
  s.add_dependency 'rspec-retry', '~> 0.2.1'
  s.add_dependency 'nokogiri'
  s.add_dependency 'syntax'
  s.add_dependency 'pygments.rb', '~> 0.5.2'
  s.add_dependency 'logging', '~> 2.0.0'
end

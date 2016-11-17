Feature: Basic Authentication

Selenium 2 does not allow header injection. So in order to support basic auth, we will pre-load HTTP and HTTPS URLs with get actions before each test execution in order for the browser to cache this information.

This way tests will be able to execute without being prompted by a modal dialog box.


Background:
  Given I run `bundle exec ckit new basic_auth_harness`
  And I cd to "basic_auth_harness"
  And a file named "beakers/basic_auth_1_beaker.rb" with:
    """
    describe "Basic Auth", :depth => 'shallow' do
      it "works without providing credentials in the URL" do
        @driver.get ENV['BASE_URL']
        @driver.find_elements({css: 'a'}).size.should_not be_zero
      end
    end
    """
Scenario: Pre-load HTTP before each test
  And a file named "config.yaml" with:
    """
    base_url: 'http://the-internet.herokuapp.com/basic_auth'
    basic_auth:
        username:   'admin'
        password:   'admin'
        http_path:   '/'
    """
  When I run `bundle exec ckit brew`
  Then the stdout should contain "1 example, 0 failures"

Scenario: Pre-load HTTP before each test without the http_path set
  And a file named "config.yaml" with:
    """
    base_url: 'http://the-internet.herokuapp.com/basic_auth'
    basic_auth:
        username:   'admin'
        password:   'admin'
    """
  When I run `bundle exec ckit brew`
  Then the stdout should contain "1 example, 1 failure"

Scenario: Works without Basic Auth
  And a file named "config.yaml" with:
    """
    base_url: 'http://google.com'
    """
  When I run `bundle exec ckit brew`
  Then the stdout should contain "1 example, 0 failures"

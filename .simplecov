require 'codecov'
require 'simplecov'

SimpleCov.add_filter "/unit-test.sh"
SimpleCov.add_filter "/unit-test.sh"
SimpleCov.formatter = SimpleCov.formatter = Codecov::SimpleCov::Formatter

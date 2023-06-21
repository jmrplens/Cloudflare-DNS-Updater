require 'codecov'
require 'simplecov'
require 'simplecov-cobertura'

SimpleCov.add_filter "/unit-test.sh"
SimpleCov.add_filter "/unit-test.sh"
SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter

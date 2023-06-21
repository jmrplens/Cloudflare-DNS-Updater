require 'codecov'
require 'simplecov'
require 'simplecov-cobertura'

SimpleCov.add_filter "/unit-test.sh"
SimpleCov.add_filter "/test/"
SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::CSVFormatter,
  SimpleCov::Formatter::CoberturaFormatter,
]

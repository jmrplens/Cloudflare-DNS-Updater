require 'codecov'
require 'simplecov'
require 'simplecov-cobertura'
require 'simplecov-csv'

SimpleCov.add_filter "/unit-test.sh"
SimpleCov.add_filter "/test/"
SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new[
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::CSVFormatter,
  SimpleCov::Formatter::CoberturaFormatter,
]

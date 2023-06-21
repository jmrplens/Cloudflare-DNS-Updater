require 'codecov'
require 'simplecov'
require 'simplecov-cobertura'
require 'simplecov-csv'

SimpleCov.start do
  SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::CSVFormatter,
    SimpleCov::Formatter::CoberturaFormatter,
  ])
  add_filter "/unit-test.sh"
  add_filter "test/"
end

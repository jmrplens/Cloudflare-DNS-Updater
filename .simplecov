require 'codecov'
require 'simplecov'
require 'simplecov-cobertura'
require 'simplecov-csv'
require 'simplecov-tailwindcss'
require 'simplecov_json_formatter'

SimpleCov.configure do
  SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::CSVFormatter,
    SimpleCov::Formatter::CoberturaFormatter,
    SimpleCov::Formatter::JSONFormatter,
    SimpleCov::Formatter::TailwindFormatter,
  ])
  add_filter "unit-test.sh"
  add_filter %r{^/test/}
end

SimpleCov.start 'Unit Tests'

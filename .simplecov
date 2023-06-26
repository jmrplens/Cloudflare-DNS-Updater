require 'codecov'
require 'bashcov'
require 'simplecov'
require 'simplecov-cobertura'
require 'simplecov-csv'
require 'simplecov-tailwindcss'
require 'simplecov_json_formatter'

SimpleCov.configure do
  SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::CSVFormatter,
    SimpleCov::Formatter::CoberturaFormatter,
    SimpleCov::Formatter::JSONFormatter,
    SimpleCov::Formatter::TailwindFormatter,
  ])
  add_filter "unit-test.sh"
  add_filter %r{^/test/}
end

SimpleCov.command_name 'bats'
SimpleCov.start 'shell'

SimpleCov.at_exit do
  SimpleCov.result.format!
end

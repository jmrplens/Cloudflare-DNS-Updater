require 'codecov'
require 'simplecov'

SimpleCov.start do
  add_filter "/test/"
  add_filter "/unit-test.sh"
  formatter SimpleCov::Formatter::CoberturaFormatter
end

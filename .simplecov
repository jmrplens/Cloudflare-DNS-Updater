SimpleCov.start do
  add_filter "/test/"
  formatter SimpleCov::Formatter::CoberturaFormatter
end

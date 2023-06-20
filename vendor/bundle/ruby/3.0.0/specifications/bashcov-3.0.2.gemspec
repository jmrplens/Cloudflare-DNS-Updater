# -*- encoding: utf-8 -*-
# stub: bashcov 3.0.2 ruby lib

Gem::Specification.new do |s|
  s.name = "bashcov".freeze
  s.version = "3.0.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/infertux/bashcov/blob/master/CHANGELOG.md", "homepage_uri" => "https://github.com/infertux/bashcov", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/infertux/bashcov" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["C\u00E9dric F\u00E9lizard".freeze]
  s.date = "2023-04-18"
  s.description = "Code coverage tool for Bash".freeze
  s.email = ["cedric@felizard.fr".freeze]
  s.executables = ["bashcov".freeze]
  s.files = ["bin/bashcov".freeze]
  s.homepage = "https://github.com/infertux/bashcov".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.0.0".freeze)
  s.rubygems_version = "3.2.33".freeze
  s.summary = "Code coverage tool for Bash".freeze

  s.installed_by_version = "3.2.33" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<simplecov>.freeze, ["~> 0.21.2"])
    s.add_development_dependency(%q<aruba>.freeze, [">= 0"])
    s.add_development_dependency(%q<bundler-audit>.freeze, [">= 0"])
    s.add_development_dependency(%q<cucumber>.freeze, [">= 0"])
    s.add_development_dependency(%q<rake>.freeze, [">= 0"])
    s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
    s.add_development_dependency(%q<rubocop>.freeze, [">= 0"])
    s.add_development_dependency(%q<rubocop-rake>.freeze, [">= 0"])
    s.add_development_dependency(%q<rubocop-rspec>.freeze, [">= 0"])
    s.add_development_dependency(%q<yard>.freeze, [">= 0"])
  else
    s.add_dependency(%q<simplecov>.freeze, ["~> 0.21.2"])
    s.add_dependency(%q<aruba>.freeze, [">= 0"])
    s.add_dependency(%q<bundler-audit>.freeze, [">= 0"])
    s.add_dependency(%q<cucumber>.freeze, [">= 0"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
    s.add_dependency(%q<rspec>.freeze, [">= 0"])
    s.add_dependency(%q<rubocop>.freeze, [">= 0"])
    s.add_dependency(%q<rubocop-rake>.freeze, [">= 0"])
    s.add_dependency(%q<rubocop-rspec>.freeze, [">= 0"])
    s.add_dependency(%q<yard>.freeze, [">= 0"])
  end
end

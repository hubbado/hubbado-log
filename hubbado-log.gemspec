Gem::Specification.new do |s|
  s.name = "hubbado-log"
  s.version = "1.0.0"
  s.summary = "Lightweight pluggable logging system"

  s.authors = ["Hubbado Devs"]
  s.email = ["devs@hubbado.com"]
  s.homepage = "https://www.github.com/hubbado/hubbado-log"
  s.license  = "MIT"

  s.metadata["homepage_uri"] = s.homepage
  s.metadata["source_code_uri"] = s.homepage
  s.metadata["changelog_uri"] = "#{s.homepage}/blob/master/CHANGELOG.md"

  s.require_paths = ["lib"]

  s.files = Dir.glob(%w[
    lib/**/*.rb
    *.gemspec
    LICENSE*
    README*
    CHANGELOG*
  ])

  s.required_ruby_version = '> 2.5'

  s.add_runtime_dependency 'evt-dependency'

  s.add_development_dependency "debug"
  s.add_development_dependency "hubbado-style"
  s.add_development_dependency "test_bench"
end

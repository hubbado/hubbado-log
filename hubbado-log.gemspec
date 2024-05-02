lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "hubbado-log"
  spec.version       = "1.0.0"
  spec.authors       = ["Sam Stickland"]
  spec.email         = ["sam@hubbado.com"]

  spec.summary       = "Lightweight pluggable logging system"
  spec.homepage      = "https://www.github.com/hubbado/logger"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["homepage_uri"] = spec.homepage
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '> 2.5'

  spec.add_runtime_dependency 'evt-dependency'

  spec.add_development_dependency "debug"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "test_bench"
end

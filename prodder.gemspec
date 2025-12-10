# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift(File.expand_path("lib", __dir__))
require "prodder/version"

Gem::Specification.new do |s|
  s.name        = "prodder"
  s.version     = Prodder::VERSION
  s.authors     = ["Kyle Hargraves"]
  s.email       = ["pd@krh.me"]
  s.homepage    = "https://github.com/enova/prodder"
  s.license     = "MIT"
  s.summary     = "Maintain your Rails apps' structure, seed and quality_checks files using production dumps"
  s.description = "Migrations suck long-term. Now you can kill them routinely."

  s.files         = Dir.glob("{lib,bin,features}/**/*") + Dir.glob("*").reject { |f| File.directory?(f) }
  s.test_files    = Dir.glob("{test,spec,features}/**/*")
  s.executables   = Dir.glob("bin/*").map { |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 2.7.0"

  # These dependencies do not match the Gemfile's for a reason.
  # These are the only dependencies necessary to satisfy inclusion of this
  # gem in a Rails application; any dependencies necessary to run prodder
  # itself are specified in the Gemfile.
  s.add_dependency "deject"
end

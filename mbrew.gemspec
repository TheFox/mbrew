# coding: UTF-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'mbrew/version'

Gem::Specification.new do |spec|
  spec.name = 'mbrew'
  spec.version = TheFox::MBrew::VERSION
  spec.date = TheFox::MBrew::DATE
  spec.author = 'Christian Mayer'
  spec.email = 'christian@fox21.at'

  spec.summary = %q{MusicBrew}
  spec.description = %q{A Package Manager for Music.}
  spec.homepage = TheFox::MBrew::HOMEPAGE
  spec.license = 'GPL-3.0'

  spec.files = `git ls-files -z`.split("\x0").reject {|f| f.match(%r{^(test|spec|features)/})}
  spec.bindir = 'bin'
  spec.executables = ['mbrew']
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>=2.2.0'

  spec.requirements << 'GPG'
  spec.requirements << 'Git'

  spec.add_development_dependency 'bundler', '~>1.10'

  spec.add_runtime_dependency 'rainbow', '~>2.0'
  spec.add_runtime_dependency 'git', '~>1.2'
  spec.add_runtime_dependency 'id3lib-ruby', '~>0.6'
  spec.add_runtime_dependency 'highline', '~>1.7'
  spec.add_runtime_dependency 'thefox-ext', '~>1.0'
end

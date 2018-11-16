# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name        = 'contextual_logger'
  spec.version     = '0.1.0'
  spec.license     = 'MIT'
  spec.date        = '2018-10-12'
  spec.summary     = 'Add context to your logger'
  spec.description = 'A way to add context to the logs you have'
  spec.authors     = ['James Ebentier']
  spec.email       = 'jebentier@invoca.com'
  spec.files       = ['lib/contextual_logger.rb']
  spec.homepage    = 'https://rubygems.org/gems/contextual_logger'
  spec.metadata    = { 'source_code_uri' => 'https://github.com/Invoca/contextual_logger' }

  spec.add_runtime_dependency 'json'
end

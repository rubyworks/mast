module Mast
  # Access to project metadata.
  def self.metadata
    @metadata ||= (
      require 'yaml'
      YAML.load(File.new(File.dirname(__FILE__) + '/mast.yml'))
    )
  end

  # Access project metadata via constants.
  def self.const_missing(name)
    key = name.to_s.downcase
    package[key] || super(name)
  end

  # becuase Ruby 1.8~ gets in the way
  VERSION = metadata['version']
end

require 'mast/manifest'

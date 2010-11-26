module Mast
  #
  def self.package
    @package ||= (
      require 'yaml'
      YAML.load(File.new(File.dirname(__FILE__) + '/package.yml'))
    )
  end

  #
  def self.const_missing(name)
    key = name.to_s.downcase
    package[key] || super(name)
  end

  # becuase Ruby 1.8~ gets in the way
  VERSION = package['version']
end


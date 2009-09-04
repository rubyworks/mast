module Mast

  #
  def self.create(options)
    # generate and save manifest

  end

  #
  def self.update(options)
    # read manifest file

    # parse topline for manifest options

    # generate and save manifest

  end

  #
  def self.diff(options)

  end


  class Manifest

    #
    def initialize(path, options={})
      @exclude = options[:exclude] || []

      if File.directory?(path)
        
      else

      end
    end

    #
    def options_set(options)
    end

    #

  end


end

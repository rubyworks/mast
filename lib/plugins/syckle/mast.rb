module Syckle::Plugins

  # = Mast Manifest Plugin
  #
  class Mast < Service

    # Pre-package phase.
    precycle :main, :package do
      generate
    end

    cycle :main, :reset
    cycle :main, :clean

    # Not that this is necessary, but ...
    available do |project|
      begin
        require 'mast'
        true
      rescue LoadError
        false
      end
    end

    # Default MANIFEST filename.
    DEFAULT_FILENAME = 'MANIFEST'

    # Default files/dirs to include.
    DEFAULT_INCLUDE = %w{ bin data etc features lib man meta qed script spec test [A-Z]* }

    # Default files/dirs to exclude.
    DEFAULT_EXCLUDE = nil #%w{}

    # Default files/dirs to ignore. Unlike exclude, this work
    # on path basenames, and not full pathnames.
    DEFAULT_IGNORE = nil #%w{}

    #
    attr_accessor :include

    #
    attr_accessor :exclude

    #
    attr_accessor :ignore

    #
    attr_accessor :output

    #
    #def output=(path)
    #  @output = Pathname.new(path)
    #end

    #
    def manifest
      @manifest ||= ::Mast::Manifest.new(options)
    end

    # Generate manifest.
    # TODO: don't overwrite if it hasn't changed
    def generate
      if manifest.changed?
        file = manifest.save #update #generate
        report "Updated #{file.to_s.sub(Dir.pwd+'/','')}"
        #report "Updated #{output.to_s.sub(Dir.pwd+'/','')}"
      else
        report "#{output.to_s.sub(Dir.pwd+'/','')} is current"
      end
    end

    # Mark MANIFEST as out-of-date.
    # TODO: Implement reset.
    def reset
    end

    # Remove MANIFEST.
    # TODO: Currently a noop. Not sure removing manfest is ever a good idea.
    def clean
    end

  private

    #
    def initialize_defaults
      @include = DEFAULT_INCLUDE
      @exclude = DEFAULT_EXCLUDE
      @ignore  = DEFAULT_IGNORE
      @output  = (file || project.root + DEFAULT_FILENAME).to_s
    end

    #
    def file
      project.root.glob("MANIFEST{,.txt}").first
    end

    #
    def options
      { :include => include,
        :exclude => exclude,
        :ignore  => ignore,
        :file    => output
      }
    end

  end

end


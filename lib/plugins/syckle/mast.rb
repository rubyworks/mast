module Syckle::Plugins

  # = Mast Manifest Plugin
  #
  class Mast < Service

    precycle :main, :package => :generate

    cycle :main, :reset
    cycle :main, :clean

    # not that this is necessary, but ...
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
    DEFAULT_INCLUDE = %w{ bin lib meta script test [A-Z]* }

    # Default files/dirs to exclude.
    DEFAULT_EXCLUDE = %w{ }

    # Default files/dirs to ignore. Unlike exclude, this work
    # on files basenames, and not full pathnames.
    DEFAULT_IGNORE = %w{ .svn }

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
      @manifest ||= Manifest.new(options)
    end

    # Generate manifest.
    def generate
      manifest.generate
      report "Updated #{output.to_s.sub(Dir.pwd+'/','')}"
    end

    # Mark MANIFEST as out-of-date.
    # TODO: Implement reset.
    def reset
    end

    # Remove MANIFEST.
    # TODO: Currently a noop. Not sure removing manfest is a good idea.
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


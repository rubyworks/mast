module Mast

  #
  class Listing

    DEFAULT_EXCLUDE = %w{InstalledFiles .config *~ CVS _darcs .svn .git}
    DEFAULT_IGNORE  = %w{*~ .svn}

    # Encryption type
    attr_accessor :digest

    # Do not use standard exclude/ignore.
    attr_accessor :all

    # What file patterns to exclude.
    # Exclusion pattens operate on the full pathname.
    attr_accessor :exclude

    # What special file patterns to ignore.
    # Ignore patterns operate on a path's basename only.
    attr_accessor :ignore

    # Layout of digest -- csf or sfv. Default is csf.
    attr_accessor :format

    #
    def initialize(location, options={})
      raise unless File.directory?(location)
      @location = location
      file_or_options.each do |h,k|
        send("#{h}=", k)
      end
    end

    # Returns a hash of path => checksum.
    #
    def chart
      @chart ||= (
        h = {}
        list.each do |path|
          h[path] = checksum(path)
        end
        h
      )
    end

    # List of files in location minus exclusions.
    #
    def list
      @list ||= (
        files = []
        Dir.chdir(@location) do
          files += Dir.multiglob_r('**/*')
          files -= Dir.multiglob_r(exclusions)
        end
        files
      )
    end

  private

    # Compute exclusions.
    #
    def exclusions
      @_exclusions ||= (
        e = [exclude].flatten
        e += DEFAULT_EXCLUDE unless all?
        #e += [filename, filename.chomp('~')] if file
        e
      )
    end

    # Produce hexdigest/cheksum for a file.
    # Default digest type is sha1.

    def checksum(file, digest=nil)
      return nil unless digest
      if FileTest.directory?(file)
        @null_string ||= digester(digest).hexdigest("")
      else
        digester(digest).hexdigest(File.read(file))
      end
    end

    # Return a digest class for given +type+.
    # Supported digests are:
    #
    # * md5
    # * sha1
    # * sha128  (same as sha1)
    # * sha256
    # * sha512
    #
    # Default digest type is sha256.

    def digester(type=nil)
      require 'openssl'
      case type.to_s.downcase
      when 'md5'
        require 'digest/md5'
        ::Digest::MD5
      when 'sha128', 'sha1'
        require 'digest/sha1'  #need?
        OpenSSL::Digest::SHA1
      when 'sha256'
        require 'digest/sha1'  #need?
        OpenSSL::Digest::SHA256
      when 'sha512'
        require 'digest/sha1'  #need?
        OpenSSL::Digest::SHA512
      else
        raise "unsupported digest #{type}"
      end
    end

  end

end


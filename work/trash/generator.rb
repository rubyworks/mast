module Mast

  class Generator

    # File used to store digest/manifest.
    attr_accessor :file

    # Encryption type
    attr_accessor :digest

    # Do not use standard exclude/ignore.
    attr_accessor :all

    # What files to exclude from digest.
    attr_accessor :exclude

    # What special files to ignore.
    attr_accessor :ignore

    # Directory to use.
    attr_accessor :directory

    # Layout of digest -- csf or sfv. Default is csf.
    attr_accessor :format

    # Generate manifest.
    def generate(out=$stdout)
      out << topline_string
      output(out)
    end

    #
    alias_method :all?, :all

  private

    #

    def output(out=$stdout)
      Dir.chdir(location) do
        rec_output('*', out)
      end
    end

    # Generate listing on the fly.

    def rec_output(match, out=$stdout)
      out.flush
      #match = (location == dir ? '*' : File.join(dir,'*'))
      files = Dir.glob(match) - exclusions
      files.sort!
      files.each do |file|
        sum = checksum(file,digest)
        sum = sum + ' ' if sum
        out << "#{sum}#{file}\n"
        if File.directory?(file)
          rec_output(File.join(file,'*'), out)
        end
      end
      #return out
    end

    # Compute exclusions.

    def exclusions
      @_exclusions ||= (
        e = [exclude].flatten
        e += DEFAULT_EXCLUDE unless all?
        e += [filename, filename.chomp('~')] if file
        e
      )
    end

    # Compute ignores.

    def ignores
    end

    # Produce hexdigest/cheksum for a file.
    # Default digest type is sha1.

    def checksum(file, digest=nil)
      return nil unless digest
      if FileTest.directory?(file)
        @null_string ||= digester(digest).hexdigest("") # TODO use other means
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


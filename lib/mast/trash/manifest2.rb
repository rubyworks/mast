module Mast
  require 'fileutils'
  require 'getoptlong'
  require 'shellwords'

  # Manifest stores a list of package files, and optionally checksums.
  #
  # The class can be used to create and compare package manifests and digests.
  #
  # TODO:
  #   - Integrate file signing and general manifest better (?)
  #   - Digester is in sign.rb too. Dry-up?
  #   - Is it problematic to add a digest to the manifest?
  #   - This needs some TLC. Eg. diff is shelling out, but it would
  #     be better if internalized.
  #   - Could just use some over all belt tightening.
  #
  class Manifest

    # Manifest file overwrite error.
    #
    class OverwriteError < Exception
    end

    # No Manifest File Error.
    #
    class NoManifestError < LoadError
    end

    DEFAULT_FILE    = 'manifest{,.txt}'
    DEFAULT_EXCLUDE = %w{ InstalledFiles .config *~ CVS _darcs .svn .git }

    # Possible file name (was for Fileable?).
    def self.filename
      DEFAULT_FILE
    end

    def self.open(file=nil, options={})
      unless file
        file = Dir.glob(filename, File::FNM_CASEFOLD).first
        raise LoadError, "Manifest file is required." unless file
      end
      options.update(:file => file)
      new(options)
    end

    # File used to store digest/manifest.
    attr_accessor :file

    # Encryption type
    attr_accessor :digest

    # Do not exclude standard exclusions.
    attr_accessor :all
    alias_method :all?, :all

    # What files to exclude from digest.
    attr_accessor :exclude
    alias_method :ignore, :exclude

    # Directory to use.
    attr_accessor :directory

    # Layout of digest, csf or sfv. Default is csf.
    attr_accessor :format

    # Files and checksums listed in file.
    attr_reader :list

    # New Digest object.
    def initialize(options={})
      #if File.directory?(location)
      #  if file = Dir[File.join(location, DEFAULT_FILE)].first
      #    @file = file
      #  else
      #  end
      #else
      #  read(@file = location)
      #end

      @exclude  = []

      change_options(options)

      #read(file) if file
      #else
        #if file = Dir.glob(self.class.filename)[0]
        #  @file = file
        #else
      #    @file = DEFAULT_FILE
        #end
      end
    end

    # Set options.
    def change_options(opts)
      opts.each do |k,v|
        k = k.to_s.downcase
        send("#{k}=",v||send(k))
      end
      #@file       = options[:file]    || @file
      #@digest     = options[:digest]  || @digest
      #@all        = options[:all]     || @all
      #@exclude    = options[:exclude] || options[:ignore] || @exclude
      #@exclude    = [@exclude].flatten.compact
    end

    #
    def file?
      @read_from_file
    end

    # Create a digest/manifest.
    def create(options=nil)
      change_options(options) if options
      generate
    end

    # Update a MANIFEST/DIGEST file.
    def update(options=nil)
      change_options(options) if options
      raise NoManifestError unless file and FileTest.file?(file)
      save
    end

    # Generate MANIFEST and save as file.
    def save #(options=nil)
      #change_options(options) if options
      File.open(file, 'w') do |f|
        f << topline_string
        output(f)
      end
      return file
    end

    # Diff file against actual files.
    # TODO: do this internally.
    def diff
      raise NoManifestError unless file and FileTest.file?(file)
      manifest = save_temporary_manifest
      begin
        result = `diff -du #{file} #{manifest.file}`
      ensure
        FileUtils.rm(manifest.file)
      end
      # pass = result.empty?
      return result
    end

    # Files listed in manifest, but not found.
    def whatsold
      #raise ManifestMissing unless file
      filelist - files
    end

    # Files found, but not listed in manifest.
    def whatsnew
      #raise ManifestMissing unless file
      files - (filelist + [filename])
    end

    # Clean non-manifest files.
    def clean
      cfiles, cdirs = clean_files.partition{ |f| !File.directory?(f) }
      FileUtils.rm(cfiles)
      FileUtils.rmdir(cdirs)
    end

    #
    def clean_files
      keep = Dir.glob('*').select{|f| File.directory?(f)}
      keep << filename # keep manifest
      Dir.glob('**/*') - (files + keep)
    end

    #     # Clobber non-manifest files.
    #     #
    #     def clobber
    #       clobber_files.each{ |f| rm_r(f) if File.exist?(f) }
    #     end
    #
    #     #--
    #     # TODO Should clobber work off the manifest file itself?
    #     #++
    #     def clobber_files
    #       keep = filelist # + [info.manifest]
    #       Dir.glob('**/*') - keep
    #     end

    # Manifest's filename.
    def filename
      File.basename(file)
    end

    # File's location.
    def location
      #if directory
      #  directory
      #if file
      #  File.dirname(file)
      #else
        @location = @directory || Dir.pwd
      #end
    end

    # List of files as given in the file.
    def filelist
      list.keys.sort
    end

    # Generate manifest.
    def generate(out=$stdout)
      out << topline_string
      output(out)
    end

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
    private :rec_output


    # List files in package.

    def files #(update=false)
      #remove = (update ? (exclude + topline.exclude) : exclude)
      #remove = exclude
      #remove += DEFAULT_EXCLUDE unless all?
      #remove += [filename, filename.chomp('~')]

      files = []
      Dir.chdir(location) do
        files += Dir.multiglob_r('**/*')
        files -= Dir.multiglob_r(exclusions)
      end
      return files
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

    # List of files in package, but omit folders.
    def files_without_folders
      files.select{ |f| !File.directory?(f) }
    end

    # Produce textual listing less the manifest file.

    def listing
      str = ''
      output(str)
      str

#       #crypt = (update ? (digest || topline.digest) : digest)
#       crypt = digest
#
#       list = files #(update) #- [filename, filename.chomp('~')]
#       list.sort!
#       list.collect!{ |file| [checksum(file,crypt), file] }
#       list.collect!{ |file| file.compact.join(' ') }
#       list.join("\n") + "\n"
    end

    # File content.

    def to_s #(update=false)
      topline_string + listing #(update) + listing(update)
    end

  private

    # Create a temporary manifest (for comparison).
    def save_temporary_manifest
      temp_manifest = Manifest.new(
        :file    => file+"~",
        :digest  => digest,
        :exclude => exclude,
        :all     => all
      )
      temp_manifest.save
      #File.open(tempfile, 'w+') do |f|
      #  f << to_s(true)
      #end
      return temp_manifest
    end

    # Remove temporary manifest.
    def remove_temporary_manifest
      FileUitls.rm(file+'~')
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

    # Read manifest file.
    def read(file)
      return unless file

      #@file = file
      #@location = File.dirname(File.expand_path(file))

      l = {}
      flist = File.read_list(file)
      flist.each do |line|
        left, right = line.split(/\s+/)
        if right
          checksum = left
          filename = right
          l[filename] = checksum
        else
          filename = left
          l[filename] = nil
        end
      end

      a, d, x = *topline_parse

      @list    = l
      @all     = a
      @digest  = d
      @exclude = x

      @read_from_file = file
    end

    # Get topline of Manifest file, parse and cache.
    #def topline
    #  @topline ||= topline_parse
    #end

    # Parse topline.
    #
    def topline_parse
      if line = read_topline
        argv = Shellwords.shellwords(line)
        ARGV.replace(argv)
        opts = GetoptLong.new(
            [ '-g', '--digest' ,             GetoptLong::REQUIRED_ARGUMENT ],
            [ '-x', '--exclude', '--ignore', GetoptLong::REQUIRED_ARGUMENT ],
            [ '-a', '--all'    ,             GetoptLong::NO_ARGUMENT ]
        )
        a, d, x = false, nil, []
        opts.each do |opt, arg|
          case opt
          when '-g': d = arg.downcase
          when '-a': a = true
          when '-x': x << arg
          end
        end
        return a, d, x
      end
    end

    # Read topline of MANIFEST file.
    #
    def read_topline
      r = nil
      #if file = locate(filename)
        File.open(file) do |f|
          s = f.readline
          if s =~ /^#!\s*(.*?)\n/
            r = $1
          end
        end
        return r
      #end
    end

    # Create topline of MANIFEST file.
    #
    def topline_string(update=false)
      if update
        a = all #|| topline.all
        d = digest #|| topline.digest
        x = exclude #+ topline.exclude
      else
        a, d, x = all, digest, exclude
      end
      top = []
      top << "-a" if a
      top << "-g #{d.to_s.downcase}" if d
      x.each do |e|
        top << "-x #{e}"
      end
      return "#!mast up #{top.join(' ')}\n"  # FIXME: use proper executable
    end

  end

end


module ProUtils

  # Metaclass extensions for core File class.
  module File

    # Is a file a gzip file?

    def gzip?( file )
      open(file,'rb') { |f|
        return false unless f.getc == 0x1f
        return false unless f.getc == 0x8b
      }
      true
    end

    # Reads in a file, removes blank lines and remarks
    # (lines starting with '#') and then returns
    # an array of all the remaining lines.
    #
    #   CREDIT: Trans

    def read_list(filepath, chomp_string='')
      farr = nil
      farr = read(filepath).split("\n")
      farr.collect! { |line|
        l = line.strip.chomp(chomp_string)
        (l.empty? or l[0,1] == '#') ? nil : l
      }
      farr.compact
    end

  end

  # Metaclass extensions for core Dir class.
  module Dir

    # Like +glob+ but can take multiple patterns.
    #
    #   Dir.multiglob( '*.rb', '*.py' )
    #
    # Rather then constants for options multiglob accepts a trailing options
    # hash of symbol keys.
    #
    #   :noescape    File::FNM_NOESCAPE
    #   :casefold    File::FNM_CASEFOLD
    #   :pathname    File::FNM_PATHNAME
    #   :dotmatch    File::FNM_DOTMATCH
    #   :strict      File::FNM_PATHNAME && File::FNM_DOTMATCH
    #
    # It also has an option for recurse.
    #
    #   :recurse     Recurively include contents of directories.
    #
    # For example
    #
    #   Dir.multiglob( '*', :recurse => true )
    #
    # would have the same result as
    #
    #   Dir.multiglob('**/*')
    #
    def multiglob(*patterns)
      options  = (Hash === patterns.last ? patterns.pop : {})

      if options.delete(:recurse)
        #patterns += patterns.collect{ |f| File.join(f, '**', '**') }
        multiglob_r(*patterns)
      end

      bitflags = 0
      bitflags |= File::FNM_NOESCAPE if options[:noescape]
      bitflags |= File::FNM_CASEFOLD if options[:casefold]
      bitflags |= File::FNM_PATHNAME if options[:pathname] or options[:strict]
      bitflags |= File::FNM_DOTMATCH if options[:dotmatch] or options[:strict]

      patterns = [patterns].flatten.compact

      if options[:recurse]
        patterns += patterns.collect{ |f| File.join(f, '**', '**') }
      end

      files = []
      files += patterns.collect{ |pattern| Dir.glob(pattern, bitflags) }.flatten.uniq

      return files
    end

    # The same as +multiglob+, but recusively includes directories.
    #
    #   Dir.multiglob_r( 'folder' )
    #
    # is equivalent to
    #
    #   Dir.multiglob( 'folder', :recurse=>true )
    #
    # The effect of which is
    #
    #   Dir.multiglob( 'folder', 'folder/**/**' )
    #
    def multiglob_r(*patterns)
      options = (Hash === patterns.last ? patterns.pop : {})
      matches = multiglob(*patterns)
      directories = matches.select{ |m| File.directory?(m) }
      matches += directories.collect{ |d| multiglob_r(File.join(d, '**'), options) }.flatten
      matches.uniq
      #options = (Hash === patterns.last ? patterns.pop : {})
      #options[:recurse] = true
      #patterns << options
      #multiglob(*patterns)
    end

  end

end

class File #:nodoc:
  extend ProUtils::File
end

class Dir #:nodoc:
  extend ProUtils::Dir
end

=begin
    #
    def manifest_file
      apply_naming_policy(@file || DEFAULT_FILE, 'txt')
    end

  private

    # Apply naming policy.
    #
    def apply_naming_policy(name, ext)
      return name unless policy
      policies = naming_policy.split(' ')
      policies.each do |polic|
        case polic
        when 'downcase'
          name = name.downcase
        when 'upcase'
          name = name.upcase
        when 'capitalize'
          name = name.capitalize
        when 'extension'
          name = name + ".#{ext}"
        when 'plain'
          name = name.chomp(File.extname(name))
        else
          name
        end
      end
      return name
    end
=end

#end # module Ratchets

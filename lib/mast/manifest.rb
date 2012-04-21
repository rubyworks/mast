module Mast
  require 'fileutils'
  require 'getoptlong'
  require 'shellwords'
  require 'mast/core_ext'

  # TODO: Integrate file signing and general manifest better (?)
  #
  # TODO: Digester is in sign.rb too. Dry-up?
  #
  # TODO: The #diff method is shelling out; this needs to be internalized.
  #
  # TODO: Consider adding @include options rather then scanning entire directory.
  # But this can't be done unless we can write a routine that can look at @include
  # and reduce it to non-overlapping matches. Eg. [doc, doc/rdoc] should reduce
  # to just [doc]. Otherwise we will get duplicate entries, b/c the #output
  # method is written for speed and low memory footprint. This might mean @include
  # can't use file globs.

  # Manifest stores a list of package files, and optionally checksums.
  #
  # The class can be used to create and compare package manifests and digests.
  #
  # Note that the #diff method currently shells out. Eventually this will be
  # internalized.
  #
  class Manifest

    # Manifest file overwrite error.
    #
    OverwriteError = Class.new(Exception)

    # No Manifest File Error.
    #
    NoManifestError = Class.new(LoadError) do
      def message; "ERROR: no manifest file"; end
    end

    # By default mast will exclude any pathname matching
    # 'CVS', '_darcs', '.git*' or '.config'.
    DEFAULT_EXCLUDE = %w{CVS _darcs .git* .config}  # InstalledFiles

    # By default, mast will ignore any file with a name matching
    # '.svn' or '*~', ie. ending with a tilde.
    DEFAULT_IGNORE  = %w{*~ .svn}

    #
    DEFAULT_FILE    = '{manifest,digest}{,.txt,.list}'

    # Possible file name (was for Fileable?).
    #def self.filename
    #  DEFAULT_FILE
    #end

    def self.open(file=nil, options={})
      unless file
        file = Dir.glob(filename, File::FNM_CASEFOLD).first
        raise NoManifestError, "Manifest file is required." unless file
      end
      options[:file] = file
      new(options)
    end

    # Directory of manifest.
    attr_accessor :directory

    # File used to store manifest/digest file.
    attr_accessor :file

    # Encryption type
    attr_accessor :digest

    # Do not exclude standard exclusions.
    attr_accessor :all

    # Include directories.
    attr_accessor :dir

    # Show as if another manifest (i.e. use file's bang options).
    attr_accessor :bang

    # Omit mast header from manifest output.
    attr_accessor :headless

    # What files to include. Defaults to ['*'].
    # Note that Mast automatically recurses through
    # directory entries, so using '**/*' would simply
    # be a waste of of processing cycles.
    attr_accessor :include

    # What files to exclude.
    attr_accessor :exclude

    # Special files to ignore.
    attr_accessor :ignore

    # Layout of digest -- 'csf' or 'sfv'. Default is 'csf'.
    attr_accessor :format

    # Files and checksums listed in file.
    #attr_reader :list

    # An IO object to output manifest. Default is `$stdout`.
    attr_accessor :io

    #
    alias_method :all?, :all

    #
    alias_method :dir?, :dir

    #
    alias_method :bang?, :bang

    #
    alias_method :headless?, :headless


    # New Manifest object.
    #
    def initialize(options={})
      @include   = ['*']
      @exclude   = []
      @ignore    = []
      @format    = 'csf'
      @all       = false
      @dir       = false
      @bang      = false
      @digest    = nil
      @directory = Dir.pwd
      @io        = $stdout

      change_options(options)

      #if @file
      #  read(@file)
      #else
        #if file = Dir.glob(self.class.filename)[0]
        #  @file = file
        #else
      #    @file = DEFAULT_FILE
        #end
      #end
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

    def include=(inc)
      @include = [inc].flatten.uniq
    end

    #
    def file
      @file ||= Dir.glob(File.join(directory, DEFAULT_FILE), File::FNM_CASEFOLD).first || 'MANIFEST'
    end

    #
    def read?
      @read
    end

    #
    def exist?
      file and FileTest.file?(file)
    end

    # Is the current mainfest in need of updating?
    def changed?
      raise NoManifestError unless exist? #file and FileTest.file?(file)
      txt = File.read(file)
      out = StringIO.new #('', 'w')
      generate(out)
      out.string != txt
    end

    # Create a digest/manifest file. This saves the list of files
    # and optionally their checksum.
    #def create(options=nil)
    #  change_options(options) if options
    #  #@file ||= DEFAULT_FILE
    #  raise OverwriteError if FileTest.file?(file)
    #  save #(false)
    #end

    # Generate manifest.
    def generate(out=nil)
      out ||= self.io
      parse_topline unless read? if bang?
      out << topline_string unless headless?
      output(out)
    end

    # Update file.
    def update
      raise NoManifestError unless file and FileTest.file?(file)
      parse_topline
      save
    end

    #
    def touch
      FileUtils.touch(file) if File.exist?(file)
    end

    # Save as file.
    def save
      File.open(file, 'w') do |f|
        f << topline_string
        output(f)
      end
      return file
    end

    # Diff file against actual files.
    #
    # TODO: Do not shell out for diff.
    #
    def diff
      raise NoManifestError unless file and FileTest.file?(file)
      parse_topline # parse_file unless read?
      manifest = create_temporary_manifest
      begin
        result = `diff -du #{file} #{manifest.file}`
      ensure
        FileUtils.rm(manifest.file)
      end
      # pass = result.empty?
      return result
    end

    # Files listed in the manifest file, but not found in file system.
    #
    def whatsold
      parse_file unless read?
      filelist - list
    end

    # Files found in file system, but not listed in the manifest file.
    def whatsnew
      parse_file unless read?
      list - (filelist + [filename])
    end

    #
    def verify
      parse_file unless read?
      chart == filechart
    end

    # Clean non-manifest files.
    def clean
      cfiles, cdirs = cleanlist.partition{ |f| !File.directory?(f) }
      if cfiles.empty? && cdirs.empty?
        $stderr < "No difference between list and actual.\n"
      else
        FileUtils.rm(cfiles)
        FileUtils.rmdir(cdirs)
      end
    end

    # List of current files.
    def list
      @list ||= chart.keys.sort
    end

    # Chart of current files (name => checksum).
    def chart
      @chart ||= parse_directory
    end

    # List of files as given in MANIFEST file.
    def filelist
      @filelist ||= filechart.keys.sort
    end

    # Chart of files as given in MANIFEST file (name => checksum).
    def filechart
      @filechart ||= parse_file
    end

    #
    def cleanlist
      showlist - filelist
    end

    # Files not listed in manifest.
    def unlisted
      list = []
      Dir.chdir(directory) do
        list = Dir.glob('**/*')
      end
      list - filelist
    end

    #
    def showlist
      parse_topline unless read?
      list
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

    # File's basename.
    def filename
      File.basename(file)
    end

  private

    #
    def output(out=nil)
      out ||= self.io
      Dir.chdir(directory) do
        exclusions  # seed exclusions
        #rec_output('*', out)
        inclusions.each do |inc|
          rec_output(inc, out)
        end
      end
    end

    # Generate listing on the fly.
    def rec_output(match, out=nil)
      out ||= self.io
      out.flush unless Array === out
      #match = (location == dir ? '*' : File.join(dir,'*'))
      files = Dir.glob(match, File::FNM_DOTMATCH) - exclusions
      # TODO: Is there a more efficient way to reject ignored files?
      #files = files.select{ |f| !ignores.any?{ |i| File.fnmatch(i, File.basename(f)) } }
      files = files.reject{ |f| ignores.any?{ |i| File.fnmatch(i, File.basename(f)) } }
      files = files.sort
      files.each do |file|
        is_dir = File.directory?(file)
        if !is_dir || (is_dir && dir?)
          sum = checksum(file,digest)
          sum = sum + ' ' if sum
          out << "#{sum}#{file}"
          out << "\n" unless Array === out
        end
        if is_dir
          rec_output(File.join(file,'*'), out)
        end
      end
      #return out
    end

    #
    def parse_directory
      h = {}
      files.each do |f|
        h[f] = checksum(f)
      end
      h
    end

    # List of files.
    #
    def files #(update=false)
      @files ||= (
        r = []
        output(r)
        r
      )
      #files = []
      #Dir.chdir(directory) do
      #  files += Dir.multiglob_r('**/*')
      #  files -= Dir.multiglob_r(exclusions)
      #end
      #return files
    end

    # Compute exclusions.
    def inclusions
      @_inclusions ||= (
        e  = [include].flatten
        #e += DEFAULT_EXCLUDE unless all?
        #e += [filename, filename.chomp('~')] if file
        e = e.map{ |x| Dir.glob(x) }.flatten.uniq
        e = File.reduce(*e)
        e
      )
    end

    # Compute exclusions.
    def exclusions
      @_exclusions ||= (
        e  = [exclude].flatten
        e += DEFAULT_EXCLUDE unless all?
        e += [filename, filename.chomp('~')] if file
        e.map{ |x| Dir.glob(x) }.flatten.uniq
      )
    end

    # Compute ignores.
    def ignores
      @_ignores ||= (
        i  = [ignore].flatten
        i += [ '.', '..' ]
        i += DEFAULT_IGNORE unless all?
        i
      )
    end

  public

    # List of files in file system, but omit folders.
    def list_without_folders
      list.select{ |f| !File.directory?(f) }
    end

    # Produce textual listing less the manifest file.
    #
    def listing
      str = ''
      output(str)
      str
    end

    #
    def to_s
      topline_string + listing
    end

  private

    # Create temporary manifest (for comparison).

    def create_temporary_manifest
      temp_manifest = Manifest.new(
        :file    => file+"~",
        :digest  => digest,
        :include => include,
        :exclude => exclude,
        :ignore  => ignore,
        :all     => all
      )
      temp_manifest.save
      #File.open(tempfile, 'w+') do |f|
      #  f << to_s(true)
      #end
      return temp_manifest
    end

    # Produce hexdigest/cheksum for a file.
    # Default digest type is sha1.

    def checksum(file, digest=nil)
      return nil unless digest
      if FileTest.directory?(file)
        #@null_string ||= digester(digest).hexdigest("")
        listing = (Dir.entries(file) - %w{. ..}).join("\n")
        digester(digest).hexdigest(listing)
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

    def parse_file
      raise ManifestMissing unless file

      parse_topline

      #@file = file
      #@location = File.dirname(File.expand_path(file))

      chart = {}
      flist = File.read_list(file)
      flist.each do |line|
        left, right = line.split(/\s+/)
        if right
          checksum = left
          filename = right
          chart[filename] = checksum
        else
          filename = left
          chart[filename] = nil
        end
      end

      @read      = true
      @filechart = chart
    end

    # Get topline of Manifest file, parse and cache.
    #def topline
    #  @topline ||= topline_parse
    #end

    # Parse topline.
    #
    def parse_topline
      if line = read_topline
        argv = Shellwords.shellwords(line)
        ARGV.replace(argv)
        opts = GetoptLong.new(
            [ '-g', '--digest' , GetoptLong::REQUIRED_ARGUMENT ],
            [ '-x', '--exclude', GetoptLong::REQUIRED_ARGUMENT ],
            [ '-i', '--ignore' , GetoptLong::REQUIRED_ARGUMENT ],
            [ '-a', '--all'    , GetoptLong::NO_ARGUMENT ]
        )
        a, d, g, x, i = false, false, nil, [], []
        opts.each do |opt, arg|
          case opt
          when '-g'
            g = arg.downcase
          when '-a'
            a = true
          when '-x'
            x << arg
          when '-i'
            i << arg
          when '-d'
            d = true
          end
        end

        @all     = a
        @digest  = g
        @exclude = x
        @ignore  = i
        @dir     = d
        @include = ARGV.empty? ? nil : ARGV.dup
      end
    end

    # Read topline of MANIFEST file.
    #
    def read_topline
      r = nil
      #if file = locate(filename)
        File.open(file) do |f|
          s = f.readline
          if s =~ /^#!mast\s*(.*?)\n/
            r = $1
          end
        end
        return r
      #end
    end

    # Create topline of MANIFEST file.
    #
    def topline_string(update=false)
      #if update
      #  a = all #|| topline.all
      #  d = digest #|| topline.digest
      #  x = exclude #+ topline.exclude
      #else
      #  a, d, x = all, digest, exclude
      #end
      top = []
      top << "-a" if all?
      top << "-d" if dir?
      top << "-g #{digest.to_s.downcase}" if digest
      exclude.each do |e|
        top << "-x #{e}"
      end
      ignore.each do |e|
        top << "-i #{e}"
      end
      include.each do |e|
        top << e
      end
      return "#!mast #{top.join(' ')}\n"  # FIXME: use proper executable
    end

  end

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

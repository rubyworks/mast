#  mast v1.0.0
#
#  Usage:
#    mast [command] [options...]
#
#  The manifest listing tool is used to list, create or update a
#  manifest for a directory (eg. to define a "package"), or compare
#  a manifest to actual directory contents. Mast is part of the
#  ProUtils set of tools.
#
#  When no command is given, a manifest is dumped to standard out.
#  If --file is specified, it will generate to that file instead.
#
#  Examples:
#    mast
#    mast -u -f PUBLISH
#
#  Commands:
#    -c --create         Generate a new manifest. (default)
#    -u --update         Update an existing manifest.
#    -l --list           List the files given in the manifest file. (Use -f to specify an alternate file.)
#    -d --diff           Diff manifest file against actual.
#    -n --new            List existant files that are not given in the manifest.
#    -o --old            List files given in the manifest but are non-existent.
#       --clean          Remove non-manifest files. (Will ask for confirmation first.)
#    -v --verify         Verify that a manifest matches actual.
#    -h --help           Display this help message.
#
#  Options:
#    -a --all            Include all files. This deactivates deafult exclusions
#                        so it is possible to make complete list of all contents.
#       --dir            When creating a list include directory paths; by default
#                        only files are listed.
#    -s --show           Show files using the options from the manifest file.
#    -f --file PATH      Path to manifest file. When using update command, if not
#                        given then the file matching 'MANIFEST', case-insensitive
#                        and with an optional '.txt' extension, will be looked for
#                        in the current directory. If the path of the manifest file
#                        is anything else then --file option must be specified.
#    -g --digest TYPE    Include crytogrpahic signiture. Type can be either
#                        md5, sha1, sha128, sha256, or sha512.
#    -x --exclude PATH   Exclude a file or dir from the manifest matching against
#                        full pathname. You can use --exclude repeatedly.
#    -i --ignore PATH    Exclude a file or dir from the manifest matching against 
#                        an entries basename. You can use --ignore repeatedly.
#    -q --quiet          Suppress extraneous output.

require 'mast'

# both of these can be replaced by using Clio instead.
require 'getoptlong'
require 'facets/kernel/ask'

module Mast

  ARGVO = ARGV.dup

  # Manifest Console Command
  #
  class Cli

    def self.run
      new.run
    end

    DIGESTS = [:md5, :sha1, :sha128, :sha256, :sha512]

    attr_accessor :quiet
    attr_accessor :file
    attr_accessor :digest
    attr_accessor :ignore
    attr_accessor :include
    attr_accessor :exclude
    attr_accessor :all
    attr_accessor :dir
    attr_accessor :show

    #
    def initialize
      @quiet   = false
      @all     = false
      @file    = nil
      @digest  = nil
      @exclude = []
      @include = []
      @ignore  = []
      @command = []
    end

    #
    def run
      begin
        run_command
      rescue => err
        raise err if $DEBUG
        report err
      end
    end

    # Run command.
    def run_command
      optparse
      if @command.size > 1
        raise ArgumentError, "Please issue only one command."
      end
      case @command.first
      when :help     then help
      when :create   then generate
      when :update   then update
      when :list     then list
      #when :show     then show
      when :diff     then diff
      when :new      then new
      when :old      then old
      when :verify   then verify
      when :clean    then clean
      else
        generate
      end
    end

    # Parse command line options.
    def optparse
      opts = GetoptLong.new(
        # options
        [ '--file'   , '-f', GetoptLong::REQUIRED_ARGUMENT ],
        [ '--digest' , '-g', GetoptLong::REQUIRED_ARGUMENT ],
        [ '--exclude', '-x', GetoptLong::REQUIRED_ARGUMENT ],
        #[ '--include', '-i', GetoptLong::REQUIRED_ARGUMENT ],
        [ '--ignore' , '-i', GetoptLong::REQUIRED_ARGUMENT ],
        [ '--all'    , '-a', GetoptLong::NO_ARGUMENT ],
        [ '--dir'    ,       GetoptLong::NO_ARGUMENT ],
        [ '--show'   , '-s', GetoptLong::NO_ARGUMENT ],
        [ '--quiet'  , '-q', GetoptLong::NO_ARGUMENT ],
        # commands
        [ '--help'   , '-h', GetoptLong::NO_ARGUMENT ],
        [ '--create' , '-c', GetoptLong::NO_ARGUMENT ],
        [ '--update' , '-u', GetoptLong::NO_ARGUMENT ],
        [ '--list'   , '-l', GetoptLong::NO_ARGUMENT ],
        [ '--diff'   , '-d', GetoptLong::NO_ARGUMENT ],
        [ '--new'    , '-n', GetoptLong::NO_ARGUMENT ],
        [ '--old'    , '-o', GetoptLong::NO_ARGUMENT ],
        [ '--verify' , '-v', GetoptLong::NO_ARGUMENT ],
        [ '--clean'  ,       GetoptLong::NO_ARGUMENT ]
      )

      opts.each do |key, val|
        case key
        when '--help'
          @command << :help
        when '--create'
          @command << :create
        when '--update'
          @command << :update
        when '--list'
          @command << :list
        #when '--show'
        #  @command << :show
        when '--diff'
          @command << :diff
        when '--new'
          @command << :new
        when '--old'
          @command << :old
        when '--verify'
          @command << :verify
        when '--clean'
          @command << :clean

        when '--file'
          @file = val
        when '--digest'
          @digest = val
        when '--exclude'
          @exclude << val
        #when '--include'
        #  @include << val
        #when '--ignore'
        #  @ignore << val
        when '--show'
          @show = true
        when '--dir'
          @dir = true
        when '--all'
          @all = true
        when '--quiet'
          @quiet = true
        end
      end

      #unless args.empty?
      #  if File.file?(args[0])
      #    opts[:file]      = args[0]
      #    opts[:directory] = args[1] if args[1]
      #  else
      #    opts[:directory] = args[0]
      #    opts[:file]      = args[1] if args[1]
      #  end
      #end

      @include = ARGV.empty? ? nil : ARGV.dup
    end

    #def default; generate; end

    # Default command -- output manifest.
    #
    def generate
      #if file
      #  update
      #else
        manifest.generate
      #end
    end

    # Update a MANIFEST file for this package.
    #
    def update
      begin
        file = manifest.update
      rescue NoManifestError => e
        puts e.message
        exit -1
      end
      report_updated(file)
    end

    alias_method :up, :update

    # List files in manifest file.
    def list
      puts manifest.filelist
    end

    #
    #def show
    #  puts manifest.showlist
    #end

    # Show diff comparison between listed and actual.
    def diff
      result = manifest.diff
      report_difference(result)
    end

    # Files listed in manifest, but not found.
    def old
      list = manifest.whatsold
      unless list.empty?
        report_whatsold(list)
      end
    end

    # Files found, but not listed in manifest.
    def new
      list = manifest.whatsnew
      unless list.empty?
        report_whatsnew(list)
      end
    end

    #
    def verify
      check = manifest.verify
      report_verify(check)
      exit -1 unless check
    end

    # Clean (or clobber if you prefer) non-manifest files.
    def clean
      answer = confirm_clean(manifest.cleanlist)
      case answer.downcase
      when 'y', 'yes'
        manifest.clean
      else
        report_cancelled('Clean')
        exit!
      end
    end

    # Display command help information.
    def help
      report_help
    end

  private

    #
    def manifest
      @manifest ||= Manifest.new(manifest_options)
      #@manifest ||= (
      #  begin
      #    manifest = Manifest.open(file, manifest_options)
      #    manifest
      #  rescue LoadError
      #    report_manifest_missing
      #    exit 0
      #  end
      #)
    end

    # Options for Manifest class taken from commandline arguments.
    def manifest_options
      { :file=>file, :digest=>digest, :exclude=>exclude, :ignore=>ignore, :all=>all, :dir=>dir, :include=>include, :show=>show }
    end

    # Quiet opertation?
    def quiet?
      @quiet
    end

    # Get confirmation for clean.
    def confirm_clean(list)
      puts list.join("\n")
      ask("The above files will be removed. Continue?", "yN")
    end

    # Get confirmation for clobber.
    def confirm_clobber(list)
      puts list.join("\n")
      ask("The above files will be removed. Continue?", "yN")
    end

    #
    def report(message)
      $stderr << "#{message}\n" unless quiet?
    end

    # Report manifest created.
    def report_created(file)
      file = File.basename(file)
      report "#{file} created."
    end

    # Report manifest updated.
    def report_updated(file)
      if file
        file = File.basename(file)
        report "#{file} updated."
      else
        report "Manifest file doesn't exit."
      end
    end

    # Display diff between file and actual.
    #--
    # TODO What about checkmode?
    #++
    def report_difference(result)
      output = nil
      if pass = result.empty?
        if @checkmode
          output = justified('Manifest', '[PASS]') + "\n"
        else
          #"Manifest is current."
        end
      else
        output = result
      end
      puts output if output
    end

    # Report missing manifest file.
    def report_whatsnew(list)
      puts list.join("\n")
    end

    #
    def report_whatsold(list)
      puts list.join("\n")
    end

    # Show help.
    def report_help
      doc = false
      File.readlines(__FILE__).each do |line|
        line = line.strip
        break if doc && line.empty?
        next if line =~ /^#!/
        next if line.empty?
        puts line[1..-1].sub(/^\ \ /,'')
        doc = true
      end
    end

    # Report missing manifest file.
    def report_manifest_missing
      report "No manifest file."
    end

    # Report action cancelled.
    def report_cancelled(action)
      report "#{action} cancelled."
    end

    # Report manifest overwrite.
    def report_overwrite(manifest)
      report "#{manifest.filename} already exists."
    end

    # Warn that a manifest already exist higher in this hierarchy.
    def report_warn_shadowing(manifest)
      report "Shadowing #{manifest.file}."
    end

    #
    def report_verify(check)
      if check
        report "Manifest if good."
      else
        report "Manifest if bad!"
      end
    end
  end

end

=begin scrap

#     # Lookup manifest.
#
#     def manifest(create_missing=false)
#       @manifest ||= (
#         file = @options[:file]
#         #manifest = file ? Manifest.open(file) : Manifest.lookup
#         manifest = nil
#
#         if file
#           manifest = Manifest.open(file, @options)
#         elsif create_missing
#           manifest = Manifest.new(@options)
#         else
#           manifest = nil
#         end
#
#         if manifest
#           #manifest.send(:set, @options)
#         else
#           report_manifest_missing
#           exit 0
#         end
#         manifest
#       )
#     end

#       @manifest ||= (
#         file = @options[:file]
#         #manifest = file ? Manifest.open(file) : Manifest.lookup
#         manifest = nil
#
#         if file
#           manifest = Manifest.open(file)
#         elsif create_missing
#           manifest = Manifest.new
#         else
#           manifest = nil
#         end
#
#         if manifest
#           manifest.change_options(@options)
#         else
#           report_manifest_missing
#           exit 0
#         end
#         manifest
#       )
#     end

#     # Generate manifest. By default it is a very simple filename
#     # list. The digest can be supplied and a checksum will
#     # be given before each filename.
#
#     def create
#       manifest = Manifest.new #lookup
#
#       return report_overwrite(manifest) if (
#         manifest and manifest.location == Dir.pwd
#       )
#
#       report_warn_shadowing(manifest) if manifest
#
#       manifest = Manifest.new(options)
#       file = manifest.create
#       report_created(file)
#     end

#     # Clobber non-manifest files.
#     #--
#     # TODO Should clobber work off the manifest file itself
#     #++
#
#     def clobber
#       ansr = confirm_clobber(manifest.toss)
#       case ansr.downcase
#       when 'y', 'yes'
#         manifest.clobber
#       else
#         report_cancelled('Clobber')
#         exit!
#       end
#     end

=end


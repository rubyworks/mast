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
#    -D --diff           Diff manifest file against actual.
#    -n --new            List existant files that are not given in the manifest.
#    -o --old            List files given in the manifest but are non-existent.
#       --clean          Remove non-manifest files. (Will ask for confirmation first.)
#    -v --verify         Verify that a manifest matches actual.
#    -h --help           Display this help message.
#
#  Options:
#    -a --all            Include all files. This deactivates deafult exclusions
#                        so it is possible to make complete list of all contents.
#    -d --dir            When creating a list include directory paths; by default
#                        only files are listed.
#    -s --show           Show actual files using the options from the manifest file.
#    -f --file PATH      Path to manifest file. This applies to comparison commands.
#                        If not given then the file matching 'MANIFEST', case-insensitive
#                        and with an optional '.txt' extension, in the current directory
#                        is used. If the path of the manifest file is anything else then
#                        the --file option must be specified.
#    -g --digest TYPE    Include crytographic signiture. Type can be either
#                        md5, sha1, sha128, sha256, or sha512.
#    -x --exclude PATH   Exclude a file or dir from the manifest matching against
#                        full pathname. You can use --exclude repeatedly.
#    -i --ignore PATH    Exclude a file or dir from the manifest matching against 
#                        an entries basename. You can use --ignore repeatedly.
#    -q --quiet          Suppress any extraneous output.

require 'mast'
require 'optparse'

module Mast

  #ARGVO = ARGV.dup

  # Manifest Console Command
  #
  class Cli

    def self.run
      new.run
    end

    DIGESTS = [:md5, :sha1, :sha128, :sha256, :sha512]

    attr_accessor :quiet

    # Options for Manifest class taken from commandline arguments.
    attr :options

    #
    def initialize
      @options = {}
      @options[:all]     = false
      @options[:file]    = nil
      @options[:show]    = nil
      @options[:digest]  = nil
      @options[:exclude] = []
      @options[:ignore]  = []
      @options[:include] = []

      @command = []

      @quiet = false
    end

    #
    def run(argv=nil)
      begin
        run_command(argv)
      rescue => err
        raise err if $DEBUG
        report err
      end
    end

    # Run command.
    def run_command(argv)
      argv = (argv || ARGV).dup
 
      @original_arguments = argv.dup

      option_parser.parse!(argv)

      @options[:include] = argv.empty? ? nil : argv #.dup

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
    # TODO: rename --show ?
    def option_parser
      OptionParser.new do |opt|
        opt.on "--file", "-f FILE" do |file|
          @options[:file] = file
        end
        opt.on "--digest", "-g TYPE" do |digest|
          @options[:digest] = digest
        end
        opt.on "--exclude", "-x GLOB" do |glob|
          @options[:exclude] << glob
        end
        opt.on "--ignore", "-i GLOB" do |glob|
          @options[:ignore] << glob
        end
        opt.on "--all", "-a" do |bool|
          @options[:all] = true
        end
        opt.on "--show", "-s" do |bool|
          @options[:show] = true
        end
        opt.on "--dir", "-d" do |bool|
          @options[:dir] = bool
        end
        #opt.on "--quiet", "-q", "" do |bool|
        #  @quiet = bool
        #end
        opt.on "--create", "-c" do
          @command << :create
        end
        opt.on "--update", "-u" do
          @command << :update
        end
        opt.on "--list", "-l" do
          @command << :list
        end
        opt.on "--diff", "-D" do
          @command << :diff
        end
        opt.on "--new", "-n" do
          @command << :new
        end
        opt.on "--old", "-o" do
          @command << :old
        end
        opt.on "--verify", "-v" do
          @command << :verify
        end
        opt.on "--clean" do
          @command << :clean
        end
        opt.on "--help" do
          @command << :help
        end
        opt.on "--debug" do
          $DEBUG = true
        end
      end
    end

    # Default command -- output manifest.
    def generate
      #if file
      #  update
      #else
        manifest.generate
      #end
    end

    # Update a MANIFEST file for this package.
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
      @manifest ||= Manifest.new(options)
      #@manifest ||= (
      #  begin
      #    manifest = Manifest.open(file, options)
      #    manifest
      #  rescue LoadError
      #    report_manifest_missing
      #    exit 0
      #  end
      #)
    end

    # Quiet opertation?
    def quiet?
      @quiet
    end

    # Get confirmation for clean.
    def confirm_clean(list)
      puts list.join("\n")
      ask("The above files will be removed. Continue? [yN]")
    end

    # Get confirmation for clobber.
    def confirm_clobber(list)
      puts list.join("\n")
      ask("The above files will be removed. Continue? [yN]")
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
        report "Manifest is good."
      else
        report "Manifest is bad!"
      end
    end

    #
    def ask(prompt=nil)
      $stdout << "#{prompt}"
      $stdout.flush
      $stdin.gets.chomp!
    end

  end

end

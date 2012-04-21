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
      @options[:bang]    = nil
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
      when :diff     then diff
      when :new      then new
      when :old      then old
      when :verify   then verify
      when :clean    then clean
      when :recent   then recent
      else
        generate
      end
    end

    # Parse command line options.
    def option_parser
      OptionParser.new do |opt|
        opt.on "-f", "--file FILE", "Path to manifest file. Looks for file matching /MANIFEST(|.txt)/i by default." do |file|
          @options[:file] = file
        end
        opt.on "-g", "--digest TYPE", "Include cryptographic signature. Type can be either md5, sha1, sha128, sha256, or sha512." do |digest|
          @options[:digest] = digest
        end
        opt.on "-x", "--exclude GLOB", "Exclude file or dir from the manifest matching against full pathname. Can be used repeatedly." do |glob|
          @options[:exclude] << glob
        end
        opt.on "-i", "--ignore GLOB",
               "Exclude file or dir from manifest matching against an entry's basename. Can be used repeatedly." do |glob|
          @options[:ignore] << glob
        end
        opt.on "-a", "--all", "Include all files. This deactivates default exclusions so it is possible to make complete list of all contents." do |bool|
          @options[:all] = true
        end
        opt.on "--bang", "-b", "Generate manifest using the options from the bang line of the manifest file." do |bool|
          @options[:bang] = true
        end
        opt.on "--dir", "-d", "When creating a list include directory paths; by default only files are listed." do |bool|
          @options[:dir] = bool
        end
        opt.on "--[no-]head", "Suppress mast header from output." do |bool|
          @options[:headless] = !bool
        end
        opt.on "-c", "--create", "Generate a new manifest. (default)" do
          @command << :create
        end
        opt.on "-u", "--update", "Update an existing manifest." do
          @command << :update
        end
        opt.on "-l", "--list", "List the files given in the manifest file. (Use -f to specify an alternate file.)" do
          @command << :list
        end
        opt.on "-D", "--diff", "Diff manifest file against actual." do
          @command << :diff
        end
        opt.on "-n", "--new", "List existent files that are not given in the manifest." do
          @command << :new
        end
        opt.on "-o", "--old", "List files given in the manifest but are non-existent." do
          @command << :old
        end
        opt.on "-v", "--verify", "Verify that a manifest matches actual." do
          @command << :verify
        end
        opt.on "--clean", "Remove non-manifest files. (Will ask for confirmation first.)" do
          @command << :clean
        end
        opt.on "-r", "--recent", "Verify that a manifest is more recent than actual." do
          @command << :recent
        end
        opt.on "-h", "--help", "Display this help message." do
          @command << :help
        end
        opt.on "-H" do
          puts opt; exit
        end
        opt.on "-q", "--quiet", "Suppress all extraneous output." do
          @quiet = true
        end
        opt.on "--debug", "Run in debug mode." do
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
      if manifest.verify
        manifest.touch
      else
        begin
          diff = manifest.diff
          file = manifest.update
        rescue Manifest::NoManifestError => e
          puts e.message
          exit -1
        end
        report_difference(diff)
        #report_updated(file)
      end
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

    # Verify manifest, then check to see that it is not older than files
    # it lists.
    def recent
      check = manifest.verify
      if !check
        report_verify(check)
        exit -1 
      end
      if !FileUtils.uptodate?(manifest.file, manifest.filelist)
        report_outofdate
        exit -1
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
      man_page  = File.dirname(__FILE__) + '/../../man/man1/mast.1'
      ronn_file = File.dirname(__FILE__) + '/../../man/man1/mast.1.ronn'
      if File.exist?(man_page)
        system "man #{man_page}" || puts(File.read(ronn_file))
      else
        puts option_parser
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
    def report_outofdate
      report "Manifest is older than listed file(s)."
    end

    #
    def ask(prompt=nil)
      $stdout << "#{prompt}"
      $stdout.flush
      $stdin.gets.chomp!
    end

  end

end

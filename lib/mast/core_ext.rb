# Metaclass extensions for core File class.
#
class File #:nodoc:

  # Is a file a gzip file?
  #
  def self.gzip?(file)
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
  def self.read_list(filepath, chomp_string='')
    farr = nil
    farr = read(filepath).split("\n")
    farr.collect! { |line|
      l = line.strip.chomp(chomp_string)
      (l.empty? or l[0,1] == '#') ? nil : l
    }
    farr.compact
  end

  # Return the path shared.
  def self.sharedpath(file1, file2)
    afile1 = file1.split(/\/\\/)
    afile2 = file2.split(/\/\\/)
    overlap = []
    i = 0; e1, e2 = afile1[i], afile2[i]
    while e1 && e2 && e1 == e2
      overlap << e1
      i += 1; e1, e2 = afile1[i], afile2[i]
    end
    return overlap.empty? ? false : overlap
  end

  # Is path1 a parent directory of path2.
  def self.parent?(file1, file2)
    return false if File.identical?(file1, file2)
    afile1 = file1.split(/(\/|\\)/)
    afile2 = file2.split(/(\/|\\)/)
    overlap = []
    i = 0; e1, e2 = afile1[i], afile2[i]
    while e1 && e2 && e1 == e2
      overlap << e1
      i += 1; e1, e2 = afile1[i], afile2[i]
    end
    return (overlap == afile1)
  end

  # Reduce a list of files so there is no overlapping
  # directory entries. This is useful when recursively
  # descending a directory listing, so as to avoid and
  # repeat entries.
  #
  # TODO: Maybe globbing should occur in here too?
  #
  def self.reduce(*list)
    # TODO: list = list.map{ |f| File.cleanpath(f) }
    newlist = list.dup
    list.each do |file1|
      list.each do |file2|
        if parent?(file1, file2)
          newlist.delete(file2)
        end
      end
    end
    newlist
  end

end

# Metaclass extensions for core Dir class.
#
class Dir #:nodoc:

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
  def self.multiglob(*patterns)
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
  def self.multiglob_r(*patterns)
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

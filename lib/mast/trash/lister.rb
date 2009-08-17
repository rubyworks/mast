module Mast

  # Lister simple opens a current MANIFEST file and dumps
  # it's contents to standard out.
  #
  class Lister
    DEFAULT = 'MANIFEST{,.txt}'

    attr_accessor :file

    # Generate manifest listing.

    def list
      glob = file || DEFAULT
      file = Dir[glob].first
      raise "no manifest" unless file
      File.open(file, 'r') do |f|
        $stdout << f.read
      end
    end
  end

end


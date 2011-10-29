require 'fileutils'
require 'mast'

Before :demo do
  if /tmp\/qed$/ =~ Dir.pwd
    Dir['*'].each do |file|
      FileUtils.rm_r(file)
    end
  end
end

When "Lets say we have a directory containing a set of files as follows" do |text|
  text.lines.each do |line|
    file = line.strip
    FileUtils.mkdir_p(File.dirname(file))
    File.open(file, 'w') do |f|
      f << file
    end
  end
end



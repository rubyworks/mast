require 'fileutils'
require 'open3'

def assert_bash(text)
  lines  = text.lines.to_a
  bash   = lines[0]
  result = lines[1..-1].join.strip

  bash.sub!('$', '')

  stdin, stdout, stderr = Open3.popen3(bash)

  #output = (stderr.read + stdout.read).strip
  output = stdout.read.strip

  result = result.split("\n").sort
  output = output.split("\n").sort

  result.assert == output
end

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

When "let's say we have a new file" do |text|
  text.lines.each do |line|
    file = line.strip
    FileUtils.mkdir_p(File.dirname(file))
    File.open(file, 'w') do |f|
      f << file
    end
  end
end

When "let's remove a file" do |text|
  text.lines.each do |line|
    file = line.strip
    FileUtils.rm(file)
  end
end

When :data do |step|
  text = step.sample_text
  if text.start_with?('$')
    assert_bash(text)
  end
end



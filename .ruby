--- 
name: mast
company: RubyWorks
title: Mast
contact: trans <transfire@gmail.com>
requires: 
- group: 
  - build
  name: syckle
  version: 0+
- group: 
  - test
  name: qed
  version: 0+
resources: 
  repo: git://github.com/rubyworks/mast.git
  code: http://github.com/rubyworks/mast/
  mail: http://groups.google.com/group/rubyworks-mailinglist
  home: http://rubyworks.github.com/mast/
  wiki: http://wiki.github.com/rubyworks/mast/
pom_verison: 1.0.0
manifest: 
- .ruby
- bin/mast
- lib/mast/cli.rb
- lib/mast/core_ext.rb
- lib/mast/manifest.rb
- lib/mast.rb
- lib/mast.yml
- lib/plugins/syckle/mast.rb
- man/man1/mast.1
- HISTORY.rdoc
- LICENSE
- README.rdoc
- VERSION
version: 1.3.0
copyright: Copyright (c) 2009 Thomas Sawyer
description: Mast is a command line tool for generating manifests and digests. Mast makes it easy to compare a manifest to a current directory structure, and to update the manifest with a simple command by storing the command options it the manifest file itself.
summary: Mast is a command line tool for generating manifests and digests.
authors: 
- Thomas Sawyer
created: 2009-08-17

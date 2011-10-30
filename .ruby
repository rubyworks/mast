---
source:
- meta
authors:
- name: Trans
  email: transfire@gmail.com
copyrights:
- holder: Thomas Sawyer
  year: '2009'
replacements: []
alternatives: []
requirements:
- name: detroit
  groups:
  - build
  development: true
- name: qed
  groups:
  - test
  development: true
dependencies: []
conflicts: []
repositories:
- uri: git://github.com/rubyworks/mast.git
  scm: git
  name: upstream
resources:
  home: http://rubyworks.github.com/mast/
  code: http://github.com/rubyworks/mast/
  mail: http://groups.google.com/group/rubyworks-mailinglist
extra: {}
load_path:
- lib
revision: 0
created: '2009-08-17'
summary: Mast is a command line tool for generating manifests and digests.
title: Mast
version: 1.4.0
name: mast
description: ! 'Mast is a command line tool for generating manifests and digests.
  Mast makes

  it easy to compare a manifest to a current directory structure, and to update

  the manifest with a simple command by storing the command options it the

  manifest file itself.'
organization: rubyworks
date: '2011-10-30'

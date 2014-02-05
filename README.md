Curriculum Alignment Tool (CAT) Puppet Module
-------------------

This module installs CAT with Apache, Tomcat and MySQL. It will clone the CAT git repo and compile the code into a war file, and then deploy the file into Tomcat contianer. Whenever a configuration file is changed, the module will recompile the CAT and redeploy the war file as the configurations are written in the source directory.

Tested with uppet 3.4 under RHEL 6.5

NOTE: The SQL for creating the structures and admin account still need to be manually executed.

Dependencies
------------
puppet-module/puppetlabs-apache
puppet-module/git
puppet-module/vcsrepo
puppet-module/evenup-tomcat

# puppetize
Script used to add agents to a Puppet enclave

Assumptions:
- You have set up a Puppet master and have a working knowledge of how Puppet works
- You are using SIMP to harden your OS (https://download.simp-project.com/simp/ISO/tar_bundles/SIMP-6.3.1-0.el7-CentOS-7-x86_64.tar.gz)
- You are using CentOS or a similar flavor of Linux

TODO:
- Add a variable that strips the domain out of the hostname variable (e.g. web1.mydomain.dev.com -> mydomain.dev.com) and replace all instances of *** with that variable

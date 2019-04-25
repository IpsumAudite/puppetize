#!/bin/bash
#Script to add new machine into enclave and puppetize it
#Run as root

#Show user how to use the script
function printHelp {
  echo "[INFO] Usage instructions"
  echo "[INFO] ./puppetize.sh <hostname> <username> <puppet IP>"
  echo "[INFO] example: ./puppetize.sh web1.mydomain.dev.com shifu 192.128.93.118"
}

#Validate user input to the script
function validateInputParameters {
  if [ $# -ne 3 ]; then
    echo "[ERROR] Expected a hostname, a username, and puppet's IP address"
    printHelp
    exit
  else
    #Create variables
    HOSTNAME=$1
    echo " "
    echo "[INFO] The hostname will be set to $HOSTNAME"
    MY_IP=$(ifconfig -a | grep inet | awk '{print $2}' | sed -n '1p')
    echo " "
    echo "[INFO] The IP address of this machine is $MY_IP"
    USERNAME=$2
    echo "[INFO] The username will be $USERNMAE"
    PUPPET_IP=$3
    echo " "
    echo "[INFO] The IP of Puppet is $PUPPET_IP"
    mainFunc
  fi
}

#Call the functions to puppetize the machine or move on to the reboot phase
function mainFunc {
  if [ -f ~/runAgain.txt ]; then
    echo " "
    echo "[INFO] running puppet agent..."
    puppet agent -t
    echo " "
    echo "[ATTENTION] Log in to puppet, run the command 'puppet cert sign $HOSTNAME',"
    echo "[ATTENTION] add '$HOSTNAME' to '/var/simp/environments/simp/FakeCA/togen' file, and"
    echo "[ATTENTION] run 'cd /var/simp/environments/simp/FakeCA/; ./gencerts_nopass.sh' before continuing."
    echo " "
    read -p "[INPUT] Did you take the steps listed above? (y/n) " -r
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo " "
    echo "[INFO] running puppet agent..."
    echo " "
    puppet agent -t
    echo "[INFO] RUnning puppet agent again..."
    puppet agent -t
    rebootServer2
  else
    echo "[INFO] Please log in to puppet, sign the cert, add the hostname to the togen file,"
    echo "[INFO] and run the gencerts_nopass.sh file."
    echo "[INFO] Then come back and run the script again"
    exit
  fi
  elif [ -f ~/goodToGo.txt ]; then
    echo " "
    echo "[INFO] deleting ec2-user and maintuser..."
    userdel -r ec2-user; userdel -r maintuser
    echo " "
    echo "[INFO] Running puppet agent a final time..."
    puppet agent -t
    echo "[INFO] This machine has been puppetized."
    echo "[INFO] You should continue to run puppet agent and clear any errors."
    echo "[INFO] Do not forget to log in to Puppet and add DNS entries for me!"
    echo "[INFO] I will make it easy for you - my hostname is $HOSTNAME and my IP is $MY_IP"
    echo "[INFO] and the files you need to update are located under the following paths:"
    echo "                  /var/simp/environments/simp/rsync/RedHat/7/bind_dns/default/named/var/named/forward"
    echo "                  /var/simp/environments/simp/rsync/RedHat/7/bind_dns/default/named/var/named/reverse"
    echo " "
    echo "[INFO] Removing ~/goodToGo.txt and ~/puppetize.sh..."
    rm -f ~/goodToGo.txt; rm -f ~/puppetize.sh
    exit
  else
    setHostname
    rewriteHostsFile
    uninstallOldPuppet
    removeCloudConfigs
    allowPasswordAuth
    addUser
    updateVisudo
    populateCustomRepo
    installPuppet
    updatePuppetConfFile
    rebootServer1
  fi
}

#Set the hostname
function setHostname {
  echo " "
  echo "[INFO] setting the hostname..."
  hostnamectl set-hostname $HOSTNAME
  hostname $HOSTNAME
  sed -ie "s|^HOSTNAME=.*|HOSTNAME=$HOSTNAME|" /etc/sysconfig/network
}

#Add puppet to the /etc/hosts file, overwriting what was there
function rewriteHostsFile {
  echo " "
  echo "[INFO] Re-writing the /etc/hosts file..."
  echo "127.0.0.1 localhost localhost.localdomain localhost4 localhost4.localdomain4" > /etc/hosts
  echo "::1 localhost localhost.localdomain localhost6 localhost6.localdomain6" >> /etc/hosts
  echo "$PUPPET_IP puppet simp puppet.test.com" >> /etc/hosts
}

#Uninstall standard puppet install
function uninstallOldPuppet {
  echo " "
  echo "[INFO] Uninstalling puppet..."
  yum remove puppet
  rm -rf /etc/puppetlabs
}

#Remove unwanted cloud configs
function removeCloudConfigs {
  echo " "
  echo "[INFO] Removing unwanted cloud configurations..."
  touch /etc/cloud/cloud.cfg.d/90_unmanage.cfg
  echo "preserve_hostname: true" > /etc/cloud/cloud.cfg.d/90_unmanage.cfg
  echo "manage_etc_hosts: false" >> /etc/cloud/cloud.cfg.d/90_unmanage.cfg
}

#Allow password authentication
function allowPasswordAuth {
  echo " "
  echo "[INFO] Allowing password authentication..."
  sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
}

#Add a local user
function addUser {
  echo " "
  echo "[INFO] Adding user $USERNAME..."
  useradd $USERNAME
  passwd $USERNAME
}

#Add $USERNAME to /etc/sudoers so it will have root permissions
function updateVisudo {
  echo " "
  echo "[INFO] Updating visudo to give $USERNAME root access..."
  echo " " >> /etc/sudoers
  echo "## Allow $USERNAME to run any commands from anywhere" >> /etc/sudoers
  echo "$USERNAME     ALL=(ALL)     NOPASSWD:ALL" >> /etc/sudoers
}

#Populate the new custom.repo file
function populateCustomRepo {
  echo " "
  echo "[INFO] Removing current yum repo files..."
  rm -f /etc/yum.repos.d/*.repo
  echo " "
  echo "[INFO] Adding Puppet-REPO..."
  #Repo for puppet files and dependencies
  echo "[Puppet-REPO]" >> /etc/yum.repos.d/custom.repo
  echo "name=Puppet-REPO" >> /etc/yum.repos.d/custom.repo
  echo "baseurl=http://$PUPPET_IP/local-repo/" >> /etc/yum.repos.d/custom.repo
  echo "enabled=1" >> /etc/yum.repos.d/custom.repo
  echo "gpgcheck=0" >> /etc/yum.repos.d/custom.repo
}

#Install puppet-agent
function installPuppet {
  echo " "
  echo "[INFO] installing puppet agent..."
  yum clean all
  yum -y install puppet-agent
}

#Update the puppet conf file
function updatePuppetConfFile {
  echo " "
  echo "[INFO] updating the puppet conf file..."
  echo "[main]" > /etc/puppetlabs/puppet/puppet.conf
  echo "trusted_server_facts = true" >> /etc/puppetlabs/puppet/puppet.conf
  echo "freeze_main = false" >> /etc/puppetlabs/puppet/puppet.conf
  echo "splay = false" >> /etc/puppetlabs/puppet/puppet.conf
  echo "syslogfacility = local6" >> /etc/puppetlabs/puppet/puppet.conf
  echo "srv_domain = test.com" >> /etc/puppetlabs/puppet/puppet.conf
  echo "certname = $HOSTNAME" >> /etc/puppetlabs/puppet/puppet.conf
  echo "vardir = /opt/puppetlabs/puppet/cache" >> /etc/puppetlabs/puppet/puppet.conf
  echo "classfile = \$vardir/classes.txt" >> /etc/puppetlabs/puppet/puppet.conf
  echo "confdir = /etc/puppetlabs/puppet" >> /etc/puppetlabs/puppet/puppet.conf
  echo "logdir = /var/log/puppetlabs/puppet" >> /etc/puppetlabs/puppet/puppet.conf
  echo "rundir = /var/run/puppetlabs" >> /etc/puppetlabs/puppet/puppet.conf
  echo "runinterval = 1800" >> /etc/puppetlabs/puppet/puppet.conf
  echo "ssldir = /etc/puppetlabs/puppet/ssl" >> /etc/puppetlabs/puppet/puppet.conf
  echo "stringify_facts = false" >> /etc/puppetlabs/puppet/puppet.conf
  echo "digest_algorithm = sha256" >> /etc/puppetlabs/puppet/puppet.conf
  echo "server = puppet" >> /etc/puppetlabs/puppet/puppet.conf
  echo "ca_server = puppet" >> /etc/puppetlabs/puppet/puppet.conf
  echo "masterport = 8140" >> /etc/puppetlabs/puppet/puppet.conf
  echo "ca_port = 8141" >> /etc/puppetlabs/puppet/puppet.conf
  echo "trusted_node_data = true" >> /etc/puppetlabs/puppet/puppet.conf
  echo " " >> /etc/puppetlabs/puppet/puppet.conf
}

#Reboot the server
function rebootServer1 {
  echo " "
  echo "[INFO] writing runAgain file..."
  touch ~/runAgain.txt
  echo " "
  echo "[INFO] rebooting the server..."
  reboot
}

#Reboot the server
function rebootServer2 {
  echo " "
  echo "[INFO] removing runAgain file..."
  rm -f ~/runAgain.txt
  echo " "
  echo "[INFO] writing goodToGo file..."
  touch ~/goodToGo.txt
  echo " "
  echo "[INFO] rebooting the server..."
  reboot
}

validateInputParameters ${@}

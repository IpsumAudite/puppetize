#!/bin/bash
#Script to add new machine into enclave and puppetize it
#Run as root

#Instructions:
# Log in the first time
# sudo -s
# useradd -m localUser
# passwd localUser
# cd
# touch puppetize.sh
# chmod +x puppetize.sh
# vim puppetize.sh
# copy the script
# get puppet IP and run the script
# log in as ec2-user again
# run the script again
# log in as localUser
# sudo -s
# cd
# run the script
 
#Show user how to use the script
function printHelp {
        echo "[INFO] Usage instructions"
        echo "[INFO] ./puppetize.sh <hostname> <puppet IP>"
        echo "[INFO] example: ./puppetize.sh web1.mydomain.dev.com 192.128.93.118"
}
 
#Validate user input to the script
function validateInputParameters {
        if [ $# -ne 2 ]; then
                echo "[ERROR] Expected a hostname and puppet's IP address"
                printHelp
                exit
        else
                #Create variables
                HOSTNAME=$1
                echo "[INFO] The hostname will be set to $HOSTNAME"
                echo " "
                MY_IP=$(ifconfig -a | grep inet | awk '{print $2}' | sed -n '1p')
                echo "[INFO] The IP address of this machine is $MY_IP"
                echo " "
                PUPPET_IP=$2
                echo "[INFO] The IP of Puppet is $PUPPET_IP"
                echo " "
                mainFunc
        fi
}
 
#Call the functions to puppetize the machine or move on to the reboot phase
function mainFunc {
        if [ -f ~/runAgain.txt ]; then
                echo "[INFO] running puppet agent..."
                echo " "
                puppet agent -t
                echo "[ATTENTION] Log in to puppet, run the command 'puppet cert sign $HOSTNAME',"
                echo "[ATTENTION] add '$HOSTNAME' to '/var/simp/environments/simp/FakeCA/togen' file, and"
                echo "[ATTENTION] run '/var/simp/environments/simp/FakeCA/gencerts_nopass.sh' before continuing."                echo " "
                echo "[ATTENTION] You also want to create a local user with sudo privileges so"
                echo "[ATTENTION] you can log in after ec2-user gets deleted. Do the following and then"
                echo "[ATTENTION] create the user_user.pp manifest:"
                echo "                  useradd -m localUser"
                echo "                  passwd localUser"
                echo " "
                read -p "[INPUT] Did you take the steps listed above? (y/n) " -r
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                        echo "[INFO] running puppet agent"
                        echo " "
                        puppet agent -t
                        puppet agent -t
                        puppet agent -t
                        rebootServer2
                else
                        echo "[INFO] Please log in to puppet, sign the cert, add the hostname to the togen file,"                        echo "[INFO] and run the gencerts_nopass.sh file."
                        echo "[INFO] Then come back and run the script again"
                        exit
                fi
        elif [ -f ~/goodToGo.txt ]; then
                echo "[INFO] deleting ec2-user and maintuser..."
                echo " "
                userdel -r ec2-user; userdel -r maintuser
                echo "[INFO] Running puppet agent a final time..."
                echo " "
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
                removeCurrentRepos
                createNewCustomRepo
                populateCustomRepo
                yumClean
                installPuppet
                updatePuppetConfFile
                rebootServer1
        fi
}
 
#Set the hostname
function setHostname {
        echo "[INFO] setting the hostname..."
        echo " "
        hostnamectl set-hostname $HOSTNAME
        hostname $HOSTNAME
}
 
#Add puppet to the /etc/hosts file, overwriting what was there
function rewriteHostsFile {
        echo "[INFO] re-writing the /etc/hosts file..."
        echo " "
        echo "127.0.0.1 localhost localhost.localdomain localhost4 localhost4.localdomain4" > /etc/hosts
        echo "::1 localhost localhost.localdomain localhost6 localhost6.localdomain6" >> /etc/hosts
        echo "$PUPPET_IP puppet puppet.**.****.***" >> /etc/hosts
        echo "$PUPPET_IP puppet.**.****.***" >> /etc/hosts
}
 
#Remove the current .repo file
function removeCurrentRepos {
        echo "[INFO] removing the current yum repos..."
        echo " "
        rm -rf /etc/yum.repos.d/*
}
 
#Create a new custom.repo file
function createNewCustomRepo {
        echo "[INFO] creating a new custom.repo file..."
        echo " "
        touch /etc/yum.repos.d/custom.repo
}
 
#Populate the new custom.repo file
function populateCustomRepo {
        #Adding Custom-Repo...
        echo "##" >> /etc/yum.repos.d/custom.repo
        echo "[Custom_Cent7]" >> /etc/yum.repos.d/custom.repo
        echo "name=Custom repository - Approved packages for CentOS 7" >> /etc/yum.repos.d/custom.repo
        echo "baseurl=http://puppet/yum/custom_repo/" >> /etc/yum.repos.d/custom.repo
        echo "enabled=1" >> /etc/yum.repos.d/custom.repo
        echo "gpgcheck=0" >> /etc/yum.repos.d/custom.repo
        #Adding CentOS-Repo...
        echo "[CentOS_7_ISO]" >> /etc/yum.repos.d/custom.repo
        echo "name=Cent7 ISO" >> /etc/yum.repos.d/custom.repo
        echo "baseurl=http://puppet/yum/CentOS/7/" >> /etc/yum.repos.d/custom.repo
        echo "enabled=1" >> /etc/yum.repos.d/custom.repo
        echo "gpgcheck=0" >> /etc/yum.repos.d/custom.repo
        #Adding SIMP-Install repo...
        echo "[Custom_SIMPFiles]" >> /etc/yum.repos.d/custom.repo
        echo "name=SIMP Install Files" >> /etc/yum.repos.d/custom.repo
        echo "baseurl=http://puppet/yum/simpinstall/" >> /etc/yum.repos.d/custom.repo
        echo "enabled=1" >> /etc/yum.repos.d/custom.repo
        echo "gpgcheck=0" >> /etc/yum.repos.d/custom.repo
        echo "##" >> /etc/yum.repos.d/custom.repo
}
 
#Clear yum cache
function yumClean {
        echo "[INFO] running yum clean all..."
        echo " "
        yum clean all
}
 
#Install puppet-agent and remove pam i686
function installPuppet {
        echo "[INFO] removing pam i686..."
        echo " "
        yum -y remove pam.i686
        echo "[INFO] installing puppet agent..."
        echo " "
        yum -y install puppet-agent
}
 
#Update the puppet conf file
function updatePuppetConfFile {
        echo "[INFO] updating the puppet conf file..."
        echo " "
        echo "[main]" > /etc/puppetlabs/puppet/puppet.conf
        echo "trusted_server_facts = true" >> /etc/puppetlabs/puppet/puppet.conf
        echo "freeze_main = false" >> /etc/puppetlabs/puppet/puppet.conf
        echo "splay = false" >> /etc/puppetlabs/puppet/puppet.conf
        echo "syslogfacility = local6" >> /etc/puppetlabs/puppet/puppet.conf
        echo "srv_domain = **.****.***" >> /etc/puppetlabs/puppet/puppet.conf
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
        echo "server = puppet.**.****.***" >> /etc/puppetlabs/puppet/puppet.conf
        echo "ca_server = puppet.**.****.***" >> /etc/puppetlabs/puppet/puppet.conf
        echo "masterport = 8140" >> /etc/puppetlabs/puppet/puppet.conf
        echo "ca_port = 8141" >> /etc/puppetlabs/puppet/puppet.conf
        echo "trusted_node_data = true" >> /etc/puppetlabs/puppet/puppet.conf
        echo " " >> /etc/puppetlabs/puppet/puppet.conf
}
 
#Reboot the server
function rebootServer1 {
        echo "[INFO] writing runAgain file..."
        echo " "
        touch ~/runAgain.txt
        echo "[INFO] rebooting the server..."
        reboot
}
 
#Reboot the server
function rebootServer2 {
        echo "[INFO] removing runAgain file..."
        echo " "
        rm -f ~/runAgain.txt
        echo "[INFO] writing goodToGo file..."
        echo " "
        touch ~/goodToGo.txt
        echo "[INFO] rebooting the server..."
        reboot
}
 
validateInputParameters ${@}

# puppetize
Script used to add agents to a Puppet enclave

## Assumptions:
- You have set up a Puppet master and have a working knowledge of how Puppet works
- You are using [SIMP](https://download.simp-project.com/simp/ISO/tar_bundles/SIMP-6.3.1-0.el7-CentOS-7-x86_64.tar.gz) to harden your OS 
- You have set up your own yum repo on the Puppet master
- You are using CentOS or a similar flavor of Linux
- You have a manifest that will give root access to the localUser that you will create

## Instructions:
*Make sure you run the script as root*

1. Log in to your new machine that you wish to puppetize and run the following:
```
sudo -s
useradd -m localUser
passwd localUser
cd
touch puppetize.sh
chmod +x puppetize.sh
vim puppetize.sh
```
2. Copy the script and paste it in
3. Get puppet's IP and run the script (`./puppetize.sh machine1.mydomain.dev.com puppetIP`)
   - The machine will reboot if it runs successfully
4. Log in as ec2-user again
5. Run the script again
6. Log in as localUser and run the following:
   - The machine will reboot if it runs successfully
```
sudo -s
cd
```
7. Run the script a final time and clear any errors

## TODO:
- [ ] Add a variable that strips the domain out of the hostname variable (e.g. web1.mydomain.dev.com -> mydomain.dev.com) and replace all instances of *** with that variable

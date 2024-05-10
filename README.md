# Clock ansibled #

Deploy a simple "clock" web application (frontend + backend) in a virtual machine using `ansible`.

## Ingredients ##

- `debian10-ssh.img.tar.xz`: Compressed disk image of a virtual machine.
- `vm.xml`: Virtual machine XML definition for `libvirt`
- `rsa`: Authorized RSA key for accessing the virtual machine
- `index.html`: Frontend clock application


## Introduction ##

A script `setup-prod.sh` has been built in order to automate:
* Downloading the compressed disk image file
* Extract the file and create a VM with that disk
* Connect to the VM via ansible and install docker and its dependancies [may take several minutes the first time]
* copy the app into the VM and deploy through docker

It automatically creates two new files in the project tree at:
* `./app/webserver/frontend/index.html`
* `./vm/vm.xml`
They are overwritten every time the automated script is invoked
but they are needed if one wants to deploy by running ansible commands manually

After that the website should be available at:
http://<IP or FQDM OF THE VM>/

### Prerequisites ###

The following binaries need to be in $PATH:
* ansible
* ansible-playbook

In case we follow usage example 1 or 4 from Usage, following also required:
* virsh

### Usage ###

The aforementioned script should be put in the project root's folder
as is now, and executed after changing directory to root.

Use either as:
1. Download VM and setup everything from scratch:
```bash
./setup.sh --auto
```

2. Provide the reachable IP or FQDN/hostname of the already deployed VM, e.g:
```bash
./setup.sh --ip=192.168.122.188
```

3. Provide the name of the already locally deployed VM (current: immfly-debian10), e.g:
```bash
./setup.sh --vm=immfly-debian10
```

4. Provide the path to disk img file and auto create the VM, e.g:
```bash
./setup.sh --img=~/debian10-ssh.img
```

Cases 2 && 3 are almost identical with the only difference being, in case 3
it tries to figure out the ip based on the vm name provided.

In those cases no direct modifications are made to the VM itself, outside 
ansible's context.

Cases 1 && 4 differ only to the fact that in case 1 the disk file will be
downloaded from the internet and extracted inside the project ./vm/

#### Manual ansible execution ####

* `export DEBIAN10_IP=<the IP of the VM>`
* Copy `./app/webserver/frontend/index-template.html` to
`./app/webserver/frontend/index.html` 
and change the IP here:
```javascript
const CLOCK_URL = 'http://${BACKEND_ENDPOINT}/clock';
```
* `ansible-playbook ./ansible/setupvm.yml -i ./ansible/env/prod/inventory.yml`
* `ansible-playbook ./ansible/deploy.yml -i ./ansible/env/prod/inventory.yml`


## Other ##

### Structure ###

The project is organized into the following dirs:
* `app` : The directory thats being copied to the VM via ansible
* `ansible`: Ansible files, inventories, variables, roles, tasks
* `vm`: Files needed to setup the VM instance itself: SSH keys and its libvirt definition

#### Ansible structure ####

In `./ansible` folder right now only the `prod` environment is used, 
meaning its inventory and its variables, as well as the 
`env/group_00_global_vars` of course.


### Future work ###

it would be better if we didn't need to keep templated files in 
* `./app/webserver/frontent/index-template.html`
* `./vm/vm-template.xml`

a.o
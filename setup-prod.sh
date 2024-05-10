#!/bin/bash

# Adjust according to your needs
LOG="setup.log"
MAC_ADDR="52:54:00:c0:e9:b1"
DOWNLOAD_URL="URL OF THE VM IMAGE"
DHCP_TIMEOUT=60   # How long to wait to boot in seconds

# leave them as they are:
SRC_ROOT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
HTML_FILE="${SRC_ROOT}/app/webserver/frontend/index.html"
VM_XML="${SRC_ROOT}/vm/vm.xml"

# keep any non-zero exit status when passing output to tee
set -o pipefail

function usage() {
  echo "***************************"
  echo "*******  USAGE  ***********"
  echo "Use either as: "
  echo "1) Download VM and setup everything from scratch:"
  echo "./setup.sh --auto"
  echo "2) Provide the reachable IP or FQDN/hostname of the already deployed VM, e.g:"
  echo "./setup.sh --ip=192.168.122.188"
  echo "3) Provide the name of the already locally deployed VM (e.g: debian10)"
  echo "./setup.sh --vm=debian10"
  echo "4) Provide the path to disk img file and auto create the VM, e.g"
  echo "./setup.sh --img=$(pwd)/vm/debian10-ssh.img"
  echo "***************************"

  exit 1
}

function parse_cmdline() {
  if [[ $# != 1 ]]; then
    usage
  fi

  # else => two arguments
  case "$1" in
    --auto)
      AUTO=true
      ;;
    --ip=*)
      IP="${1#*=}"
      ;;
    --vm=*)
      VM_NAME="${1#*=}"
      ;;
    --img=*)
      IMG_PATH="${1#*=}"
      ;;
    *)
      printf "*** Error: Invalid argument. ****\n\n"
      usage
  esac
}

function check_req() {
  if [[ $AUTO = true ]]; then
    # check if libvirt is installed since we need to setup the VM ourselves
    if ! command -v virsh &> /dev/null
    then
      {
       echo "Command virsh not found or not in PATH"
       echo "Please either install libvirt through package manager or"
       echo "point to a running instance of the VM, using the --ip parameter"
      } | tee -a "$LOG"
      exit 1
    fi
  fi

  # check if ansible is installed, if not ask permission to install
  if ! command -v ansible &> /dev/null
  then
    echo "Ansible is not installed or not in PATH" | tee -a "$LOG"
    read -p "Would you like to install it or abort (y/N)?" answer
    if [[ $answer != 'y' ]] && [[ $answer != "Y" ]]; then
      echo exiting... | tee -a "$LOG"
      exit 1
    fi

    if ! command -v pip3 &> /dev/null
    then
      echo "pip3 wasnt found. Please install through package manager
            (e.g deb: python3-pip)" | tee -a "$LOG"
      exit 1
    fi

    # install ansible. Send errors only to console and everything to LOG
    pip3 install ansible >> "$LOG" 2> >(tee -a "$LOG" >&2) || exit 2
  fi
}


# will only execute in auto mode
function _download_vm() {
  echo "Downloading and extracting the VM ..." | tee -a "$LOG"

  EXTRACT_LOC="${SRC_ROOT}/vm"
  TEMP_FILE="/tmp/debian.img.tar.xz"

  {
    # download the VM image (disk) if not already
    if ! test -f "$TEMP_FILE"; then
      curl "$DOWNLOAD_URL" -o "$TEMP_FILE" || exit 2
    fi
    filename=$(tar -tf "$TEMP_FILE")

    # will extract the image to debian10-ssh.img
    tar -xf "$TEMP_FILE" -C "$EXTRACT_LOC" || exit 2
    # rm "$TEMP_FILE"
  } >> "$LOG" 2> >(tee -a "$LOG" >&2)  # both to log, only errors to tty

  # Set global var IMG_PATH which wasnt set at cmdline since we are in --auto case
  IMG_PATH="${EXTRACT_LOC}/${filename}"

  echo "Disk image path: ${IMG_PATH}" | tee -a "$LOG"
}

# will only execute in auto mode
function _create_vm() {
  echo "Setting up the VM ..." | tee -a "$LOG"

  # create the VM from the XML definition
  virsh create "$VM_XML" >> "$LOG" 2> >(tee -a "$LOG" >&2) || exit 2

  # Wait until the VM gets an IP
  echo "Booting ..." | tee -a "$LOG"
  IP=""
  i=0
  while [[ $IP == "" ]]; do
    IP=$(virsh net-dhcp-leases default | grep $MAC_ADDR | awk '{print $5}' | cut -d "/" -f 1)

    sleep 1
    i=$((i + 1))
    if [[ $i -gt $DHCP_TIMEOUT ]]; then
      >&2 echo "DCHP TIMEOUT Didnt receive an IP.. exiting..." | tee -a "$LOG" && exit 2;
    fi
  done

  echo "VM is set, with IP: ${IP}"
}

# This function will be called only if cmdline args: cases 1) --auto or 4) --img
function auto_prepare_env() {
  # replace template value with actual image file path, in vm/vm.xml
  if ! sed -i "s^\${PATH_TO_VM_DISK_FILE}^${IMG_PATH}^g" "${SRC_ROOT}/vm/vm.xml" 2>&1 | tee -a "$LOG";
  then
    >&2 echo "Failed to edit ${SRC_ROOT}/vm/vm.xml" | tee -a "$LOG" && exit 2
  fi

  _create_vm
}


function prepare() {
  echo "Preparing the environment..." | tee -a "$LOG"

  # keep initial src files intact, while making any dynamical changes
  {
    cp "${SRC_ROOT}/vm/vm-template.xml" "$VM_XML" || exit 2
    cp "${SRC_ROOT}/app/webserver/frontend/index-template.html" "$HTML_FILE" || exit 2
  } >> "$LOG" 2> >(tee -a "$LOG" >&2)

  # based on the cmdline option either:
  if [[ $AUTO = true ]]; then
    _download_vm
    # set up everything, sets $IP value
    auto_prepare_env
  elif [[ "$IP" ]]; then
    # all set, we have the IP, local or remote
    echo "nothing to do in this case" > /dev/null
  elif [[ "$VM_NAME" ]]; then
    # find the local IP from the VM name
    IP=$(virsh domifaddr "$VM_NAME" |grep ipv4|awk '{print $4}' | cut -d "/" -f 1)
  elif [[ $IMG_PATH ]]; then
    # set up everything, sets $IP value
    auto_prepare_env
  fi
  # Now export that env to be used by ansible's subshell
  export DEBIAN10_IP=$IP
  echo "IP/Domain found: ${IP}" >> "$LOG"

  # ugly but necessary with current frontend, hardcode the IP of the backend:
  if ! sed -i "s^\${BACKEND_ENDPOINT}^${IP}^g" "$HTML_FILE" 2>&1 | tee -a "$LOG";
  then
    >&2 echo "Failed to edit $HTML_FILE" | tee -a "$LOG" && exit 2
  fi

  # set permission to ssh private key file
  chmod 0400 vm/rsa 2>&1 | tee -a "$LOG" || exit 2
}


main() {
  # some paths in ansible files are evaluated as relative to the execution
  # directory while others are evaluated based the file's path...
  # Therefore the `SRC_ROOT` and the working directory needs to be the same,
  # so we `cd` to the `SRC_ROOT` and perform all actions from there
  cd "$SRC_ROOT" || exit 2

  # pass the cmdline arguments to parse_cmdline which will set global vars
  parse_cmdline "$@"

  # Init logging
  printf "\n######## %s ######## \n\n" "$(date)" >> "$LOG" || exit 2

  # check if the prerequisites are installed
  check_req

  # based on the cmdline options, prepare the environment accordingly
  prepare

  # Ensure ansible can connect to the machine
  while ! ansible-playbook ./ansible/testconn.yml -i ./ansible/env/prod/inventory.yml &>> "$LOG"; do
    echo "Waiting for sshd to come up " | tee -a "$LOG"
    sleep 2
  done

  # setup the servers
  echo "Setting up the production servers ..." | tee -a "$LOG"
  if ! ansible-playbook ./ansible/setupvm.yml -i ./ansible/env/prod/inventory.yml &>> "$LOG" 2>&1;
  then
    echo "ERROR setting up production servers" | tee -a "$LOG" && exit 2
  fi

  # copy the app files and deploy the dockers
  echo "Deploying the application ..." | tee -a "$LOG"
  if ! ansible-playbook ./ansible/deploy.yml -i ./ansible/env/prod/inventory.yml &>> "$LOG" 2>&1;
  then
    echo "ERROR deploying docker images to the production servers" | tee -a "$LOG" && exit 2
  fi

  echo "Visit at http://${DEBIAN10_IP}"
}

main "$@"

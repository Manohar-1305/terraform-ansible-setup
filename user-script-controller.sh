#!/bin/bash

LOG_FILE="$(pwd)/ansible-controller-userdata.log"

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export AWS_REGION="ap-south-1"

# Terminal + log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "============================================================"
echo "CONTROLLER SCRIPT STARTED"
echo "Date : $(date)"
echo "User : $(whoami)"
echo "PWD  : $(pwd)"
echo "Log  : $LOG_FILE"
echo "============================================================"

# ============================================================
# VARIABLES
# ============================================================

user_name="ansible-user"
user_home="/home/$user_name"
user_ssh_dir="$user_home/.ssh"

# ============================================================
# CREATE ANSIBLE USER
# ============================================================

echo "Checking ansible-user..."

if id "$user_name" &>/dev/null; then
    echo "User $user_name already exists."
else
    adduser --disabled-password --gecos "" "$user_name"

    echo "User $user_name created successfully."

    echo "ansible-user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible-user
    chmod 440 /etc/sudoers.d/ansible-user
fi

# ============================================================
# INSTALL REQUIRED PACKAGES
# ============================================================

echo "Installing required packages..."

apt-get update -y

apt-get install -y \
    awscli \
    git \
    curl \
    software-properties-common \
    ansible

# ============================================================
# SSH DIRECTORY
# ============================================================

mkdir -p "$user_ssh_dir"
chmod 700 "$user_ssh_dir"

# ============================================================
# GENERATE SSH KEY
# ============================================================

echo "Checking SSH key..."

if [ ! -f "$user_ssh_dir/id_rsa" ]; then

    echo "Generating SSH key..."

    ssh-keygen \
        -t rsa \
        -b 4096 \
        -f "$user_ssh_dir/id_rsa" \
        -N ""

else
    echo "SSH key already exists."
fi

chown -R "$user_name:$user_name" "$user_home"

# ============================================================
# GET CONTROLLER INSTANCE ID
# ============================================================

echo "Getting controller instance ID..."

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

echo "Controller Instance ID: $INSTANCE_ID"

if [ -z "$INSTANCE_ID" ]; then
    echo "ERROR: Could not get instance ID."
    exit 1
fi

# ============================================================
# GET CONTROLLER NAME
# ============================================================

server_name=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[0].Instances[0].Tags[?Key=='Name'].Value | [0]" \
    --output text)

echo "Controller Name: $server_name"

if [ -z "$server_name" ] || [ "$server_name" = "None" ]; then
    echo "ERROR: Could not determine controller Name tag."
    exit 1
fi

# ============================================================
# UPLOAD CONTROLLER PUBLIC KEY
# ============================================================

S3_KEY="s3://my-key/${server_name}.pub"

echo "Uploading controller public key to:"
echo "$S3_KEY"

aws s3 cp \
    "$user_ssh_dir/id_rsa.pub" \
    "$S3_KEY"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to upload controller public key."
    exit 1
fi

echo "Controller public key uploaded successfully."

# ============================================================
# CLONE REPOSITORY AS ANSIBLE-USER HOME
# ============================================================

cd "$user_home"

echo "Current directory: $(pwd)"

if [ -d "$user_home/ansible_setup/.git" ]; then

    echo "ansible_setup repository already exists."

else

    echo "Cloning ansible_setup repository..."

    git clone \
        "https://github.com/Manohar-1305/ansible_setup.git" \
        "$user_home/ansible_setup"

    if [ $? -ne 0 ]; then
        echo "ERROR: Git clone failed."
        exit 1
    fi

fi

chown -R "$user_name:$user_name" "$user_home/ansible_setup"

# ============================================================
# INVENTORY
# ============================================================

INVENTORY_FILE="$user_home/ansible_setup/ansible/inventories/inventory.ini"

echo "Inventory file:"
echo "$INVENTORY_FILE"

if [ ! -f "$INVENTORY_FILE" ]; then
    echo "ERROR: Inventory file not found."
    exit 1
fi

# ============================================================
# LOG FUNCTION
# ============================================================

INVENTORY_LOG="$user_home/ansible_script.log"

log() {
    local message="$1"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $message" | tee -a "$INVENTORY_LOG"
}

# ============================================================
# UPDATE INVENTORY FUNCTION
# ============================================================

update_entry() {

    local section="$1"
    local host="$2"
    local ip="$3"

    log "Updating [$section] $host -> $ip"

    if ! grep -q "^\[$section\]" "$INVENTORY_FILE"; then

        log "Section [$section] does not exist. Creating it."

        echo "" >> "$INVENTORY_FILE"
        echo "[$section]" >> "$INVENTORY_FILE"
    fi

    sed -i \
        "/^\[$section\]/,/^\[.*\]/{/^$host ansible_host=.*/d}" \
        "$INVENTORY_FILE"

    sed -i \
        "/^\[$section\]/a $host ansible_host=$ip" \
        "$INVENTORY_FILE"
}

# ============================================================
# REMOVE ONLY OLD CLIENT1/2/3 ENTRIES
# ============================================================

echo "Removing old client1/client2/client3 inventory entries..."

sed -i \
    '/^ansible_client1 ansible_host=/d' \
    "$INVENTORY_FILE"

sed -i \
    '/^ansible_client2 ansible_host=/d' \
    "$INVENTORY_FILE"

sed -i \
    '/^ansible_client3 ansible_host=/d' \
    "$INVENTORY_FILE"

# ============================================================
# GET CONTROLLER PUBLIC IP
# ============================================================

echo "Fetching controller public IP..."

ansible_controller=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)

echo "Controller Public IP: $ansible_controller"

if [ -z "$ansible_controller" ] || [ "$ansible_controller" = "None" ]; then
    echo "ERROR: Controller public IP not found."
    exit 1
fi

# ============================================================
# WAIT FOR CLIENT
# ============================================================

echo "Waiting for ansible_client..."

sleep 90

# ============================================================
# GET CLIENT PRIVATE IP
# ============================================================

echo "Fetching ansible_client private IP..."

ansible_client_ip=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=ansible_client" \
    --query "Reservations[*].Instances[*].PrivateIpAddress" \
    --output text)

echo "Client Private IP: $ansible_client_ip"

if [ -z "$ansible_client_ip" ] || [ "$ansible_client_ip" = "None" ]; then

    echo "Client IP not found. Retrying..."

    sleep 10

    ansible_client_ip=$(aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=ansible_client" \
        --query "Reservations[*].Instances[*].PrivateIpAddress" \
        --output text)

    echo "Client Private IP after retry: $ansible_client_ip"
fi

if [ -z "$ansible_client_ip" ] || [ "$ansible_client_ip" = "None" ]; then
    echo "ERROR: Failed to get ansible_client private IP."
    exit 1
fi

# ============================================================
# UPDATE INVENTORY
# ============================================================

echo "Updating controller inventory entry..."

update_entry \
    "controller" \
    "ansible_controller" \
    "$ansible_controller"

echo "Updating client inventory entry..."

update_entry \
    "client" \
    "ansible_client" \
    "$ansible_client_ip"

# ============================================================
# OWNERSHIP
# ============================================================

chown -R "$user_name:$user_name" "$user_home"

# ============================================================
# SHOW INVENTORY
# ============================================================

echo ""
echo "============================================================"
echo "UPDATED INVENTORY"
echo "============================================================"

cat "$INVENTORY_FILE"

echo ""
echo "============================================================"
echo "CONTROLLER SETUP COMPLETED"
echo "============================================================"

echo "Repository : $user_home/ansible_setup"
echo "Inventory  : $INVENTORY_FILE"
echo "Controller : $ansible_controller"
echo "Client     : $ansible_client_ip"
echo "Date       : $(date)"

echo "============================================================"
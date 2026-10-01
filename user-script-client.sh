#!/bin/bash

LOG_FILE="$(pwd)/ansible-client-userdata.log"

# Send ALL output to terminal and log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "============================================================"
echo "CLIENT SCRIPT STARTED"
echo "Date : $(date)"
echo "User : $(whoami)"
echo "PWD  : $(pwd)"
echo "Log  : $LOG_FILE"
echo "============================================================"

# Non-interactive mode
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# ============================================================
# VARIABLES
# ============================================================

user_name="ansible-user"
user_home="/home/$user_name"
user_ssh_dir="$user_home/.ssh"
ssh_key_path="$user_ssh_dir/authorized_keys"

export AWS_REGION="ap-south-1"

# ============================================================
# CREATE USER
# ============================================================

echo "Checking ansible-user..."

if id "$user_name" &>/dev/null; then
    echo "User $user_name already exists."
else

    adduser --disabled-password --gecos "" "$user_name"

    echo "User $user_name has been created successfully."

    echo "ansible-user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible-user
    chmod 440 /etc/sudoers.d/ansible-user

fi

# ============================================================
# WAIT FOR CONTROLLER KEY
# ============================================================

echo "Waiting 120 seconds for controller SSH key..."

sleep 120

# ============================================================
# CREATE SSH DIRECTORY
# ============================================================

echo "Creating SSH directory..."

mkdir -p "$user_ssh_dir"

chmod 700 "$user_ssh_dir"

# ============================================================
# INSTALL AWS CLI
# ============================================================

echo "Installing AWS CLI..."

apt-get update -y

apt-get install -y awscli

# ============================================================
# DOWNLOAD CONTROLLER SSH PUBLIC KEY
# ============================================================

echo "Downloading controller SSH public key from S3..."

CONTROLLER_KEY="s3://my-key/ansible_controller.pub"

echo "S3 key: $CONTROLLER_KEY"

aws s3 cp \
    "$CONTROLLER_KEY" \
    "$ssh_key_path"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to download controller SSH public key."
    exit 1
fi

echo "Controller SSH public key downloaded successfully."

# ============================================================
# CONFIGURE AUTHORIZED_KEYS
# ============================================================

chmod 600 "$ssh_key_path"

chown -R "$user_name:$user_name" "$user_home"

echo "authorized_keys configured successfully."

# ============================================================
# SUDO ACCESS
# ============================================================

echo "Configuring sudo access..."

echo "ansible-user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible-user

chmod 440 /etc/sudoers.d/ansible-user

# ============================================================
# FINAL STATUS
# ============================================================

echo ""
echo "============================================================"
echo "CLIENT SETUP COMPLETED"
echo "============================================================"

echo "User        : $user_name"
echo "SSH key     : $ssh_key_path"
echo "S3 key      : $CONTROLLER_KEY"
echo "Date        : $(date)"
echo "Log file    : $LOG_FILE"

echo "============================================================"

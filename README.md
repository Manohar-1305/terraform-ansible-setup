Terraform + Ansible Automation on AWS
This repository demonstrates an end-to-end automation workflow using
Terraform for AWS infrastructure provisioning and Ansible for
server configuration and post-provisioning automation.
The project is designed to replicate a practical post-migration
configuration scenario. The actual VMware-to-OpenShift Virtualization
migration is outside the scope of this repository. Instead, an AWS EC2
environment is used to represent the infrastructure and the type of
manual configuration that may be required after a VM migration.
Project Objective
In a real VM migration workflow, a VM can be successfully migrated but
still fail post-migration checks because required guest-side
configuration is missing.
One example is a migrated Linux VM where the QEMU Guest Agent is not
installed or configured correctly. If required post-migration checks
fail, the migration workflow can ultimately be reported as failed.
This repository demonstrates how such manual post-migration
configuration can be converted into repeatable Ansible automation.
The demonstration covers:
- Provisioning AWS infrastructure with Terraform
- Creating an Ansible Controller and Client
- Configuring SSH connectivity between Controller and Client
- Dynamically updating the Ansible inventory
- Installing and configuring Nginx
- Installing and configuring the QEMU Guest Agent
- Verifying configuration
- Separating infrastructure provisioning from server configuration
Architecture
                         AWS
                          |
                    +-----+------+
                    |    VPC     |
                    +-----+------+
                          |
                  +-------+-------+
                  | Public Subnet |
                  +-------+-------+
                          |
             +------------+------------+
             |                         |
             v                         v
     +---------------+         +---------------+
     | Ansible       |   SSH   | Ansible       |
     | Controller    | ------> | Client        |
     |               |         |               |
     | Terraform     |         | Represents    |
     | Ansible       |         | migrated VM   |
     +---------------+         +---------------+
             |
             | Ansible
             v
       +----------------------+
       | Server Configuration |
       +----------------------+
       | Nginx                |
       | QEMU Guest Agent     |
       | Verification         |
       +----------------------+
Terraform and Ansible Responsibilities
Terraform
Terraform handles the infrastructure layer.
It provisions:
- VPC
- Internet Gateway
- Public Subnet
- Route Table
- Security Group
- IAM Role
- IAM Policies
- IAM Instance Profile
- Ansible Controller EC2 instance
- Ansible Client EC2 instance
Terraform also controls the dependency between the Controller and Client
so that the Controller is created before the Client.
Ansible
Ansible handles the configuration and management layer.
It connects to the Client over SSH and performs tasks such as:
- Installing packages
- Configuring services
- Installing Nginx
- Installing QEMU Guest Agent
- Enabling required services
- Performing configuration checks
The separation is:
Terraform  -> Infrastructure provisioning
Ansible    -> Server configuration and management
Repository Structure
terraform-ansible-setup/
|
+-- terraform/
|   |
|   +-- main.tf
|   +-- variables.tf
|   +-- outputs.tf
|   +-- ...
|
+-- ansible/
|   |
|   +-- ansible.cfg
|   |
|   +-- inventories/
|   |   +-- inventory.ini
|   |
|   +-- playbooks/
|       +-- ping.yml
|       +-- nginx.yml
|       +-- qemu.yml
|       +-- ...
|
+-- user-script-controller.sh
+-- user-script-client.sh
+-- README.md
The exact filenames and directory layout should match the files
currently present in the repository.

Terraform Configuration
The Terraform configuration defines the AWS environment.
The main infrastructure components are:
VPC
Creates the isolated AWS network:
10.20.0.0/16
Public Subnet
The EC2 instances are placed in the public subnet:
10.20.4.0/24
The subnet is configured to automatically assign public IPv4 addresses
to instances.
Internet Gateway
Provides internet connectivity between the VPC and the internet.
Route Table
The public route table contains a default route:
0.0.0.0/0 -> Internet Gateway
Security Group
The security group allows:
TCP 22   SSH
TCP 80   HTTP
TCP 443  HTTPS
It also allows outbound IPv4 traffic.
IAM Role and Instance Profile
The EC2 instances receive an IAM role through an instance profile.
The role provides permissions required by the automation, including:
- S3 object access
- EC2 instance information lookup
This allows the instances to use temporary AWS credentials instead of
storing AWS access keys on the servers.
Controller and Client
Ansible Controller
The Controller is the system from which Ansible is executed.
During first boot, the Controller user-data script:
1. Creates ansible-user
2. Configures passwordless sudo
3. Installs AWS CLI, Git and Ansible
4. Generates an SSH key pair
5. Retrieves its EC2 instance information
6. Uploads its public SSH key to S3
7. Clones the Ansible/Terraform repository
8. Updates the Ansible inventory with the Controller and Client
   addresses
Ansible Client
The Client represents the server that Ansible manages.
During first boot, the Client user-data script:
1. Creates ansible-user
2. Configures passwordless sudo
3. Installs AWS CLI
4. Downloads the Controller public SSH key from S3
5. Places the key in authorized_keys
6. Configures SSH permissions
This establishes passwordless SSH authentication from the Controller to
the Client.
SSH Key Flow
The SSH authentication flow is:
Controller
    |
    | Generate SSH key pair
    |
    +---- id_rsa
    |
    +---- id_rsa.pub
             |
             | Upload
             v
        S3 Bucket
             |
             | Download
             v
          Client
             |
             v
      authorized_keys
Ansible then uses the Controller's private key to connect to the Client.
Ansible Configuration
The repository uses an Ansible configuration similar to:
[defaults]
private_key_file = /home/ansible-user/.ssh/id_rsa
remote_user = ansible-user
host_key_checking = False
This defines the SSH private key, remote Linux user, and host-key
checking behavior used by Ansible.
Inventory
The inventory contains the Controller and Client groups:
[controller]
ansible_controller ansible_host=<CONTROLLER_IP>

[client]
ansible_client ansible_host=<CLIENT_IP>
The Client group is used by the configuration playbooks.
Example Ansible Operations
Connectivity Test
The ping playbook verifies that Ansible can connect to the Client.
- name: Ping all hosts
  hosts: client
  gather_facts: no

  tasks:
    - name: Check connectivity
      ansible.builtin.ping:
Nginx
The Nginx playbook demonstrates a normal server configuration task.
It:
- Installs Nginx
- Enables the Nginx service
- Starts the service
- Tests the Nginx configuration
- Checks the service state
QEMU Guest Agent
The QEMU playbook represents a post-migration configuration task.
It:
- Determines the Ubuntu version
- Changes the root password
- Enables the Ubuntu Universe repository
- Updates the package cache
- Installs QEMU/KVM-related packages
- Installs qemu-guest-agent
- Attempts to enable the QEMU Guest Agent service
- Verifies the service state
The QEMU Guest Agent is relevant to the migration scenario because it
provides a communication mechanism between a guest VM and its
virtualization platform.
Real-World Scenario Being Replicated
The repository does not perform an actual VMware-to-OpenShift
Virtualization migration.
Instead, it replicates the type of post-migration remediation that
may be required.
The scenario is:
VMware VM
    |
    | Migration
    v
OpenShift Virtualization
    |
    v
Migrated VM
    |
    +-- QEMU Guest Agent missing/not configured
    |
    v
Post-Migration Checks
    |
    v
Checks Fail
    |
    v
Migration Workflow Reported as FAILED
The manual remediation can then be represented by:
Ansible
   |
   +-- Connect to VM
   +-- Install required packages
   +-- Configure QEMU Guest Agent
   +-- Enable required service
   +-- Verify configuration
The purpose of the demonstration is to show how this type of manual
activity can be automated and repeated consistently.
Deployment Workflow
1. Initialize Terraform
terraform init
Downloads and initializes the required Terraform providers.
2. Validate Configuration
terraform validate
Checks the Terraform configuration for syntax and configuration errors.
3. Review the Plan
terraform plan
Shows the infrastructure changes Terraform intends to make.
4. Create Infrastructure
terraform apply
Creates the AWS infrastructure.
5. Get Instance IP Addresses
terraform output
Displays the Terraform outputs, including the Controller and Client
public IP addresses.
6. Connect to the Controller
After the Controller has completed its user-data initialization, connect
to the Controller and use the configured Ansible environment.
7. Run Ansible
For example:
ansible-playbook -i ansible/inventories/inventory.ini ansible/playbooks/ping.yml
Then execute the required configuration playbooks.
Terraform Dependency Flow
The project intentionally creates the Controller before the Client.
Controller EC2
      |
      v
90-second Terraform wait
      |
      v
Client EC2
The Controller also waits during its startup before looking up the
Client address, while the Client waits before downloading the
Controller's public SSH key.
These delays provide a startup buffer for the SSH key exchange and
inventory configuration.
Important Note About QEMU Guest Agent on AWS
This AWS environment is being used to demonstrate the automation
workflow.
An EC2 instance is not the same as a VM running under QEMU/KVM with the
expected VirtIO guest-agent communication channel. Therefore, the QEMU
Guest Agent package can be installed on the test system while the
service may not operate normally because the required virtualization
channel is not provided by the EC2 environment.
This is a limitation of the demonstration environment and does not
represent the complete behavior of a VM running under OpenShift
Virtualization.
Learning Objectives
After completing this repository, you should understand:
- How Terraform provisions AWS infrastructure
- How Terraform resources depend on one another
- How IAM roles and instance profiles provide permissions to EC2
- How EC2 instances can use AWS APIs without static credentials
- How Ansible connects to remote Linux systems
- How SSH keys can be automated
- How dynamic inventory information can be retrieved from AWS
- How Ansible playbooks configure servers
- How post-migration activities can be automated
- How Terraform and Ansible can be used together
Related Learning
For more advanced Ansible automation on OpenShift and Kubernetes, see:
- Deploying Ansible Automation Platform on
  OpenShift
- Executing Ansible Jobs using AAP on
  OpenShift
- Deploying Ansible Tower/AWX on Kubernetes with AWX
  Operator
Blog
A detailed explanation of this demonstration is available here:
Ansible Automation on AWS: Complete Setup, Nginx and QEMU Guest
Agent
Technologies Used
- AWS
- Terraform
- Ansible
- EC2
- IAM
- VPC
- S3
- SSH
- Nginx
- QEMU Guest Agent
- Linux
Disclaimer
This repository is a demonstration and learning environment. The
VMware-to-OpenShift Virtualization migration itself is not performed
here. The AWS environment is used to reproduce and automate
representative post-migration configuration tasks.

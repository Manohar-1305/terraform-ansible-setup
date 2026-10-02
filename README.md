## Terraform + Ansible Automation on AWS

This repository demonstrates an end-to-end automation workflow using Terraform and Ansible on AWS.

The project is designed to replicate a practical post-migration configuration scenario. The actual VMware-to-OpenShift Virtualization migration is outside the scope of this repository. Instead, AWS EC2 instances are used to reproduce the type of environment and configuration activities that may be required after a VM migration.

One example is a migrated Linux VM where the QEMU Guest Agent is missing or not configured correctly. If required post-migration checks fail, the overall migration workflow can ultimately be reported as failed.

This repository demonstrates how such manual post-migration configuration activities can be converted into repeatable Ansible automation.

Project Objective

The main objective is to demonstrate the separation between infrastructure provisioning and server configuration.

Tool	Responsibility
Terraform	Provisions and manages the AWS infrastructure
Ansible	Connects to the servers and performs configuration and management tasks

Terraform creates the infrastructure required for the demonstration, while Ansible is used after the infrastructure is available to connect to the target system and perform configuration tasks.

## What This Repository Demonstrates

- **AWS infrastructure provisioning**
- **Ansible Controller and Client creation**
- **SSH-based communication**
- **Dynamic inventory update**
- **Nginx installation and configuration**
- **QEMU Guest Agent installation and configuration**
- **Post-migration configuration automation**
- **Configuration verification**

## Architecture

                              AWS
                               |
                         +-----+------+
                         |    VPC     |
                         +-----+------+
                               |
                       +-------+-------+
                       | Public Subnet|
                       +-------+-------+
                               |
                  +------------+------------+
                  |                         |
                  v                         v
          +---------------+         +---------------+
          |   Ansible     |   SSH   |   Ansible     |
          |   Controller  | ------> |     Client    |
          |               |         |               |
          | Runs Ansible  |         | Target Server |
          +---------------+         +---------------+
                  |
                  | Ansible
                  v
          +----------------------+
          | Server Configuration |
          +----------+-----------+
                     |
               +-----+-----+
               |           |
               v           v
             Nginx     QEMU Guest
                        Agent

The Ansible Client represents the Linux system on which post-provisioning or post-migration configuration tasks are performed.

## Repository Structure

The repository contains the following files and directories:

```text
terraform-ansible-setup/
│
├── ansible/
│   └── inventories/
│       └── inventory.ini
│
├── ansible.cfg
├── main.tf
├── ping.yaml
├── policy.json
├── steps.txt
├── testing-dev-1.pem
├── user-script-client.sh
├── user-script-controller.sh
└── README.md

File and Directory Overview
File / Directory	Purpose
main.tf	Main Terraform configuration containing AWS infrastructure resources, variables, dependencies, and outputs.
ansible.cfg	Ansible configuration used by the Controller.
ansible/inventories/inventory.ini	Ansible inventory containing the managed hosts.
ping.yaml	Ansible playbook used to test connectivity to the Client.
policy.json	IAM policy configuration used by the project.
steps.txt	Setup, deployment, and testing commands.
user-script-controller.sh	EC2 user-data script that prepares the Ansible Controller.
user-script-client.sh	EC2 user-data script that prepares the Ansible Client.
testing-dev-1.pem	EC2 SSH private key used for instance access.
README.md	Project documentation.


Terraform Configuration
The Terraform configuration provisions the AWS infrastructure required for the Ansible automation environment.
```
Infrastructure Components
| Component | Purpose |
|---|---|
| VPC | Provides the isolated AWS network |
| Internet Gateway | Provides internet connectivity for the public subnet |
| Public Subnet | Hosts the Controller and Client EC2 instances |
| Route Table | Defines network routing for the subnet |
| Security Group | Controls inbound and outbound network traffic |
| IAM Role | Provides AWS permissions to EC2 |
| IAM Policies | Define the AWS actions allowed to the EC2 instances |
| IAM Instance Profile | Attaches the IAM role to EC2 instances |
| Ansible Controller EC2 | Runs Ansible automation |
| Ansible Client EC2 | Target system managed by Ansible |
| Time Sleep | Provides a delay between Controller and Client creation |

Terraform and AWS Requirements
| Configuration | Value |
|---|---|
| Terraform version | `<= 1.6.6` |
| AWS provider | `~> 5.0` |
| AWS Region | `ap-south-1` |
| VPC CIDR | `10.20.0.0/16` |
| Public Subnet CIDR | `10.20.4.0/24` |
| Availability Zone | `ap-south-1b` |
| Controller instance type | `t2.micro` |
| Client instance type | `t2.micro` |
| Client count | `1` |

VPC
| Configuration | Value |
|---|---|
| CIDR | `10.20.0.0/16` |
| Purpose | Provides the isolated network in which the AWS resources are deployed |
| Resources | EC2 Controller and Client |

Internet Gateway
| Configuration | Value |
|---|---|
| Purpose | Provides a path between the VPC and the internet |
| Default Route | `0.0.0.0/0` |
| Target | Internet Gateway |
| Effect | Allows the public subnet to communicate with the internet |

Public Subnet
| Configuration | Value |
|---|---|
| CIDR | `10.20.4.0/24` |
| Availability Zone | `ap-south-1b` |
| Public IPv4 | Enabled |
| Resources | Ansible Controller and Ansible Client |
The subnet is configured to assign public IPv4 addresses to launched instances.

Route Table
| Configuration | Value |
|---|---|
| Route | `0.0.0.0/0` |
| Target | Internet Gateway |
| Purpose | Allows instances in the public subnet to send traffic to the internet |

Security Group
The security group acts as the virtual firewall for the EC2 instances.
| Port | Protocol | Purpose |
|---:|:---:|---|
| 22 | TCP | SSH and Ansible connectivity |
| 80 | TCP | HTTP / Nginx |
| 443 | TCP | HTTPS |

| Traffic | Configuration |
|---|---|
| Inbound | Ports 22, 80, and 443 |
| Outbound | IPv4 traffic allowed |
| SSH | Required for the Ansible Controller to connect to the Client |

IAM Role
| Configuration | Value |
|---|---|
| Trusted Service | EC2 |
| Purpose | Provides AWS permissions required by the automation |

The role trusts the EC2 service:
```code
Principal = {
  Service = "ec2.amazonaws.com"
}
```
This allows EC2 to assume the role through AWS Security Token Service (STS).
| Permission | Purpose |
|---|---|
| `s3:PutObject` | Upload the Controller public SSH key to S3 |
| `s3:GetObject` | Download the Controller public SSH key from S3 |
| `s3:ListBucket` | Access/list the S3 bucket |
| `ec2:DescribeInstances` | Retrieve EC2 instance information |

IAM Policies
The project uses IAM permissions for the AWS operations performed by the automation.
| Permission | Purpose |
|---|---|
| `s3:PutObject` | Upload the Controller public SSH key to S3 |
| `s3:GetObject` | Download the Controller public SSH key from S3 |
| `s3:ListBucket` | Access/list the S3 bucket |
| `ec2:DescribeInstances` | Retrieve EC2 instance information |
The Controller uses the EC2 API to retrieve information such as the instance ID, Name tag, public IP address, and private IP address.

IAM Instance Profile
The IAM role is attached to EC2 through an IAM Instance Profile.
```code
IAM Role
    |
    v
IAM Instance Profile
    |
    v
EC2 Instance
```
This allows the EC2 instances to use the permissions of the IAM role without storing static AWS access keys on the servers.
Ansible Controller
The Ansible Controller is the system from which Ansible commands and playbooks are executed.
The Controller user-data script performs the following tasks:
| Task | Description |
|---|---|
| User creation | Creates the `ansible-user` |
| Sudo configuration | Configures sudo access |
| Package installation | Installs required packages |
| AWS CLI | Installs AWS CLI |
| Git | Installs Git |
| Ansible | Installs Ansible |
| SSH key generation | Creates an SSH key pair |
| EC2 information | Retrieves Controller EC2 information |
| S3 upload | Uploads the Controller public SSH key to S3 |
| Repository | Clones the repository |
| Inventory | Updates the Ansible inventory |
| Logging | Records setup activity in log files |

After initialization, the Controller is ready to execute Ansible automation against the Client.
## Ansible Client
The Ansible Client is the target system managed by Ansible.
The Client user-data script performs the following tasks:
| Task | Description |
|---|---|
| User creation | Creates the `ansible-user` |
| Sudo configuration | Configures sudo access |
| Startup wait | Waits for the Controller public key |
| AWS CLI | Installs AWS CLI |
| S3 download | Downloads the Controller public SSH key from S3 |
| SSH configuration | Places the key in `authorized_keys` |
| SSH permissions | Configures the required SSH permissions |

The result is SSH authentication from the Controller to the Client.
## SSH Key Flow
The SSH key exchange works as follows:
```
Ansible Controller
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
        Ansible Client
                |
                v
        authorized_keys
```
The Controller keeps the private key, while the Client receives the public key.
Ansible uses the Controller's private key when connecting to the Client.

Why S3 Is Used
S3 is used as an intermediate location for transferring the Controller's public SSH key to the Client.
Step	Action
1	Controller generates an SSH key pair
2	Controller uploads id_rsa.pub to S3
3	Client retrieves the public key from S3
4	Client places the public key in authorized_keys
5	Controller can connect to Client using SSH


The EC2 instances use their IAM role permissions to access the required S3 objects.
Controller and Client Creation Order
The Terraform configuration intentionally creates the Controller before the Client.
The dependency is:
```
Ansible Controller
        |
        v
   90-second wait
        |
        v
Ansible Client
```
The Controller also waits during its startup before looking up the Client information. The Client waits before downloading the Controller public SSH key.

## IAM Role Access to S3

The EC2 instances use their IAM role permissions to access the required S3 objects.
Controller and Client Creation Order
The Terraform configuration intentionally creates the Controller before the Client.
The dependency is:
```
Ansible Controller
        |
        v
   90-second wait
        |
        v
Ansible Client
```

The Controller also waits during its startup before looking up the Client information. The Client waits before downloading the Controller public SSH key.
These delays provide a startup buffer so that the Controller has time to initialize and upload its public key before the Client attempts to retrieve it.
Ansible Configuration
The ansible.cfg file contains the Ansible configuration used by the Controller.
```
[defaults]
private_key_file = /home/ansible-user/.ssh/id_rsa
remote_user = ansible-user
host_key_checking = False
```
| Setting | Purpose |
|---|---|
| `private_key_file` | Specifies the SSH private key Ansible uses |
| `remote_user` | Specifies the Linux user used for SSH |
| `host_key_checking` | Controls SSH host-key verification prompts |

Ansible Inventory
The inventory is located at:
``` 
ansible/inventories/inventory.ini

[controller]
ansible_controller ansible_host=<CONTROLLER_IP>

[client]
ansible_client ansible_host=<CLIENT_IP>
```
| Inventory Item | Purpose |
|---|---|
| `[controller]` | Controller host group |
| `[client]` | Client host group |
| `ansible_controller` | Ansible inventory hostname |
| `ansible_client` | Ansible inventory hostname |
| `ansible_host` | Actual IP address used for the connection |

The Controller startup script dynamically updates the inventory with the instance information obtained from AWS.

ping.yaml
The ping.yaml playbook is used to verify Ansible connectivity to the Client.
Example
```
---
- name: Ping all hosts
  hosts: client
  gather_facts: no
  tasks:
    - name: Check connectivity
      ansible.builtin.ping:
```
| Verification | Purpose |
|---|---|
| Ansible | Ansible is installed on the Controller |
| Inventory | The inventory contains the Client |
| SSH Authentication | SSH authentication is working |
| Connectivity | The Controller can reach the Client |
| User | The `ansible-user` can be used for the connection |

Nginx Configuration
Nginx is used as a basic server-configuration example.
The Ansible automation can be used to:

| Task | Purpose |
|---|---|
| Install Nginx | Installs Nginx |
| Enable the Nginx service | Enables the Nginx service |
| Start the Nginx service | Starts the Nginx service |
| Validate the Nginx configuration | Validates the Nginx configuration |
| Verify the service status | Verifies the Nginx service status |

```
Ansible Controller
       |
       | SSH
       v
Ansible Client
       |
       +-- Install Nginx
       +-- Enable service
       +-- Start service
       +-- Verify configuration
```
## This demonstrates a common Day-2 server configuration task.
QEMU Guest Agent
The QEMU Guest Agent is relevant to the post-migration scenario demonstrated by this project.
After a VM is migrated to a virtualization platform, required guest-side components may need to be installed or configured before post-migration checks can complete successfully.
The QEMU Guest Agent provides a communication mechanism between a guest VM and its virtualization platform.
Automation Scenario
```
Migrated VM
     |
     v
QEMU Guest Agent missing / not configured
     |
     v
Post-Migration Checks
     |
     v
Checks Fail
     |
     v
Migration Workflow Reported as FAILED
```
# Ansible Remediation

```
Ansible
   |
   +-- Install QEMU Guest Agent
   +-- Configure service
   +-- Enable required service
   +-- Verify configuration
```
Important Demonstration Limitation
This repository does not perform an actual VMware-to-OpenShift Virtualization migration.
The AWS EC2 environment is being used to reproduce the automation workflow.
An EC2 instance is not the same as a VM running under QEMU/KVM with the expected VirtIO guest-agent communication channel. Therefore, the QEMU Guest Agent package can be installed on the EC2 test system, but the service may not operate in the same way as it would on a VM running under OpenShift Virtualization.
The actual OpenShift Virtualization environment is outside the scope of this repository.
Real-World Scenario
The scenario being replicated is:
```
VMware VM
    |
    | VM Migration
    v
OpenShift Virtualization
    |
    v
Migrated VM
    |
    | Required configuration missing
    v
Post-Migration Checks
    |
    v
Checks Fail
    |
    v
Migration Reported as FAILED
```

In a real environment, an administrator may manually:

## Real-World Scenario
In a real environment, an administrator may manually:
```
| Step | Activity |
|---:|---|
| 1 | Log in to the migrated VM |
| 2 | Install required packages |
| 3 | Configure the required services |
| 4 | Enable and start the services |
| 5 | Perform post-migration checks |
| 6 | Confirm that the VM passes validation |
```
This project demonstrates how that type of manual activity can be converted into Ansible automation.

## Deployment Workflow
The complete workflow is:
```
1. Clone Repository
        |
        v
2. terraform init
        |
        v
3. terraform validate
        |
        v
4. terraform plan
        |
        v
5. terraform apply
        |
        v
6. AWS Infrastructure Created
        |
        v
7. Controller Initialized
        |
        v
8. Client Initialized
        |
        v
9. SSH Key Exchange
        |
        v
10. Inventory Updated
        |
        v
11. Ansible Connectivity Test
        |
        v
12. Server Configuration
        |
        v
13. Post-Migration Automation
```
## Terraform Commands
Initialize Terraform
```
terraform init
```
Terraform Commands
Initialize Terraform
bash
terraform init

Initializes the Terraform working directory and downloads the required provider.

##  Validate Terraform
```
terraform validate
```
Checks the Terraform configuration for syntax and configuration errors.

## Review the Plan
```
terraform plan
```
Shows the infrastructure changes Terraform intends to make.
Create Infrastructure
```
terraform apply
```
Creates the AWS infrastructure.


## Display Outputs
bash
terraform output


Displays the Terraform outputs, including the Controller and Client public IP addresses.

Ansible Command

After the Controller and Client are initialized, test Ansible connectivity with:

bash
ansible-playbook -i ansible/inventories/inventory.ini ping.yaml

A successful result confirms that the Controller can connect to the Client through Ansible.

Complete Workflow

The complete project can be summarized as:

                  Terraform
                      |
                      v
              AWS Infrastructure
                      |
          +-----------+-----------+
          |                       |
          v                       v
   Ansible Controller      Ansible Client
          |                       ^
          |                       |
          +-------- SSH ---------+
          |
          v
       Ansible
          |
     +----+----+
     |         |
     v         v
   Nginx     QEMU
            Guest Agent
               |
               v
       Configuration
        Verification
Why Terraform and Ansible Together?

Terraform and Ansible solve different parts of the automation workflow.

Terraform	Ansible
Infrastructure as Code	Configuration Management
Creates AWS resources	Configures existing servers
Creates VPC and networking	Installs packages
Creates IAM resources	Manages services
Creates EC2 instances	Performs server configuration
Defines infrastructure dependencies	Performs Day-2 operations
Manages infrastructure state	Executes configuration tasks

The project therefore follows:

Terraform → Provision the infrastructure
Ansible → Configure and manage the servers
Main Technologies
Technology	Role in the Project
AWS	Cloud infrastructure platform
Terraform	Infrastructure provisioning
Ansible	Server configuration and automation
Amazon EC2	Controller and Client instances
Amazon VPC	Network environment
IAM	AWS permissions
Amazon S3	SSH public-key transfer
SSH	Controller-to-Client communication
Nginx	Server configuration example
QEMU Guest Agent	Post-migration configuration example
Linux	Operating system environment
Security Note

The repository contains:

testing-dev-1.pem

A private SSH key should not be committed to a public Git repository.

For a production or publicly shared repository, use an appropriate secret-management approach and keep private credentials outside version control.

Related Blog

The detailed explanation and walkthrough for this project are available here:

Ansible Automation on AWS: Complete Setup, Nginx and QEMU Guest Agent

Further Learning
Ansible Automation Platform on OpenShift
Executing Ansible Jobs using AAP on OpenShift
Ansible Tower / AWX on Kubernetes
Disclaimer

This repository is a demonstration and learning environment.

The VMware-to-OpenShift Virtualization migration itself is not performed by this repository. The AWS environment is used to reproduce and automate representative configuration activities that may be required after VM migration.

The focus is on demonstrating how Terraform can provision the environment and Ansible can automate server-side and post-migration configuration tasks.

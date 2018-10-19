# Install Mesosphere DC/OS on virtualbox via docker-machine [WIP]

This repository is to test out running DC/OS locally using virtualbox and docker-machine to create a highly reproducable cluster. It is designed to be able to support installs, expands of nodes, and DC/OS ugprades. This will be resuing the same instructions that is used in production making this project to be easily maintained.

THIS PROJECT CURRENTLY UNDER DEVELOPMENT

## Prerequisites
- [Terraform 0.11.x](https://www.terraform.io/downloads.html)
- go
- Virtualbox
- docker-machine

## Getting Started

1. Create directory
2. Install dockermachine provider
3. Initialize Terraform
4. Configure settings
5. Apply Terraform


## Create Installer Directory

Make your directory where Terraform will download and place your Terraform infrastructure files.

```bash
mkdir dcos-installer
cd dcos-installer
```

Run this command below to have Terraform initialized from this repository. There is **no git clone of this repo required** as Terraform performs this for you.

```
terraform init
```
## Install dockermachine provider

Install the dockermachine provider as this is not a native provider to terraform.

```
go get github.com/gstruct/terraform-provider-dockermachine
```

## Deploy DC/OS

### Deploying with Default Configuration

We've provided sensible defaults if you would want to play around with Mesosphere DC/OS. The default variables are tracked in  [variables.tf](/aws/variables.tf). 

Just run this command to deploy a multi-master setup in the cloud. **3 agents will be deployed** for you; 2 private agents, 1 public agent.

```bash
terraform apply 
```
<!--- removing unsupported docs
### Deploying with Custom Configuration

The default variables are tracked in the [variables.tf](/aws/variables.tf) file. Since this file can be overwritten during updates when you may run `terraform get --update` when you fetch new releases of DC/OS to upgrade to, it's best to use the [desired_cluster_profile.tfvars](/aws/desired_cluster_profile.tfvars.example) and set your custom Terraform and DC/OS flags there. This way you can keep track of a single file that you can use manage the lifecycle of your cluster.

#### Supported Operating Systems

Here is the [list of operating systems supported](/aws/modules/dcos-tested-aws-oses/platform/cloud/aws).

#### Supported DC/OS Versions

Here is the [list of DC/OS versions supported](https://github.com/dcos/tf_dcos_core/tree/master/dcos-versions).

**Note**: Master DC/OS version is not meant for production use. It is only for CI/CD testing.

To apply the configuration file, you can use this command below.

```bash
terraform apply -var-file desired_cluster_profile.tfvars
```

## Advanced YAML Configuration

We have designed this project to be flexible. Here are the example working variables that allows very deep customization by using a single `tfvars` file.

For advanced users with stringent requirements, here are DC/OS flag examples you can simply paste in `desired_cluster_profile.tfvars`.

```bash
$ cat desired_cluster_profile.tfvars
dcos_version = "1.11.1"
os = "centos_7.3"
num_masters = "3"
num_private_agents = "2"
num_public_agents = "1"
ssh_key_name = "default" 
dcos_cluster_name = "DC/OS Cluster"
dcos_cluster_docker_credentials_enabled =  "true"
dcos_cluster_docker_credentials_write_to_etc = "true"
dcos_cluster_docker_credentials_dcos_owned = "false"
dcos_cluster_docker_registry_url = "https://index.docker.io"
dcos_use_proxy = "yes"
dcos_http_proxy = "example.com"
dcos_https_proxy = "example.com"
dcos_no_proxy = <<EOF
# YAML
 - "internal.net"
 - "169.254.169.254"
EOF
dcos_overlay_network = <<EOF
# YAML
    vtep_subnet: 44.128.0.0/20
    vtep_mac_oui: 70:B3:D5:00:00:00
    overlays:
      - name: dcos
        subnet: 12.0.0.0/8
        prefix: 26
EOF
dcos_rexray_config = <<EOF
# YAML
  rexray:
    loglevel: warn
    modules:
      default-admin:
        host: tcp://127.0.0.1:61003
    storageDrivers:
    - ec2
    volume:
      unmount:
        ignoreusedcount: true
EOF
dcos_cluster_docker_credentials = <<EOF
# YAML
  auths:
    'https://index.docker.io/v1/':
      auth: Ze9ja2VyY3licmljSmVFOEJrcTY2eTV1WHhnSkVuVndjVEE=
EOF
```
**Note**: The YAML comment is required for the DC/OS specific YAML settings.

## Upgrading DC/OS  

You can upgrade your DC/OS cluster with a single command. This Terraform script was built to perform installs and upgrades from the inception of this project. 

With the upgrade procedures below, you can also have finer control on how masters or agents upgrade at a given time. This will give you the ability to change the parallelism of master or agent upgrades.

###  Rolling Upgrade

#### Masters Sequentially, Agents Parellel

Supported upgraded by dcos.io.

```bash
terraform apply -var-file desired_cluster_profile.tfvars -var state=upgrade -target null_resource.bootstrap -target null_resource.master -parallelism=1
terraform apply -var-file desired_cluster_profile.tfvars -var state=upgrade
```

#### All Roles Simultaniously

Not supported by dcos.io but it works without dcos_skip_checks enabled.

```bash
terraform apply -var-file desired_cluster_profile.tfvars -var state=upgrade
```

## Maintenance

If you would like to add more or remove agents from your cluster, you can do so by telling Terraform your desired state and it will make sure it gets you there. 

For example, if I have 2 private agents and 1 public agent in my `-var-file` I can override that flag by specifying the `-var` flag. It has higher priority than the `-var-file`.

### Adding Agents

```bash
terraform apply \
-var-file desired_cluster_profile \
--var num_private_agents=5 \
--var num_public_agents=3
```

### Removing Agents

```bash
terraform apply \
-var-file desired_cluster_profile \
--var num_private_agents=1 \
--var num_public_agents=1
```

## Redeploy an Existing Master

If you wanted to redeploy a problematic master (ie. storage filled up, not responsive, etc), you can tell Terraform to redeploy during the next cycle.

**Note:** This only applies to DC/OS clusters that have set their `dcos_master_discovery` to `master_http_loadbalancer` and not `static`.

### Master Node

Taint master node:

```bash
terraform taint aws_instance.master.0 # The number represents the agent in the list
```

Redeploy master node:

```bash
terraform apply -var-file desired_cluster_profile
```

## Redeploy an Existing Agent

If you wanted to redeploy a problematic agent, (ie. storage filled up, not responsive, etc), you can tell terraform to redeploy during the next cycle.

### Private Agents

Taint private agent:

```bash
terraform taint aws_instance.agent.0 # The number represents the agent in the list
```

Redeploy agent:

```bash
terraform apply -var-file desired_cluster_profile
```

### Public Agents

Taint private agent:

```bash
terraform taint aws_instance.public-agent.0 # The number represents the agent in the list
```

Redeploy agent:

```bash
terraform apply -var-file desired_cluster_profile
```
--->
## Destroy Cluster

You can shutdown/destroy all resources from your environment by running this command below:

```bash
terraform destroy -var-file desired_cluster_profile
```

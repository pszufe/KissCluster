# Welcome to KissCluster 
The simplest cluster computing solution!
- The only no-frills HPC solution with KISS approach - one command to setup the cluster (takes 30 sec to complete)
- serverless master hosted in AWS - no expenses for hosting your master node (the cluster definition entirely fits into AWS free tier)
- cross-cloud - mix nodes from various cloud vendors: AWS, Azure (note: TODO), Google  (note: TODO)
- fully hybrid - mix'n'match on-prem and cloud nodes in your cluster (note: TODO)
- scallable - run clusters with hundreds or thousands of nodes - just edit `config.conf` file

# How to start

## Setting up your AWS cloud 

For quick start let's use AWS Ohio region.

### Set up your permission
**Beginner?** The easiest way to configure your permissions along with the S3 bucket is to [click this AWS Cloud Formation script](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?templateURL=https://s3.us-east-2.amazonaws.com/szufel-public/kissRoleS3.yaml&stackName=kissc) link while being logged-in to your AWS account. Select the checkbox *I acknowledge that AWS CloudFormation might create IAM resources.*, click *Create*, wait 4 minutes and you are done. 

**Advanced?** [Here](https://raw.githubusercontent.com/pszufe/KissCluster/master/aws/kisscPolicy.json) is the JSON Policy template. You need to create the S3 bucket yourself and edit the bucket name in the policy file. Please note that the S3 bucket should be in the same region where the cluster information is stored (however, the nodes can be anywhere). Once you create the policy: if you use your own machine with `aws configure` command -- assign it to your IAM accout, if you use AWS machine create a Role of type : AWS service - EC2 and attach the role to the instance. 

### Install the software

Just joking, there is no install - just download and unzip wherever you like.

In order to start just type (we assume the current release is 0.0.4):
```bash
wget -L https://github.com/pszufe/KissCluster/archive/0.0.4.zip
uznip 0.0.4.zip
cd KissCluster-0.0.4/
```

### Create the cluster 
\[For all commands we assume that your are in KissCluster's home folder\]
```bash 
./kissc create --passwordless_ssh keyname --s3_bucket s3://kissc-data-1qlz7ow7tfqmo/ myc@us-east-2
```
This command creates a cluster named `myc` in the `us-east-2` AWS region with a passwordless SSH across the nodes (not needed for some cluster configuration, you can skip this option if you do not need it) and the S3 bucket `s3://kissc-data-1qlz7ow7tfqmo/` to store the data (update the bucket name to match your configuration). 

The software will create your cluster. However the cluster has zero nodes and the KissCluster cluster master is serverless - so there is not a single server yet. 

### Create a AWS SecurityGroup (AWS passwordless ssh nodes only)

If you need to have a passwordless SSH (required by some cluster types - e.g. [Julia parallel](https://docs.julialang.org/en/latest/manual/parallel-computing) you need to make sure that network transfer is allowed among your nodes. On the AWS platform simply create a SecurityGroup (enable the access to it from your computer) and next edit to to enable access to this security group from within itself.

### Add nodes to the cluster

Your previous command has generated `cloud_init_node_myc.sh` file. On whichever machine (that has properly configured AWS permissions) you run it - the machine becomes cluster node (TODO: tested only as cloud-init script on AWS Ubuntu instances). 
To see the file contents type:
```bash
cat cloud_init_node_myc.sh
```



The software will configure your cluster and will generate a `cloud_init_node_PKG.sh` file. 
Run the file on any Ubuntu Linux machine and it becomes a node in your cluster and starts the job straight away!

Notes:
- KissCluster uses AWS S3 and DynamoDB - you need to define AWS access credentials for those two services in one AWS region (TODO docs)
- Each process spawned within the cluster will be appended by a jobid number (available as a parameter appended to command) - you can use this number to adjust work for processes
- the collected results will contain stadnard output and standard error of your processes - all gzipped and alligned on S3 bucket - ready for further analysis. 



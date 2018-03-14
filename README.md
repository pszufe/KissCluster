# Welcome to KissCluster 

The simplest cluster computing solution!
- The only no-frills HPC solution with KISS approach - one command to setup the cluster (takes 30 sec to complete)
- serverless master hosted in AWS - no expenses for hosting your master node (the cluster definition entirely fits into AWS free tier)
- cross-cloud - mix nodes from various cloud vendors: AWS, Azure (note: TODO), Google  (note: TODO)
- fully hybrid - mix'n'match on-prem and cloud nodes in your cluster (note: TODO)
- scallable - run clusters with hundreds or thousands of nodes - just edit `config.conf` file

The overall KissCluster architecture is presented below:

![alt text](https://raw.githubusercontent.com/pszufe/KissCluster/master/manual/architecture1.png "KissCluster architecture overview")



# How to start

For quick start let's use AWS Ohio region.

### Step (1) Set up your permissions
**Beginner?** The easiest way to configure your permissions along with the S3 bucket (the place were you store your cluster information and your computation results) is to [click this AWS Cloud Formation script](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?templateURL=https://s3.us-east-2.amazonaws.com/szufel-public/kissRoleS3.yaml&stackName=kissc) link while being logged-in to your AWS account. Select the checkbox *I acknowledge that AWS CloudFormation might create IAM resources.*, click *Create*, wait 4 minutes and you are done. 

**Advanced?** [Here](https://raw.githubusercontent.com/pszufe/KissCluster/master/aws/kisscPolicy.json) is the JSON Policy template. You need to create the S3 bucket yourself and edit the bucket name in the policy file. Please note that the S3 bucket should be in the same region where the cluster information is stored (however, the nodes can be anywhere). Once you create the policy: if you use your own machine with `aws configure` command -- assign it to your IAM accout, if you use AWS machine create a Role of type : AWS service - EC2 and attach the role to the instance. 

### Step (2) Create a AWS SecurityGroup (AWS passwordless-ssh nodes only)

If you need to have a passwordless SSH (required by some cluster types - e.g. [Julia parallel](https://docs.julialang.org/en/latest/manual/parallel-computing) you need to make sure that the network traffic is allowed across all your cluster nodes. On the AWS platform simply create a SecurityGroup (enable the access to it from your computer) and next edit it to enable access to this security group from within itself. See [this picture](https://github.com/pszufe/KissCluster/blob/master/manual/aws_passwordless_ssh.png) for reference.

### Step (3) Have an Ubuntu Linux instance to execute commands on your cluster 

**Beginner?** 
Launch a tiny EC2 instance to manage your cluster. you can use any Ubuntu node or maybe you can create any own Ubuntu-based AMI.
For example here is [a test AMI with Julia](https://us-east-2.console.aws.amazon.com/ec2/home?region=us-east-2#LaunchInstanceWizard:ami=ami-aaab89cf) and here is [a test AMI with NetLogo](https://us-east-2.console.aws.amazon.com/ec2/home?region=us-east-2#LaunchInstanceWizard:ami=ami-ba614cdf).

**Advanced?**
You can configure cluster management enviroment on your laptop. Just run aws configure and configure your AWS CLI envirment to point to an IAM user created in the *Set up your permissions* section.

### Step (4) Install the software

Just joking, there is no install - just download and unzip wherever you like.

In order to start just type (we assume the current release is 0.0.5):
```bash
wget -L https://github.com/pszufe/KissCluster/archive/0.0.5.zip
unzip 0.0.5.zip
cd KissCluster-0.0.5/
```

### Step (5) Create the cluster 
\[For all commands we assume that your are in KissCluster's home folder\]


#### Standard cluster (grid computing)
This is a typical configuration for grid computing where no direct communication between nodes is required. Examples include launching NetLogo, Java or Python simulation and explorating its parameter space.

```bash 
./kissc create --s3_bucket s3://kissc-data-1qlz7ow7tfqmo/ myc@us-east-2
```
This command creates a cluster named `myc` in the `us-east-2` AWS region and the S3 bucket `s3://kissc-data-1qlz7ow7tfqmo/` to store the data (update the bucket name to match your configuration). 


#### Passwordless SSH cluster

This is a configuration when you need a passwordless SSH between cluster nodes. This is the way to go if you need the nodes direct acces to each other. A good example is Julia parallel.

```bash 
./kissc create --passwordless_ssh keyname --s3_bucket s3://kissc-data-1qlz7ow7tfqmo/ myc@us-east-2
```
This command creates a cluster named `myc` in the `us-east-2` AWS region with a passwordless SSH across the nodes and the S3 bucket `s3://kissc-data-1qlz7ow7tfqmo/` to store the data (update the bucket name to match your configuration). 


Please note that the above command will create the cluster. However, the cluster has zero nodes and the KissCluster cluster master is serverless - so there is not a single server yet. 

### Step (6) Add nodes to the cluster

The `kissc create` command has generated `cloud_init_node_myc.sh` file. On whichever machine (that has properly configured AWS permissions) you run it - the machine becomes a cluster node (TODO: tested only as cloud-init script on AWS Ubuntu instances). 
To see the file contents type:
```bash
cat cloud_init_node_myc.sh
```

In order to add node to the cluster on AWS:
- Select *Launch instance* and choose any Ubuntu image and hardware type that you like
- Select the IAM role that your previously created (see *Set up your permissions* section)
- Open *Advanced details* and paste the text from the `cat cloud_init_node_myc.sh` file
- If using passwordless SSH remember to select the Security Group that you previously created (see *Create a AWS SecurityGroup* section). 

### Step (7) Check if it works
To list your clusters and see how many nodes and job queues they have run
```bash
 ./kissc list us-east-2
```

To see the cluster nodes run:
```bash
 ./kissc nodes myc@us-east-2
```

### Step (8) Submit a job to your cluster
This submits a "Hello world" bash job onto your cluster that will be executed 100 times. 
```bash
./kissc submit --job_command "bash program.sh" --folder sample_app_bash/ --max_jobid 100 myc@us-east-2
```

To see the list of jobs submitted to your cluster and their status run:
```bash
./kissc queues myc@us-east-2
```

### Deleting a cluster
```bash
./kissc delete myc@us-east-2
```
Only the information about the cluster in DynamoDB tables is deleted. The nodes and S3 data are not affected by this command. 


### Notes:
- Each process spawned within the cluster will have the jobid number parameter (available as the last parameter appended to command) - you can use this number to adjust work for processes
- the collected results will contain standard output and standard error of your processes - all gzipped and alligned on S3 bucket - ready for further analysis. 

# Getting help

In order to see the list of available KissCluster commands type 
```bash
./kissc
```

In order to see help for a particular command try 
```
./kissc <command> help
```
For example this command:
```bash
./kissc create help
```
will display a full list of options for cluster creation.


# FAQ

**What are the software prerequisites?**

Ans:
```bash
sudo apt --yes install jq awscli
```
Please note that if those packages are not available KissCluster will try to install them automatically the first time it is run.

**How to configure the amount of workers per cluster node?**

Ans:

In the default configuration there is one worker per one cluster node core. If you want something different have a look inside `config.conf`. The configuration changes need to be made before a cluster is created.

**How does KissCluster control user processes**

Ans: please have a look a the picture below

![alt text](https://raw.githubusercontent.com/pszufe/KissCluster/master/manual/kissc_process.png "Controlling worker processes within KissCluster")




**Where is cluster data stored**

Ans:

There is no master node in KissCluster. Instead a DynamoDB database is used. Please see the picture below for data structure reference.

![alt text](https://raw.githubusercontent.com/pszufe/KissCluster/master/manual/architecture2.png "KissCluster data structure overview")


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

The easiest way to configure your permissions along with the S3 bucket is to [click this AWS Cloud Formation script](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?templateURL=https://s3.us-east-2.amazonaws.com/szufel-public/kissRoleS3.yaml&stackName=kissc) link,


In order to start just type (we assume the current release is 0.0.4):

```bash
wget -L https://github.com/pszufe/KissCluster/archive/0.0.4.zip
uznip 0.0.4.zip
cd KissCluster-0.0.4/
```

Now you are read

Next, create your cluster. Below is a real-world example - a java app in the folder ./app will packed for distributed HPC execution. The cluster name is PKG and distributed execution enviroment within the cluster is named N100_W50.

`
bash KissCluster/kissc-start.sh --region us-east-2  --folder ./app --command "java -server -Xmx1500M -cp lib/*:bin experiments.Exp eriments_N100_W50_AKG_OCBA_AOCBA" --queue_name N100_W50 --s3_bucket s3://aws-s3-bucket-name-to-store-your-results PKG
`

The software will configure your cluster and will generate a `cloud_init_node_PKG.sh` file. 
Run the file on any Ubuntu Linux machine and it becomes a node in your cluster and starts the job straight away!

Notes:
- KissCluster uses AWS S3 and DynamoDB - you need to define AWS access credentials for those two services in one AWS region (TODO docs)
- Each process spawned within the cluster will be appended by a jobid number (available as a parameter appended to command) - you can use this number to adjust work for processes
- the collected results will contain stadnard output and standard error of your processes - all gzipped and alligned on S3 bucket - ready for further analysis. 



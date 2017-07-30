#!/bin/bash

if [[ $# -ne 5 ]]; then
    echo Usage:
	echo create_cluster.sh clustername region command folder s3_bucket
	echo ""
	echo clustername - name of your computation
	echo region - AWS region where the computations will be carried out
	echo command - command to be executed on each node. \
		An additional parameter jobid will be added \
		to each command executed on the clustername. \
		The command will be executed on nodes within the folder given as the next parameter
	echo folder - folder that contains all files needed to execute the command. \
		The contents of the folder will be copied to each cluster node
	echo s3_bucket - name of an AWS S3 bucket that will be used to store application code \
		and will be used for result collection.
	exit 1
fi


CLUSTERNAME=$1
REGION=$2
COMMAND=$3
HOME_DIR=$4
S3=$5

S3_LOCATION=${S3}/${CLUSTERNAME}

JOBSTABLE="kissc_jobs_${CLUSTERNAME}"
CLUSTERTABLE="kissc_cluster_${CLUSTERNAME}"

CLOUD_INIT_FILE=./cloud_init_node_${CLUSTERNAME}.sh

function wait4table {
    TABLENAME=$1
    while  
		echo "Waiting for DynamoDB table ${TABLENAME} in region ${REGION} to be active"
		sleep 3
		status=`aws dynamodb --region ${REGION} describe-table --table-name ${TABLENAME} 2>/dev/null  | jq -r ".Table.TableStatus"`
		[[ $status != ACTIVE ]]
	do
		:
	done
	echo "DynamoDB table ${TABLENAME} created"
}

set -e

createddate=$(date '+%Y%m%dT%H%M%SZ')

#sudo apt-get update
sudo apt install awscli jq --yes

res=`aws dynamodb --region ${REGION} describe-table --table-name kissc_clusters 2>/dev/null` || echo "DynamoDB table kissc_clusters not found"
if [[ -z "${res// }" ]]; then
  echo "Creating DynamoDB table kissc_clusters"
  res=`aws dynamodb --region ${REGION} create-table --table-name kissc_clusters \
	--attribute-definitions AttributeName=clustername,AttributeType=S \
	--key-schema AttributeName=clustername,KeyType=HASH \
	--provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5`
   wait4table kissc_clusters
fi

echo "Resetting the counters for ${CLUSTERNAME}"

res=`aws dynamodb --region ${REGION} put-item --table-name kissc_clusters \
  --item '{"clustername":{"S":"'"${CLUSTERNAME}"'"},"command":{"S":"'"${COMMAND}"'"} , "jobid":{"N":"0"}, "nodeid":{"N":"0"}, "S3_folder":{"S":"'${S3_LOCATION}'"}, "date":{"S":"'${createddate}'"}, "creator":{"S":"'${USER}'@'${HOSTNAME}'"}}  '`



res=`aws dynamodb --region ${REGION} describe-table --table-name ${JOBSTABLE} 2>/dev/null` || echo "DynamoDB table ${JOBSTABLE} not found"

if [[ ! -z "${res// }" ]]; then
  echo "Dropping DynamoDB table ${JOBSTABLE}"
  res=`aws dynamodb --region ${REGION}  delete-table --table-name ${JOBSTABLE}`
  while  
    echo "Waiting for DynamoDB table ${JOBSTABLE} to be dropped"
    sleep 3
	res=`aws dynamodb --region ${REGION} describe-table --table-name ${JOBSTABLE} 2>/dev/null`
	[[ ! -z "${res// }" ]]
   do
     :
   done
   echo "DynamoDB table ${JOBSTABLE} has been dropped"
fi


res=`aws dynamodb --region ${REGION} describe-table --table-name ${CLUSTERTABLE} 2>/dev/null` || echo "DynamoDB table ${CLUSTERTABLE} not found"

if [[ ! -z "${res// }" ]]; then
  echo "Dropping DynamoDB table ${CLUSTERTABLE}"
  res=`aws dynamodb --region ${REGION}  delete-table --table-name ${CLUSTERTABLE}`
  while  
    echo "Waiting for DynamoDB table ${CLUSTERTABLE} to be dropped"
    sleep 3
	res=`aws dynamodb --region ${REGION} describe-table --table-name ${CLUSTERTABLE} 2>/dev/null`
	[[ ! -z "${res// }" ]]
   do
     :
   done
   echo "DynamoDB table ${CLUSTERTABLE} has been dropped"
fi

echo "Creating DynamoDB table ${JOBSTABLE}"
res=`aws dynamodb --region ${REGION}  create-table --table-name ${JOBSTABLE} \
	--attribute-definitions AttributeName=jobid,AttributeType=N \
	--key-schema AttributeName=jobid,KeyType=HASH \
	--provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5`


echo "Creating DynamoDB table ${CLUSTERTABLE}"
res=`aws dynamodb --region ${REGION}  create-table --table-name ${CLUSTERTABLE} \
	--attribute-definitions AttributeName=nodeid,AttributeType=N \
	--key-schema AttributeName=nodeid,KeyType=HASH \
	--provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1`



wait4table ${JOBSTABLE}
wait4table ${CLUSTERTABLE}
	

echo Deleting S3 folder ${S3_LOCATION}/app
res=`aws s3 --region ${REGION} rm --recursive ${S3_LOCATION}/app`


tmpname=`tempfile`
printf "#!/bin/bash\n\n${COMMAND} \$1" > ${tmpname}

echo "copying application data to S3" 
aws s3 --region ${REGION} cp --recursive ${HOME_DIR} ${S3_LOCATION}/app
aws s3 --region ${REGION} cp ${tmpname} ${S3_LOCATION}/app/job.sh


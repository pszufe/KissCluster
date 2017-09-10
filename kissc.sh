#!/bin/bash
set -e

function contains {
    [[ $1 =~ (^|[[:space:]])$2($|[[:space:]]) ]] && return 0 || return 1
}

function basic_usage {
   echo "usage: kissc.sh <command> [parameters] clustername@region"
   echo "region : AWS region where the cluster information will be stored (e.g. us-east-1)"
   if [[ -n "$2" ]]; then
     echo "kissc: error: $2"
   fi
   echo "The following commands are available:"
   echo "create : Creates a cluster in the given region with the given name. If the cluster already exists its data will be reset."
   echo "submit : Submits a job to the cluster"
   echo "delete : Deletes a cluster"
   echo "Run kissc.sh <command> help to see help for a specific command"
   if [[ -n "$2" ]]; then
     echo "kissc: error: $2"
   fi
   exit $1
}

function usage_create {
    if [[ -n "$2" ]]; then
        echo "kissc create: error: $2"
    fi
    echo "Usage:"
    echo "kissc.sh create [parameters] clustername@region"
    echo "Supported parameters:"
    echo "--passwordless_ssh keyname - key name that will be used to configure passwordless ssh across cluster nodes. "
    echo "--user username - username that will be used on cluster nodes, defaults to 'ubuntu'"
    echo "clustername@region - name and region of your cluster"
    if [[ -n "$2" ]]; then
        echo "kissc: error: $2"
    fi
    exit $1
}

function usage_delete {
    if [[ -n "$2" ]]; then
        echo "kissc delete: error: $2"
    fi
    echo "Usage:"
    echo "kissc.sh delete clustername@region"
    echo "Deletes the given cluster information."
    echo "This operation does not have additional parameters."
    echo "Note that the function call does try to terminate the nodes in any way!"
    echo "If you run your nodes in AWS you should try to terminate them manually"
    echo "clustername@region - name and region of your cluster"
    if [[ -n "$2" ]]; then
        echo "kissc: error: $2"
    fi
    exit $1
}


function usage_submit {
    if [[ -n "$2" ]]; then
        echo "kissc submit: error: $2"
    fi
    echo "Usage:"
    echo "kissc.sh submit --bash_command bash_command --folder folder --s3_bucket s3_bucket [other parameters] clustername@region"
    echo ""
    echo "Supported parameters:"
    echo "--bash_command bash_command - command to be executed on each node. "
    echo "  Note that an additional parameter jobid will be added "
    echo "  to each command executed on the clustername. "
    echo "  The command will be executed on nodes within the folder given as the next parameter"
    echo "--folder folder - a local path  that contains all files needed to execute the command. "
    echo "  The contents of the folder will be copied to each cluster node"
    echo "--s3_bucket s3_bucket - name of an AWS S3 bucket (e.g. s3://mybucketname/) that will be used "
    echo "  to store cluster data and will be used for result collection (mandatory parameter)"
    echo "--min_jobid minjobid - starting job id - an optional parameter, requires command and folder parameters"
    echo "--max_jobid maxjobid - ending job id - an optional parameter, requires command and folder parameters"
    echo "--queue_name queue_name a label that will describe a particular queue created if the command parameter is given (optional)"
    echo "clustername@region - name and region of your cluster"
    if [[ -n "$2" ]]; then
        echo "kissc: error: $2"
    fi
    exit $1
}

COMMAND=$1

if [[ -z $COMMAND ]] || ! `contains "create submit delete" $COMMAND`; then
   basic_usage 1 "the following arguments are required: command"
fi

if [[ "$2" == "help" ]]; then
	if [[ $COMMAND = "create" ]]; then
	  usage_create 0
	elif [[ $COMMAND = "submit" ]]; then
	  usage_submit 0
	elif [[ $COMMAND = "delete" ]]; then
	   usage_delete 0
	fi
	basic_usage 1 "Unexpected error"
fi


REGION=""
CLUSTERNAME=""
BASH_COMMAND=""
HOME_DIR=""
S3=""
MINJOBID=1
MAXJOBID=1000000000
QUEUE_NAME=""
KEY_NAME=""
USERNAME=ubuntu

shift
# shifts skips the <command> parameter
while [[ $# -gt 1 ]]
do
key="$1"
case $key in
    -c|--command)
    BASH_COMMAND="$2"
	shift
    ;;
    -f|--folder)
    HOME_DIR="$2"
	shift
    ;;
	-s|--min_jobid)
    MINJOBID="$2"
	shift
    ;;
	-e|--max_jobid)
    MAXJOBID="$2"
	shift
    ;;
    -s|--s3_bucket)
    S3="$2"
	shift
    ;;
    -h|--help)
    HELP=1
    ;;
    -n|--queue_name)
    QUEUE_NAME="$2"
	shift
    ;;
    -p|--passwordless_ssh)
    KEY_NAME="$2"
	shift
    ;;
    -u|--user)
    USERNAME="$2"
	shift
    ;;
    *)
    ERROR=1
	echo "Error: Unknown option $key"
	break;
    ;;
esac
shift
done


if [[ -n $1 ]]; then
    vals=(${1//@/ })
    CLUSTERNAME=${vals[0]}
	REGION=${vals[1]}
    if [[ -z ${REGION} ]]; then
	   basic_usage 1 "The last parameter does not contain region name. Should be clustername@regionname"
    fi
	if [[ -z ${QUEUE_NAME} ]]; then
	   QUEUE_NAME=${CLUSTERNAME}
	fi
else
	basic_usage 1 "The last parameter (clustername@region) not given"
fi





function checkinstall {
  PKG_NAME=$1
  PKG_OK=$(dpkg-query -W --showformat='${Status}\n' ${PKG_NAME}|grep "install ok installed")
  if [ "" == "$PKG_OK" ]; then
    echo "Missing package ${PKG_NAME}. "
	echo "Trying to install ${PKG_NAME}. "
    sudo apt --yes install $PKG_NAME
  fi
}

checkinstall jq
checkinstall awscli



if [[ $COMMAND = "create" ]]; then
  if [[ -n $KEY_NAME ]];then
     KEY_FILE=~/.ssh/$KEY_NAME
     echo "Creating a key $KEY_NAME for passwordless SSH in file $KEY_FILE"
     ssh-keygen -P "" -t rsa -f $KEY_FILE
     printf "\nUser $USERNAME\nPubKeyAuthentication yes\nIdentityFile $KEY_NAME\n" >> ~/.ssh/config
  fi

elif [[ $COMMAND = "submit" ]]; then
  if [[ -z $S3 ]]; then
      usage_submit 1 "missing --s3_bucket parameter"
  fi
  if [[ -z $BASH_COMMAND ]]; then
      usage_submit 1 "missing --bash_command parameter"
  fi
  if [[ -z $HOME_DIR ]]; then
      usage_submit 1 "missing --folder parameter"
  fi

elif [[ $COMMAND = "delete" ]]; then
   echo delete
fi

exit 0


S3_LOCATION=${S3}/${CLUSTERNAME}
JOBSTABLE="kissc_jobs_${CLUSTERNAME}"
QUEUESTABLE="kissc_queues_${CLUSTERNAME}"
NODESTABLE="kissc_nodes_${CLUSTERNAME}"

CLOUD_INIT_FILE=./cloud_init_node_${CLUSTERNAME}.sh

function wait4table {
    TABLENAME=$1
    while
        status=`aws dynamodb --region ${REGION} describe-table --table-name ${TABLENAME} 2>/dev/null  | jq -r ".Table.TableStatus"`
		if [[ $status != "ACTIVE" ]]; then
			echo "Waiting for DynamoDB table ${TABLENAME} in region ${REGION} to be active"
			sleep 3
		fi
        [[ $status != "ACTIVE" ]]
    do
        :
    done
    echo "DynamoDB table ${TABLENAME} created"
}

function droptable {
    TABLENAME=$1
	res=`aws dynamodb --region ${REGION} describe-table --table-name ${TABLENAME} 2>/dev/null` || echo "DynamoDB table ${TABLENAME} not found"
	if [[ ! -z "${res// }" ]]; then
	  echo "Dropping DynamoDB table ${TABLENAME}"
	  res=`aws dynamodb --region ${REGION}  delete-table --table-name ${TABLENAME}`
	  while
	    res=`aws dynamodb --region ${REGION} describe-table --table-name ${TABLENAME} 2>/dev/null`
		echo "Waiting for DynamoDB table ${TABLENAME} to be dropped"
		sleep 3
		if [[ ! -z "${res// }" ]]; then
			echo "Waiting for DynamoDB table ${TABLENAME} to be dropped"
			sleep 3
		fi
		[[ ! -z "${res// }" ]]
	   do
		 :
	   done
	   echo "DynamoDB table ${TABLENAME} has been dropped"
	fi
}

createddate=$(date '+%Y%m%dT%H%M%SZ')


res=`aws dynamodb --region ${REGION} describe-table --table-name kissc_clusters 2>/dev/null` || echo "DynamoDB table kissc_clusters not found"
if [[ -z "${res// }" ]]; then
  echo "Creating DynamoDB table kissc_clusters"
  res=`aws dynamodb --region ${REGION} create-table --table-name kissc_clusters \
    --attribute-definitions AttributeName=clustername,AttributeType=S \
    --key-schema AttributeName=clustername,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=4,WriteCapacityUnits=1`
   wait4table kissc_clusters
fi

echo "Resetting the counters for ${CLUSTERNAME}"

res=`aws dynamodb --region ${REGION} put-item --table-name kissc_clusters \
  --item '{"clustername":{"S":"'"${CLUSTERNAME}"'"},"nodeid":{"N":"0"}, \
           "queueid":{"N":"0"},"currentqueueid":{"N":"0"}, \
		   "S3_folder":{"S":"'${S3_LOCATION}'"}, "date":{"S":"'${createddate}'"},\
		   "creator":{"S":"'${USER}'@'${HOSTNAME}'"}}  '`



droptable ${NODESTABLE}
droptable ${QUEUESTABLE}
droptable ${JOBSTABLE}


echo "Creating DynamoDB table ${NODESTABLE}"
res=`aws dynamodb --region ${REGION}  create-table --table-name ${NODESTABLE} \
    --attribute-definitions AttributeName=nodeid,AttributeType=N \
    --key-schema AttributeName=nodeid,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1`


echo "Creating DynamoDB table ${QUEUESTABLE}"
res=`aws dynamodb --region ${REGION}  create-table --table-name ${QUEUESTABLE} \
    --attribute-definitions AttributeName=queueid,AttributeType=N \
    --key-schema AttributeName=queueid,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5`

echo "Creating DynamoDB table ${JOBSTABLE}"
res=`aws dynamodb --region ${REGION}  create-table --table-name ${JOBSTABLE} \
    --attribute-definitions AttributeName=queueid,AttributeType=N AttributeName=jobid,AttributeType=N  \
    --key-schema AttributeName=queueid,KeyType=HASH AttributeName=jobid,KeyType=RANGE \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5`




wait4table ${NODESTABLE}
wait4table ${QUEUESTABLE}
wait4table ${JOBSTABLE}


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


if [[ ! -z ${COMMAND} ]];then 
    bash ${DIR}/kissc-qsub.sh --region ${REGION} --command "${COMMAND}" \
		--folder "${HOME_DIR}" --s3_bucket ${S3} --queue_name "${QUEUE_NAME}" \
		--min_jobid ${MINJOBID} --max_jobid ${MAXJOBID} "${CLUSTERNAME}"
fi




S3_RUN_NODE_SCRIPT=${S3_LOCATION}/cluster/run_node_${CLUSTERNAME}.sh

aws s3 --region ${REGION} cp ${DIR}/src/job_envelope.sh ${S3_LOCATION}/cluster/job_envelope.sh
aws s3 --region ${REGION} cp ${DIR}/src/run_node.sh ${S3_RUN_NODE_SCRIPT}

printf "#!/bin/bash\n\n" > ${CLOUD_INIT_FILE}
printf "CLUSTERNAME=${CLUSTERNAME}\n" >> ${CLOUD_INIT_FILE}
printf "REGION=${REGION}\n" >> ${CLOUD_INIT_FILE}
printf "S3_RUN_NODE_SCRIPT=${S3_RUN_NODE_SCRIPT}\n\n" >> ${CLOUD_INIT_FILE}
cat ${DIR}/src/cloud_init_template.sh >> ${CLOUD_INIT_FILE}
chmod +x ${CLOUD_INIT_FILE}
aws s3 --region ${REGION} cp ${CLOUD_INIT_FILE} ${S3_LOCATION}/cluster/

printf "\nSUCCESS!\n"
printf "The cluster ${CLUSTERNAME} has been successfully build!  \n"
printf "Now you can simply run ${CLOUD_INIT_FILE} on any AWS EC2 machine to start processing on your cluster. \n"
printf "${CLOUD_INIT_FILE} can also be used as a cloud-init configuration for EC2 instances. \n"

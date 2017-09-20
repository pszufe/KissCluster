#!/bin/bash

set -e

BASH_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. ${BASH_FILE_DIR}/config.conf
. ${BASH_FILE_DIR}/kissc-lib.sh


function basic_usage {
   echo "usage: kissc <command> [parameters] [clustername@]region"
   echo "region : AWS region where the cluster information will be stored (e.g. us-east-1)"
   if [[ -n "$2" ]]; then
     echo "kissc: error: $2"
   fi
   echo "The following commands are available:"
   echo "create : Creates a cluster."
   echo "submit : Submits a job to the cluster."
   echo "delete : Deletes a cluster."
   echo "list : List all clusters."
   echo "nodes : List nodes of a specific cluster."
   echo "queues : List queues of a specific cluster."
   echo "Run kissc <command> help to see help for a specific command"
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
    echo "kissc create --s3_bucket s3_bucket [other parameters] clustername@region"
    echo "Supported parameters:"
    echo "--s3_bucket s3_bucket - name of an AWS S3 bucket (e.g. s3://mybucketname/) that will be used "
    echo "  to store cluster data."
    echo "--passwordless_ssh keyname - key name that will be used to configure passwordless ssh across cluster nodes. "
    echo "  Please note that using this option will write information to your local ~/.ssh/config file."
    echo "--user username - username that will be used on cluster nodes, defaults to 'ubuntu'"
    echo "clustername@region - name and region of your cluster"
    if [[ -n "$2" ]]; then
        echo "kissc create: error: $2"
    fi
    exit $1
}

function usage_nodes {
    if [[ -n "$2" ]]; then
        echo "kissc nodes: error: $2"
    fi
    echo "Lists nodes of this cluster."
    echo "Usage:"
    echo "kissc nodes clustername@region"
    echo "Supported parameters:"
    echo "--show_nproc yes - will show the number of workers at each node"
    echo "clustername@region - name and region of your cluster"
    if [[ -n "$2" ]]; then
        echo "kissc nodes: error: $2"
    fi
    exit $1
}

function usage_queues {
    if [[ -n "$2" ]]; then
        echo "kissc queues: error: $2"
    fi
    echo "Lists queues of this cluster."
    echo "Usage:"
    echo "kissc queues clustername@region"
    echo "Supported parameters:"
    echo "clustername@region - name and region of your cluster"
    if [[ -n "$2" ]]; then
        echo "kissc queues: error: $2"
    fi
    exit $1
}


function usage_list {
    if [[ -n "$2" ]]; then
        echo "kissc list: error: $2"
    fi
    echo "Lists clusters in a given region."
    echo "Usage:"
    echo "kissc list region"
    echo "Lists all clusters in the given region."
    if [[ -n "$2" ]]; then
        echo "kissc list: error: $2"
    fi
    exit $1
}

function usage_delete {
    if [[ -n "$2" ]]; then
        echo "kissc delete: error: $2"
    fi
    echo "Deletes information about the cluster from DynamoDB. Nodes and S3 data are not affected."
    echo "Usage:"
    echo "kissc delete clustername@region"
    echo "Deletes the given cluster information."
    echo "This operation does not have additional parameters."
    echo "Note that the function call does try to terminate the nodes in any way!"
    echo "If you run your nodes in AWS you should try to terminate them manually"
    echo "clustername@region - name and region of your cluster"
    if [[ -n "$2" ]]; then
        echo "kissc delete: error: $2"
    fi
    exit $1
}


function usage_submit {
    if [[ -n "$2" ]]; then
        echo "kissc submit: error: $2"
    fi
    echo "Submits a job to cluste's queue."
    echo "Usage:"
    echo "kissc submit --job_command job_command --folder folder [other parameters] clustername@region"
    echo ""
    echo "Supported parameters:"
    echo "--job_command job_command - job command to be executed on each node (commands run on cluster). "
    echo "  Note that an every time  job_command is exected an additional parameter <jobid> "
    echo "   will be added to each command executed on the clustername. "
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
        echo "kissc submit: error: $2"
    fi
    exit $1
}

COMMAND=$1

if [[ -z $COMMAND ]] || ! `contains "create submit delete list nodes queues" $COMMAND`; then
   basic_usage 1 "the following arguments are required: command"
fi

if [[ "$2" == "help" ]]; then
    if [[ $COMMAND = "create" ]]; then
      usage_create 0
    elif [[ $COMMAND = "submit" ]]; then
      usage_submit 0
    elif [[ $COMMAND = "delete" ]]; then
       usage_delete 0
    elif [[ $COMMAND = "list" ]]; then
       usage_list 0
    elif [[ $COMMAND = "nodes" ]]; then
       usage_nodes 0
    elif [[ $COMMAND = "queues" ]]; then
       usage_queues 0
    fi
    basic_usage 1 "Unexpected error"
fi


REGION=""
CLUSTERNAME=""
job_command=""
HOMEDIR=""
S3=""
MINJOBID=1
MAXJOBID=1000000000
QUEUE_NAME=""
KEY_NAME=""
USERNAME=ubuntu
SHOW_NPROC="no"
shift
# shifts skips the <command> parameter
while [[ $# -gt 1 ]]
do
key="$1"
case $key in
    -c|--job_command)
    job_command="$2"
    shift
    ;;
    -f|--folder)
    HOMEDIR="$2"
    shift
    ;;
    -a|--min_jobid)
    MINJOBID="$2"
    shift
    ;;
    -b|--max_jobid)
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
    -v|--show_nproc)
    SHOW_NPROC="$2"
    shift
    ;;
    -u|--user)
    USERNAME="$2"
    shift
    ;;
    *)
    basic_usage 1 "Unknown option $key"
    ;;
esac
shift
done

if [[ $COMMAND = "list" ]]; then
    if [[ -z "$1" ]]; then
       usage_list 1 "Region not given"
    fi
fi
if [[ -n "$1" ]]; then
    vals=(${1//@/ })
    CLUSTERNAME=${vals[0]}
    REGION=${vals[1]}
    if [[ -z ${REGION} ]]; then
        if [[ $COMMAND = "list" ]]; then
            REGION=${CLUSTERNAME}
        else
            basic_usage 1 "The last parameter does not contain region name. Should be clustername@regionname"
        fi
    fi
    if [[ -z ${QUEUE_NAME} ]]; then
       QUEUE_NAME=${CLUSTERNAME}
    fi
    S3=${S3%/}
else
    basic_usage 1 "The last parameter (clustername@region) not given"
fi

checkinstall jq
checkinstall awscli

JOBSTABLE="kissc_jobs_${CLUSTERNAME}"
QUEUESTABLE="kissc_queues_${CLUSTERNAME}"
NODESTABLE="kissc_nodes_${CLUSTERNAME}"


if [[ $COMMAND = "create" ]]; then
    if [[ -z "$S3" ]]; then
        usage_create 1 "missing --s3_bucket parameter"
    fi
    S3_LOCATION=${S3}/${CLUSTERNAME}


    res=`aws dynamodb --region us-east-2 describe-table --table-name ${NODESTABLE} 2>/dev/null  | jq -r ".Table.TableArn"` &&
    if [[ ! -z "$res" ]]; then
       basic_usage 1 "The cluster ${CLUSTERNAME} already exist. Please use a different cluster name or delete the cluster first"
    fi

    PUBLIC_KEY_DATA="-"
    PRIVATE_KEY_DATA="-"
    if [[ -n $KEY_NAME ]];then
        KEY_FILE=~/.ssh/$KEY_NAME
        echo "Creating a key $KEY_NAME for passwordless SSH in file $KEY_FILE"
        ssh-keygen -P "" -t rsa -f $KEY_FILE
        printf "\nUser $USERNAME\nPubKeyAuthentication yes\nStrictHostKeyChecking no\nIdentityFile $KEY_FILE\n" >> ~/.ssh/config		
        PUBLIC_KEY_DATA=$(<${KEY_FILE}.pub)
        PUBLIC_KEY_DATA=${PUBLIC_KEY_DATA//$'\n'/\\n}
        PRIVATE_KEY_DATA=$(<${KEY_FILE})
        PRIVATE_KEY_DATA=${PRIVATE_KEY_DATA//$'\n'/\\n}
    fi
    createddate=$(date '+%Y%m%dT%H%M%SZ')

    res=`aws dynamodb --region ${REGION} describe-table --table-name kissc_clusters 2>/dev/null` || echo "DynamoDB table kissc_clusters not found"
    if [[ -z "${res// }" ]]; then
      echo "Creating DynamoDB table kissc_clusters"
      res=`aws dynamodb --region ${REGION} create-table --table-name kissc_clusters \
        --attribute-definitions AttributeName=clustername,AttributeType=S \
        --key-schema AttributeName=clustername,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=${CLUSTERS_TABLE_ReadCapacityUnits},WriteCapacityUnits=${CLUSTERS_TABLE_WriteCapacityUnits}`
       dynamoDBwait4table kissc_clusters
    fi

    echo "Setting the counters and configuration for ${CLUSTERNAME}"

    

    dynamoDBdroptable "${NODESTABLE} ${QUEUESTABLE} ${JOBSTABLE}"

    echo "Creating DynamoDB table ${NODESTABLE}"
    res=`aws dynamodb --region ${REGION}  create-table --table-name ${NODESTABLE} \
        --attribute-definitions AttributeName=nodeid,AttributeType=N \
        --key-schema AttributeName=nodeid,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=${NODES_TABLE_ReadCapacityUnits},WriteCapacityUnits=${NODES_TABLE_WriteCapacityUnits}`
    echo "Creating DynamoDB table ${QUEUESTABLE}"
    res=`aws dynamodb --region ${REGION}  create-table --table-name ${QUEUESTABLE} \
        --attribute-definitions AttributeName=queueid,AttributeType=N \
        --key-schema AttributeName=queueid,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=${QUEUES_TABLE_ReadCapacityUnits},WriteCapacityUnits=${QUEUES_TABLE_WriteCapacityUnits}`
    echo "Creating DynamoDB table ${JOBSTABLE}"
    res=`aws dynamodb --region ${REGION}  create-table --table-name ${JOBSTABLE} \
        --attribute-definitions AttributeName=queueid,AttributeType=N AttributeName=jobid,AttributeType=N  \
        --key-schema AttributeName=queueid,KeyType=HASH AttributeName=jobid,KeyType=RANGE \
        --provisioned-throughput ReadCapacityUnits=${JOBS_TABLE_ReadCapacityUnits},WriteCapacityUnits=${JOBS_TABLE_WriteCapacityUnits}`

    dynamoDBwait4table ${NODESTABLE}
    dynamoDBwait4table ${QUEUESTABLE}
    dynamoDBwait4table ${JOBSTABLE}
    
    CLOUD_INIT_FILE_NAME=cloud_init_node_${CLUSTERNAME}.sh
    CLOUD_INIT_FILE=./${CLOUD_INIT_FILE_NAME}
    S3_CLOUD_INIT_SCRIPT=${S3_LOCATION}/${CLOUD_INIT_FILE_NAME}
    S3_RUN_NODE_SCRIPT=${S3_LOCATION}/cluster/run_node_${CLUSTERNAME}.sh
    S3_JOB_ENVELOPE_SCRIPT=${S3_LOCATION}/cluster/job_envelope.sh
    S3_QUEUE_UPDATE_SCRIPT=${S3_LOCATION}/cluster/queue_update.sh
    
    printf "#!/bin/bash\n\n" > ${CLOUD_INIT_FILE}
    printf "CLUSTERNAME=${CLUSTERNAME}\n" >> ${CLOUD_INIT_FILE}
    printf "REGION=${REGION}\n" >> ${CLOUD_INIT_FILE}
    printf "S3_RUN_NODE_SCRIPT=${S3_RUN_NODE_SCRIPT}\n" >> ${CLOUD_INIT_FILE}
    printf "USERNAME=${USERNAME}\n" >> ${CLOUD_INIT_FILE}
    
    cat ${BASH_FILE_DIR}/src/cloud_init_template.sh >> ${CLOUD_INIT_FILE}
    chmod +x ${CLOUD_INIT_FILE}
    aws s3 --region ${REGION} cp ${CLOUD_INIT_FILE} ${S3_CLOUD_INIT_SCRIPT}
    aws s3 --region ${REGION} cp ${BASH_FILE_DIR}/src/run_node.sh ${S3_RUN_NODE_SCRIPT}
    aws s3 --region ${REGION} cp ${BASH_FILE_DIR}/src/job_envelope.sh ${S3_JOB_ENVELOPE_SCRIPT}
    aws s3 --region ${REGION} cp ${BASH_FILE_DIR}/src/queue_update.sh ${S3_QUEUE_UPDATE_SCRIPT}
    
    
    json='{"clustername":{"S":"'"${CLUSTERNAME}"'"},"nodeid":{"N":"0"}, 
               "queueid":{"N":"0"}, 
               "date":{"S":"'${createddate}'"},
               "S3_location":{"S":"'${S3_LOCATION}'"},
               "S3_node_init_script":{"S":"'${S3_CLOUD_INIT_SCRIPT}'"},
               "S3_run_node_script":{"S":"'${S3_RUN_NODE_SCRIPT}'"},
               "S3_job_envelope_script":{"S":"'${S3_JOB_ENVELOPE_SCRIPT}'"},
               "S3_queue_update_script":{"S":"'${S3_QUEUE_UPDATE_SCRIPT}'"},
               "workers_in_a_node":{"S":"'"${WORKERS_IN_A_NODE}"'"},
               "username":{"S":"'${USERNAME}'"},
               "creator":{"S":"'${USER}'@'${HOSTNAME}'"},
               "publickey":{"S":"'"${PUBLIC_KEY_DATA}"'"}, 
               "privatekey":{"S":"'"${PRIVATE_KEY_DATA}"'"} }'
    
    res=`aws dynamodb --region ${REGION} put-item --table-name kissc_clusters \
      --item "$json"`
    
    printf "\nSUCCESS!\n"
    printf "The Servless master of cluster ${CLUSTERNAME} has been successfully build!  \n"
    printf "Now you can simply run ${CLOUD_INIT_FILE} on any Linux machine having AWS CLI configured to start processing on your cluster. \n"
    printf "${CLOUD_INIT_FILE} can also be used as a cloud-init configuration for AWS EC2 instances. \n"

elif [[ $COMMAND = "submit" ]]; then
    if [[ -z "$S3" ]]; then
        S3=`aws dynamodb --region ${REGION} get-item --table-name kissc_clusters --key '{"clustername":{"S":"'"${CLUSTERNAME}"'"}}' | jq -r ".Item.S3_location.S"`
        if [[ -z "$S3" ]]; then
            usage_submit 1 "missing --s3_bucket parameter and no information found in kissc_clusters table"
        fi
    fi
    if [[ -z "$job_command" ]]; then
        usage_submit 1 "missing --job_command parameter"
    fi
    if [[ -z "$HOMEDIR" ]]; then
        usage_submit 1 "missing --folder parameter"
    fi

    QUEUE_ID=`aws dynamodb --region ${REGION} update-item \
    --table-name kissc_clusters \
    --key '{"clustername":{"S":"'"${CLUSTERNAME}"'"}}' \
    --update-expression "SET queueid = queueid + :incr" \
    --expression-attribute-values '{":incr":{"N":"1"}}' \
    --return-values UPDATED_NEW | jq -r ".Attributes.queueid.N"`

    if [[ -z ${QUEUE_ID} ]];then
        usage_submit 1  "The cluster ${CLUSTERNAME} does not exist in the region ${REGION}. Use kissc create to create the cluster first."
    fi

    QUEUE_ID_F="Q$(printf "%06d" $QUEUE_ID)_${QUEUE_NAME}"

    S3_LOCATION=${S3}/${CLUSTERNAME}/${QUEUE_ID_F}

    echo "Creating a queue ${QUEUE_ID_F} at ${S3_LOCATION}"

    echo Deleting S3 folder ${S3_LOCATION}/app
    res=`aws s3 --region ${REGION} rm --recursive ${S3_LOCATION}/app`
    tmpname=`tempfile`
    printf "#!/bin/bash\n\n${job_command} \$1" > ${tmpname}
    echo "copying application data to S3" 
    aws s3 --region ${REGION} cp --recursive ${HOMEDIR} ${S3_LOCATION}/app
    aws s3 --region ${REGION} mv ${tmpname} ${S3_LOCATION}/app/job.sh

    jobid=$((${MINJOBID}-1))
    createddate=$(date '+%Y%m%dT%H%M%SZ')
    creator="${USER}@${HOSTNAME}"

    res=`aws dynamodb --region ${REGION} put-item --table-name ${QUEUESTABLE} \
        --item '{"queueid":{"N":"'"${QUEUE_ID}"'"}, \
                "qstatus":{"S":"created"},\
                "queue_name":{"S":"'"${QUEUE_NAME}"'"},\
                "command":{"S":"'"${job_command}"'"},\
                "jobid":{"N":"'"${jobid}"'"},\
                "minjobid":{"N":"'"${MINJOBID}"'"},\
                "maxjobid":{"N":"'"${MAXJOBID}"'"},\
                "date":{"S":"'"${createddate}"'"},\
                "creator":{"S":"'"${creator}"'"},\
                "S3_location":{"S":"'"${S3_LOCATION}"'"}}'\
                `

    echo "The queue ${QUEUE_ID_F} has been successfully created"

elif [[ $COMMAND = "delete" ]]; then
   echo "Deleting the counters and configuration for ${CLUSTERNAME}"
   res=`aws dynamodb --region ${REGION} delete-item --table-name kissc_clusters \
          --key '{"clustername":{"S":"'"${CLUSTERNAME}"'"}}'`
   dynamoDBdroptable "${NODESTABLE} ${QUEUESTABLE} ${JOBSTABLE}"
   echo "Configuration for ${CLUSTERNAME} successfully deleted."
elif [[ $COMMAND = "list" ]]; then
    printf "cluster\tnodes\tqueues\tcreated date        \tS3\n"
    aws dynamodb --region ${REGION} scan --table-name kissc_clusters | jq -r '.Items[] | "\(.clustername.S)\t\(.nodeid.N)\t\(.queueid.N)\t\(.date.S)\t\(.S3_location.S)"'
elif [[ $COMMAND = "nodes" ]]; then
    cluster_data=`aws dynamodb --region ${REGION} get-item --table-name kissc_clusters --key '{"clustername":{"S":"'"${CLUSTERNAME}"'"}}'`
    username=`echo ${cluster_data} | jq -r ".Item.username.S"`
    if [[ "$SHOW_NPROC" = "yes" ]];then
        aws dynamodb --region ${REGION} scan --table-name ${NODESTABLE} | jq -r '.Items[] | "\(.nproc.S)*'"${username}"'@\(.privateip.S)"'
    else
        aws dynamodb --region ${REGION} scan --table-name ${NODESTABLE} | jq -r '.Items[] | "'"${username}"'@\(.privateip.S)"'
    fi
elif [[ $COMMAND = "queues" ]]; then
    printf "q_id\tstatus\tjobid\tminjob\tmaxjob        \tS3 result location            \tcommand\n"
    aws dynamodb --region ${REGION} scan --table-name ${QUEUESTABLE} | jq -r '.Items[] | "\(.queueid.N)\t\(.qstatus.S)\t\(.jobid.N)\t\(.minjobid.N)\t\(.maxjobid.N)\t\(.S3_location.S)\t\(.command.S)"'
fi








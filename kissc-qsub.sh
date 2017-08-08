#!/bin/bash

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

set -e

HELP=0
ERROR=0
REGION=us-east-1

CLUSTERNAME=""
COMMAND=""
HOME_DIR=""
S3=""
MINJOBID=1
MAXJOBID=1000000000

QUEUE_NAME=""

while [[ $# -gt 1 ]]
do
key="$1"
case $key in
    -r|--region)
    REGION="$2"
	shift
    ;;
    -c|--command)
    COMMAND="$2"
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
	-n|--queue_name)
    QUEUE_NAME="$2"
	shift
    ;;
    -h|--help)    
    HELP=1    
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
    CLUSTERNAME=$1
else
	ERROR=1
	echo "Error: The last parameter (clustername) not given"
fi

if [[ $CLUSTERNAME = "-h" ]] || [[ $CLUSTERNAME = "--help" ]]; then
    HELP=1
fi

if [[ $HELP = "0" ]] && [[ $ERROR = "0" ]]; then

    if [[ -z ${QUEUE_NAME} ]]; then
	    QUEUE_NAME=${CLUSTERNAME}
	fi
    if [[ -z $S3 ]]; then
        echo "Error: missing --s3_bucket parameter"
        ERROR=1    
    fi
    if [[ -z $COMMAND ]]; then
        echo "Error: No command to be executed"
        ERROR=1    
    fi
    if [[ -z $HOME_DIR ]]; then
        echo "Error: No application folder"
        ERROR=1    
    fi
    echo ERROR $ERROR
    echo HELP $HELP
    echo REGION $REGION
    echo CLUSTERNAME $CLUSTERNAME
    echo COMMAND $COMMAND
    echo HOME_DIR $HOME_DIR
    echo S3 $S3
	echo MAXJOBID ${MAXJOBID}
	echo MINJOBID ${MINJOBID}
	echo QUEUE_NAME ${QUEUE_NAME}
	
	
fi


if [[ $HELP = "1" ]] || [[ $ERROR = "1" ]]; then
    echo "Usage:"
    echo "kissc-qsub.sh --region region --command command --folder folder --s3_bucket s3_bucket clustername"
    echo ""
    
    echo "--region region - AWS region where the computations will be carried out (optional parameter, if not given defaults to us-east-1)"
    echo "--command - command to be executed on each node. \
        Note that an additional parameter jobid will be added \
        to each command executed on the clustername. \
        The command will be executed on nodes within the folder given as the next parameter"
    echo "--folder folder - a local path  that contains all files needed to execute the command. \
        The contents of the folder will be copied to each cluster node"
    echo "--min_jobid minjobid - starting job id - an optional parameter, requires command and folder parameters"
	echo "--max_jobid maxjobid - ending job id - an optional parameter, requires command and folder parameters"
	echo "--s3_bucket s3_bucket - name of an AWS S3 bucket (e.g. s3://mybucketname/) that will be used \
        to store cluster data and will be used for result collection (mandatory parameter)"
	echo "--queue_name queue_name a label that will describe a particular queue (optional)"
    echo "clustername - name of your cluster (mandatory parameter)"
    echo "Note: the parameters command and folder are optional, but if one is present the other also should be given."
    exit $ERROR
fi




JOBSTABLE="kissc_jobs_${CLUSTERNAME}"
QUEUESTABLE="kissc_queues_${CLUSTERNAME}"
NODESTABLE="kissc_nodes_${CLUSTERNAME}"


QUEUE_ID=`aws dynamodb --region ${REGION} update-item \
    --table-name kissc_clusters \
    --key '{"clustername":{"S":"'"${CLUSTERNAME}"'"}}' \
    --update-expression "SET queueid = queueid + :incr" \
    --expression-attribute-values '{":incr":{"N":"1"}}' \
    --return-values UPDATED_NEW | jq -r ".Attributes.queueid.N"`

if [[ -z ${QUEUE_ID} ]];then 
	echo "Error: the cluster ${CLUSTERNAME} does not exist in the region ${REGION}"
	exit 1
fi
	
QUEUE_ID_F="Q$(printf "%06d" $QUEUE_ID)_${QUEUE_NAME}"

S3_LOCATION=${S3}/${CLUSTERNAME}/${QUEUE_ID_F}

echo "Creating a queue ${QUEUE_ID_F} at ${S3_LOCATION}"

echo Deleting S3 folder ${S3_LOCATION}/app
res=`aws s3 --region ${REGION} rm --recursive ${S3_LOCATION}/app`
tmpname=`tempfile`
printf "#!/bin/bash\n\n${COMMAND} \$1" > ${tmpname}
echo "copying application data to S3" 
aws s3 --region ${REGION} cp --recursive ${HOME_DIR} ${S3_LOCATION}/app
aws s3 --region ${REGION} mv ${tmpname} ${S3_LOCATION}/app/job.sh

jobid=$((${MINJOBID}-1))
createddate=$(date '+%Y%m%dT%H%M%SZ')
creator="${USER}@${HOSTNAME}"

res=`aws dynamodb --region ${REGION} put-item --table-name ${QUEUESTABLE} \
    --item '{"queueid":{"N":"'"${QUEUE_ID}"'"}, \
			"qstatus":{"S":"created"},\
            "queue_name":{"S":"'"${QUEUE_NAME}"'"},\
			"command":{"S":"'"${COMMAND}"'"},\
			"jobid":{"N":"'"${jobid}"'"},\
			"minjobid":{"N":"'"${MINJOBID}"'"},\
			"maxjobid":{"N":"'"${MAXJOBID}"'"},\
			"date":{"S":"'"${createddate}"'"},\
			"creator":{"S":"'"${creator}"'"},\
			"S3_folder":{"S":"'"${S3_LOCATION}"'"}}'\
			`
			
res=`aws dynamodb --region ${REGION} update-item \
    --table-name kissc_clusters \
    --key '{"clustername":{"S":"'"${CLUSTERNAME}"'"}}' \
    --update-expression "SET currentqueueid = :queueid" \
    --condition-expression "currentqueueid = :zero" \
    --expression-attribute-values '{":queueid":{"N":"'"${QUEUE_ID}"'"},":zero":{"N":"0"}}' \
    --return-values UPDATED_NEW  2>/dev/null | jq -r ".Attributes.currentqueueid.N"` 

	


if [[ "${res}" = "${QUEUE_ID}" ]];then
    echo "The queue ${QUEUE_ID} is the running queue on the ${CLUSTERNAME} cluster."
	aws dynamodb --region ${REGION} update-item \
		--table-name ${QUEUESTABLE} \
		--key '{"queueid":{"N":"'"${QUEUE_ID}"'"}}' \
		--update-expression "SET qstatus = :newstatus" \
		--condition-expression "qstatus = :oldstatus" \
		--expression-attribute-values '{":oldstatus":{"S":"created"}, ":newstatus":{"S":"running"}  }' 2>/dev/null
fi

echo "The queue ${QUEUE_ID_F} has been successfully created"


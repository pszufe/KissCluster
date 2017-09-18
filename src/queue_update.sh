#!/bin/bash

REGION=$1
CLUSTERNAME=$2
HOMEDIR=$3
NODEID=$4

NODESTABLE="kissc_nodes_${CLUSTERNAME}"
QUEUESTABLE="kissc_queues_${CLUSTERNAME}"

node_data=`aws dynamodb --region ${REGION} get-item --table-name ${NODESTABLE} --key '{"nodeid":{"N":"'${NODEID}'"}}'`
QUEUE_ID=`echo ${node_data} | jq -r ".Item.currentqueueid.N"`

function allocate_new_queue {
    QUEUE_ID=$1
    nextQUEUE_ID=$(( QUEUE_ID + 1 ))
    queue_data=`aws dynamodb --region ${REGION} get-item --table-name ${QUEUESTABLE} --key '{"queueid":{"N":"'${nextQUEUE_ID}'"}}'`
    if [[ -z ${queue_data} ]]; then
       return $QUEUE_ID
    fi
    QUEUE_ID=${nextQUEUE_ID}
    
    QUEUE_NAME=`echo $queue_data | jq -r ".Item.queue_name.S"`
    S3_LOCATION=`echo $queue_data  | jq -r ".Item.S3_location.S"`
    QUEUE_ID_F="Q$(printf "%06d" $QUEUE_ID)_${QUEUE_NAME}"
    QUEUE_FOLDER=${HOMEDIR}/${QUEUE_ID_F}
    
    echo "Starting working on a new queue ${QUEUE_ID} with data at ${QUEUE_FOLDER}"
    
    
    
    mkdir -p ${QUEUE_FOLDER}/app/
    mkdir -p ${QUEUE_FOLDER}/err/
    mkdir -p ${QUEUE_FOLDER}/log/

    echo "aws s3 --region ${REGION} sync ${S3_LOCATION}/app/ ${QUEUE_FOLDER}/app/ &> /dev/null"
    aws s3 --region ${REGION} sync ${S3_LOCATION}/app/ ${QUEUE_FOLDER}/app/ &> /dev/null
    aws s3 --region ${REGION} cp ${S3_LOCATION}/app/job.sh ${QUEUE_FOLDER}/app/job.sh
    chmod +x ${QUEUE_FOLDER}/app/job.sh
    
    res=`aws dynamodb --region ${REGION} update-item \
    --table-name ${NODESTABLE} \
    --key '{"nodeid":{"N":"'"${NODEID}"'"}}' \
    --update-expression "SET currentqueueid = :currentqueueid" \
    --expression-attribute-values '{":currentqueueid":{"N":"'"${QUEUE_ID}"'"}}' \
    --return-values UPDATED_NEW | jq -r ".Attributes.jobid.N"`
    printf ${QUEUE_ID} > ${HOMEDIR}/queue.id
}

if [[ ${QUEUE_ID} == 0 ]]; then
    QUEUE_ID=`allocate_new_queue ${QUEUE_ID}`
else 
    queue_data=`aws dynamodb --region ${REGION} get-item --table-name ${QUEUESTABLE} --key '{"queueid":{"N":"'${QUEUE_ID}'"}}'`
    maxjobid=`echo $queue_data  | jq -r ".Item.maxjobid.N"`
    jobid=`echo $queue_data  | jq -r ".Item.jobid.N"`
    if [[ ${jobid} -ge ${maxjobid} ]]; then
        QUEUE_ID=`allocate_new_queue ${QUEUE_ID}`
    fi
fi

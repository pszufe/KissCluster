#!/bin/bash

REGION=$1
CLUSTERNAME=$2
HOMEDIR=$3
NODEID=$4
S3_LOCATION_master=$5
CLUSTERDATE=$6
RUN_ID=$7

set -e

JOBSTABLE="kissc_jobs_${CLUSTERNAME}"
NODESTABLE="kissc_nodes_${CLUSTERNAME}"
QUEUESTABLE="kissc_queues_${CLUSTERNAME}"



node_data=`aws --region ${REGION} dynamodb get-item --table-name ${NODESTABLE} --key '{"nodeid":{"N":"'${NODEID}'"}}'`
QUEUE_ID=`echo ${node_data} | jq -r ".Item.currentqueueid.N"`
if [[ ${QUEUE_ID} == 0 ]];then
   echo "No job queue submitted yet"
   flock -n /var/lock/kissc${CLUSTERNAME}.lock ${HOMEDIR}/queue_update.sh ${REGION} ${CLUSTERNAME} ${HOMEDIR} ${NODEID}
   sleep 30 
   exit 0
fi

queue_data=`aws dynamodb --region ${REGION} get-item --table-name ${QUEUESTABLE} --key '{"queueid":{"N":"'${QUEUE_ID}'"}}'`
maxjobid=`echo $queue_data  | jq -r ".Item.maxjobid.N"`
jobid=`echo $queue_data  | jq -r ".Item.jobid.N"`
if [[ ${jobid} -gt ${maxjobid} ]]; then
    echo "The queue ${QUEUE_ID} is exhausted. Looking for a new one..."
    flock -n /var/lock/kissc${CLUSTERNAME}.lock ${HOMEDIR}/queue_update.sh ${REGION} ${CLUSTERNAME} ${HOMEDIR} ${NODEID}
    sleep 10
    exit 0
fi
QUEUE_NAME=`echo $queue_data  | jq -r ".Item.queue_name.S"`

JOB_ID=`aws dynamodb --region ${REGION} update-item \
    --table-name ${QUEUESTABLE} \
    --key '{"queueid":{"N":"'"${QUEUE_ID}"'"}}' \
    --update-expression "SET jobid = jobid + :incr" \
    --expression-attribute-values '{":incr":{"N":"1"}}' \
    --return-values UPDATED_NEW | jq -r ".Attributes.jobid.N"`

QUEUE_ID_F="Q$(printf "%06d" $QUEUE_ID)_${QUEUE_NAME}"
RUN_ID_F="$(printf "%09d" $RUN_ID)"
JOB_ID_F="$(printf "%09d" $JOB_ID)"
NODEID_F="$(printf "%05d" $NODEID)"

QUEUE_FOLDER=${HOMEDIR}/${QUEUE_ID_F}
S3_LOCATION=${S3_LOCATION_master}/${QUEUE_ID_F}

echo "Running: N${NODEID_F} ${QUEUE_ID_F} R${RUN_ID_F} J${JOB_ID_F}"

filename_log="N${NODEID_F}_${QUEUE_ID_F}_R${RUN_ID_F}_J${JOB_ID_F}.log.txt"
filepath_log=${QUEUE_FOLDER}/log/${filename_log}

filename_error="N${NODEID_F}_R${RUN_ID_F}_J${JOB_ID_F}.error.txt"
filepath_error=${QUEUE_FOLDER}/err/${filename_error}

jobstartdate=$(date '+%Y%m%dT%H%M%SZ')
start_time=$(date +%s)


res=`aws dynamodb --region ${REGION} put-item --table-name ${JOBSTABLE} \
    --item '{"queueid":{"N":"'${QUEUE_ID}'"},"jobid":{"N":"'${JOB_ID}'"},\
            "nodeid":{"N":"'${NODEID}'"}, "jstatus":{"S":"running"},\
            "jobstartdate":{"S":"'${jobstartdate}'"},\
            "S3_log":{"S":"'"${filepath_log}"'"},\
            "S3_error":{"S":"'"${filepath_error}"'"}}'\
            `


cd ${QUEUE_FOLDER}/app
./job.sh $JOB_ID > ${filepath_log} 2> ${filepath_error}
exit_status=$?
jobenddate=$(date '+%Y%m%dT%H%M%SZ')
end_time=$(date +%s)
job_duration_s=$(( end_time - start_time ))

if [[ $job_duration_s -lt 2 ]]; then
    sleep 1
fi

out_txt_size=`stat --printf="%s" ${filepath_log}`
log_error_size=`stat --printf="%s" ${filepath_error}`

#if [[ $out_txt_size -gt 256 ]]; then
#    log_txt=${log_txt}"(...)"
#fi

#if [[ $log_error_size -gt 256 ]]; then
#    log_error=${log_error}"(...)"
#fi


gzip $filepath_log
gzip $filepath_error

S3_log=${S3_LOCATION}/std_out_${CLUSTERDATE}
S3_error=${S3_LOCATION}/std_error_${CLUSTERDATE}

aws s3 --region ${REGION} cp ${filepath_log}.gz ${S3_log}/
aws s3 --region ${REGION} cp ${filepath_error}.gz ${S3_error}/
echo "Completed: N${NODEID_F} ${QUEUE_ID_F} R${RUN_ID_F} J${JOB_ID_F}"
res=`aws dynamodb --region ${REGION} put-item --table-name ${JOBSTABLE} \
    --item '{"queueid":{"N":"'${QUEUE_ID}'"},"jobid":{"N":"'${JOB_ID}'"},\
            "nodeid":{"N":"'${NODEID}'"}, \
            "jstatus":{"S":"completed"},\
            "jobstartdate":{"S":"'${jobstartdate}'"},\
            "jobenddate":{"S":"'${jobenddate}'"},\
            "job_duration_s":{"N":"'${job_duration_s}'"},\
            "exit_status":{"N":"'${exit_status}'"},\
            "out_txt_size":{"N":"'${out_txt_size}'"},\
            "log_error_size":{"N":"'${log_error_size}'"},\
            "S3_log":{"S":"'"${S3_log}/${filename_log}.gz"'"},\
            "S3_error":{"S":"'"${S3_error}/${filename_error}.gz"'"}}'\
            `
echo "Written: N${NODEID_F} ${QUEUE_ID_F} R${RUN_ID_F} J${JOB_ID_F}"

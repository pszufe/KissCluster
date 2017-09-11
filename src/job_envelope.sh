#!/bin/bash

CLUSTERNAME=$1
REGION=$2
NODEID=$3
S3_LOCATION_master=$4
HOME_DIR=$5
CLUSTERDATE=$6
RUN_ID=$7


JOBSTABLE="kissc_jobs_${CLUSTERNAME}"
CLUSTERTABLE="kissc_cluster_${CLUSTERNAME}"
QUEUESTABLE="kissc_queues_${CLUSTERNAME}"


mkdir -p ${HOME_DIR}/app/
mkdir -p ${HOME_DIR}/res/
mkdir -p ${HOME_DIR}/log/

QUEUE_ID=`aws dynamodb --region ${REGION} get-item --table-name kissc_clusters --key '{"clustername":{"S":"'"${CLUSTERNAME}"'"}}' | jq -r ".Item.currentqueueid.N"`

echo Synchronizing files...
QUEUE_NAME=`aws dynamodb --region ${REGION} get-item --table-name ${QUEUESTABLE} --key '{"queueid":{"N":"'"${QUEUE_ID}"'"}}' | jq -r ".Item.queue_name.S"`
S3_LOCATION=`aws dynamodb --region ${REGION} get-item --table-name ${QUEUESTABLE} --key '{"queueid":{"N":"'"${QUEUE_ID}"'"}}' | jq -r ".Item.S3_folder.S"`
QUEUE_ID_F="Q$(printf "%06d" $QUEUE_ID)_${QUEUE_NAME}"

echo "aws s3 --region ${REGION} sync ${S3_LOCATION}/app/ ${HOME_DIR}/app/ &> /dev/null"
aws s3 --region ${REGION} sync ${S3_LOCATION}/app/ ${HOME_DIR}/app/ &> /dev/null

aws s3 --region ${REGION} cp ${S3_LOCATION}/app/job.sh ${HOME_DIR}/app/job.sh
chmod +x ${HOME_DIR}/app/job.sh



QUEUE_ID=`aws dynamodb --region ${REGION} get-item --table-name kissc_clusters --key '{"clustername":{"S":"'"${CLUSTERNAME}"'"}}' | jq -r ".Item.currentqueueid.N"`
QUEUE_NAME=`aws dynamodb --region ${REGION} get-item --table-name ${QUEUESTABLE} --key '{"queueid":{"N":"'"${QUEUE_ID}"'"}}' | jq -r ".Item.queue_name.S"`


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


echo "Running: N${NODEID_F} ${QUEUE_ID_F} R${RUN_ID_F} J${JOB_ID_F}"

filename_log="N${NODEID_F}_${QUEUE_ID_F}_R${RUN_ID_F}_J${JOB_ID_F}.log.txt"
filepath_log=${HOME_DIR}/res/${filename_log}

filename_error="N${NODEID_F}_R${RUN_ID_F}_J${JOB_ID_F}.error.txt"
filepath_error=${HOME_DIR}/log/${filename_error}

jobstartdate=$(date '+%Y%m%dT%H%M%SZ')
start_time=$(date +%s)


res=`aws dynamodb --region ${REGION} put-item --table-name ${JOBSTABLE} \
    --item '{"queueid":{"N":"'${QUEUE_ID}'"},"jobid":{"N":"'${JOB_ID}'"},\
            "nodeid":{"N":"'${NODEID}'"}, "jstatus":{"S":"running"},\
            "jobstartdate":{"S":"'${jobstartdate}'"},\
            "S3_log":{"S":"'"${filepath_log}"'"},\
            "S3_error":{"S":"'"${filepath_error}"'"}}'\
            `


cd ${HOME_DIR}/app
./job.sh $JOB_ID > ${filepath_log} 2> ${filepath_error}
exit_status=$?
jobenddate=$(date '+%Y%m%dT%H%M%SZ')
end_time=$(date +%s)
job_duration_s=$(( end_time - start_time ))

out_txt_size=`stat --printf="%s" ${filepath_log}`
log_error_size=`stat --printf="%s" ${filepath_error}`

#if [[ $out_txt_size -gt 256 ]]; then
#	log_txt=${log_txt}"(...)"
#fi

#if [[ $log_error_size -gt 256 ]]; then
#	log_error=${log_error}"(...)"
#fi


gzip $filepath_log
gzip $filepath_error

S3_log=${S3_LOCATION}/res/${CLUSTERDATE}
S3_error=${S3_LOCATION}/log/std_error_${CLUSTERDATE}

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

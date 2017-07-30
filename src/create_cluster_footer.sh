tmpname=`tempfile`
printf "${job_envelope_base64}" | base64 -d > ${tmpname}
aws s3 --region ${REGION} mv ${tmpname} ${S3_LOCATION}/app/job_envelope.sh

S3_RUN_NODE_SCRIPT=${S3_LOCATION}/app/run_node_${CLUSTERNAME}.sh

printf "#!/bin/bash\n\n" > ${tmpname}
printf "CLUSTERNAME=${CLUSTERNAME}\n" >> ${tmpname}
printf "REGION=${REGION}\n" >> ${tmpname}
printf "${run_node_template_base64}" | base64 -d >> ${tmpname}
aws s3 --region ${REGION} mv ${tmpname} ${S3_RUN_NODE_SCRIPT}

printf "#!/bin/bash\n\n" > ${CLOUD_INIT_FILE}
printf "CLUSTERNAME=${CLUSTERNAME}\n" >> ${CLOUD_INIT_FILE}
printf "REGION=${REGION}\n" >> ${CLOUD_INIT_FILE}
printf "S3_RUN_NODE_SCRIPT=${S3_RUN_NODE_SCRIPT}\n\n" >> ${CLOUD_INIT_FILE}

printf  "${cloud_init_base64}" | base64 -d >> ${CLOUD_INIT_FILE}
chmod +x ${CLOUD_INIT_FILE}

printf "\nSUCCESS!\n"
printf "The cluster ${CLUSTERNAME} has been successfully build!  \n"
printf "Now you can simply run ${CLOUD_INIT_FILE} on any AWS EC2 machine to start processing on your cluster. \n"
printf "${CLOUD_INIT_FILE} can also be used as a cloud-init configuration for EC2 instances. \n"

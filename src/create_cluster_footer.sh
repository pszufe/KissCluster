tmpname=`tempfile`
printf ${job_envelope_base64} | base64 -d > ${tmpname}
aws s3 --region ${REGION} mv ${tmpname} ${S3_LOCATION}/app/job_envelope.sh

printf "#!/bin/bash\n\n" > ${RUN_NODE_FILE}
printf "CLUSTERNAME=${CLUSTERNAME}\n" >> ${RUN_NODE_FILE}
printf "REGION=${REGION}\n" >> ${RUN_NODE_FILE}
printf "\n" >> ${RUN_NODE_FILE}
printf ${run_node_template_base64} | base64 -d >> ${RUN_NODE_FILE}
chmod +x ${RUN_NODE_FILE}

printf "\nSUCCESS!\n"
printf "The cluster ${CLUSTERNAME} has been successfully build!  \n"
printf "Now you can simply run ${RUN_NODE_FILE} on any AWS EC2 machine to start processing on your cluster. \n"
printf "${RUN_NODE_FILE} can also be used as a cloud-init configuration for EC2 instances. \n"

#!/bin/bash

set -e
cp create_cluster_base.sh ../create_cluster.sh
printf "" >> ../create_cluster.sh

base64jobEnv=`cat job_envelope.sh | base64`
printf "tmpname=\`tempfile\`\n" >> ../create_cluster.sh
printf "printf \"${base64jobEnv}\" | base64 -d > \${tmpname}\n"  >> ../create_cluster.sh
printf "aws s3 --region \${REGION} mv \${tmpname} \${S3_LOCATION}/app/job_envelope.sh\n\n" >> ../create_cluster.sh

base64RunNode=`cat run_node_template.sh | base64`

printf "printf \"#!/bin/bash\\\\n\\\\n\" > \${RUN_NODE_FILE}\n"  >> ../create_cluster.sh
printf "printf \"CLUSTERNAME=\${CLUSTERNAME}\\\\n\" >> \${RUN_NODE_FILE}\n"  >> ../create_cluster.sh
printf "printf \"REGION=\${REGION}\\\\n\" >> \${RUN_NODE_FILE}\n"  >> ../create_cluster.sh
printf "printf \"\\\\n\" >> \${RUN_NODE_FILE}\n"  >> ../create_cluster.sh
printf "printf \"${base64RunNode}\" | base64 -d >> \${RUN_NODE_FILE}\n"  >> ../create_cluster.sh
printf "\n\n"  >> ../create_cluster.sh
printf "printf \"\\\\nSUCCESS!\\\\n\"\n"  >> ../create_cluster.sh
printf "printf \"The cluster \${CLUSTERNAME} has been successfully build!  \\\\n\"\n"  >> ../create_cluster.sh
printf "printf \"Now you can simply run \${RUN_NODE_FILE} on any AWS EC2 machine to start processing on your cluster. \\\\n\"\n"  >> ../create_cluster.sh
printf "printf \"\${RUN_NODE_FILE} can also be used as a cloud-init configuration for EC2 instances. \\\\n\"\n"  >> ../create_cluster.sh

chmod +x ../create_cluster.sh
echo The build process has been successfully completed!
echo The ../create_cluster.sh is ready.


sudo apt update --yes
sudo apt install awscli jq --yes
sudo su ubuntu

aws  --region ${REGION} s3 cp ${S3_RUN_NODE_SCRIPT} /home/ubuntu/run_node_${CLUSTERNAME}.sh
cd /home/ubuntu
bash run_node_${CLUSTERNAME}.sh
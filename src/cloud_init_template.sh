

sudo apt update --yes
sudo apt install awscli jq --yes

#uncomment this line when using as cloud init and do not want to run as root
#sudo su - ${USERNAME}

aws  --region ${REGION} s3 cp ${S3_RUN_NODE_SCRIPT} /home/${USERNAME}/run_node_${CLUSTERNAME}.sh 
cd /home/${USERNAME}

echo "Now running the command"
echo "bash run_node_${CLUSTERNAME}.sh ${REGION} ${CLUSTERNAME}"
bash run_node_${CLUSTERNAME}.sh ${REGION} ${CLUSTERNAME}

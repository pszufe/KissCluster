

sudo apt update --yes
sudo apt install awscli jq --yes

#uncomment this line when using as cloud init and do not want to run as root
#sudo su - ${USERNAME}

HOME_DIR=/home/${USERNAME}/kissc-${CLUSTERNAME}
aws  --region ${REGION} s3 cp ${S3_RUN_NODE_SCRIPT} ${HOMEDIR}/run_node_${CLUSTERNAME}.sh 
cd ${HOME_DIR}

echo "Now running the command"
echo "bash run_node_${CLUSTERNAME}.sh ${REGION} ${CLUSTERNAME}"
bash run_node_${CLUSTERNAME}.sh ${REGION} ${CLUSTERNAME} ${HOME_DIR}

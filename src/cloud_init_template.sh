sudo apt update --yes
sudo apt install awscli jq --yes
sudo su - ${USERNAME}
[[ "${USERNAME}" = "root" ]] && USER_HOME=/root || \
    USER_HOME=/home/${USERNAME}
HOMEDIR=${USER_HOME}/kissc-${CLUSTERNAME}
mkdir -p ${HOMEDIR} 
aws  --region ${REGION} s3 cp ${S3_RUN_NODE_SCRIPT} \
    ${HOMEDIR}/run_node_${CLUSTERNAME}.sh 
cd ${HOME_DIR}
echo "Now running the command:"
echo "run_node_${CLUSTERNAME}.sh ${REGION} ${CLUSTERNAME} \
    ${HOME_DIR} ${USERNAME} ${USER_HOME}"
bash run_node_${CLUSTERNAME}.sh ${REGION} ${CLUSTERNAME} \
    ${HOME_DIR} ${USERNAME} ${USER_HOME}

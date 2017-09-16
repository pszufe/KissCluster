sudo apt update --yes
sudo apt install awscli jq --yes
set -e
#sudo su - ${USERNAME}
[[ "${USERNAME}" = "root" ]] && USER_HOME=/root || \
    USER_HOME=/home/${USERNAME}
HOMEDIR=${USER_HOME}/kissc-${CLUSTERNAME}
sudo install -d -o ${USERNAME} -g ${USERNAME} ${HOMEDIR} 

echo "Copying node file to ${HOMEDIR}/run_node_${CLUSTERNAME}.sh"
aws  --region ${REGION} s3 cp ${S3_RUN_NODE_SCRIPT} \
    ${HOMEDIR}/run_node_${CLUSTERNAME}.sh
cd ${HOMEDIR}
echo "Now running the command:"
echo "bash run_node_${CLUSTERNAME}.sh ${REGION} ${CLUSTERNAME} \
    ${HOMEDIR} ${USERNAME} ${USER_HOME}"
sudo bash run_node_${CLUSTERNAME}.sh ${REGION} ${CLUSTERNAME} \
    ${HOMEDIR} ${USERNAME} ${USER_HOME}

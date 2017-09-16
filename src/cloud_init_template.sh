sudo apt update --yes
sudo apt install awscli jq --yes
sudo su - ${USERNAME}
set -e
[[ "${USERNAME}" = "root" ]] && USER_HOME=/root || \
    USER_HOME=/home/${USERNAME}
HOMEDIR=${USER_HOME}/kissc-${CLUSTERNAME}
mkdir -p ${HOMEDIR} 
echo "Copying node file to ${HOMEDIR}/run_node_${CLUSTERNAME}.sh"
aws  --region ${REGION} s3 cp ${S3_RUN_NODE_SCRIPT} \
    ${HOMEDIR}/run_node_${CLUSTERNAME}.sh
cd ${HOMEDIR}
echo "Now running the command:"
echo "bash run_node_${CLUSTERNAME}.sh ${REGION} ${CLUSTERNAME} \
    ${HOMEDIR} ${USERNAME} ${USER_HOME}"
bash run_node_${CLUSTERNAME}.sh ${REGION} ${CLUSTERNAME} \
    ${HOMEDIR} ${USERNAME} ${USER_HOME}

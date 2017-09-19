#!/bin/bash

REGION=$1
CLUSTERNAME=$2
HOMEDIR=$3
USERNAME=$4
USERHOME=$5

set -e

NODESTABLE="kissc_nodes_${CLUSTERNAME}"
QUEUESTABLE="kissc_queues_${CLUSTERNAME}"
JOBSTABLE="kissc_jobs_${CLUSTERNAME}"

cluster_data=`aws dynamodb --region ${REGION} get-item --table-name kissc_clusters --key '{"clustername":{"S":"'"${CLUSTERNAME}"'"}}'`
S3_job_envelope_script=`echo ${cluster_data} | jq -r ".Item.S3_job_envelope_script.S"`
S3_queue_update_script=`echo ${cluster_data} | jq -r ".Item.S3_queue_update_script.S"`

S3_LOCATION_master=`echo ${cluster_data} | jq -r ".Item.S3_location.S"`

workers_in_a_node=`echo ${cluster_data} | jq -r ".Item.workers_in_a_node.S"`
nproc=`nproc`
eval max_procs=$workers_in_a_node

if [[ -z "$max_procs" ]];then
    echo "Error: ${workers_in_a_node} evaluated to an empty string - using number of cores instead"
    max_procs=`nproc`
fi


publickey=`echo ${cluster_data} | jq -r ".Item.publickey.S"`

if [[ ! -z "${publickey}" ]];then
    mkdir -p ${USERHOME}/.ssh
    priv_key_file=${USERHOME}/.ssh/${CLUSTERNAME}-private.key
    echo ${cluster_data} | jq -r ".Item.privatekey.S" > ${priv_key_file}
    echo "${publickey}"  >> ${USERHOME}/.ssh/authorized_keys
    printf "User ${USERNAME}\nPubKeyAuthentication yes\nIdentityFile ${priv_key_file}\nStrictHostKeyChecking no" > ${USERHOME}/.ssh/config

fi 

CLUSTERDATE=`echo ${cluster_data} | jq -r ".Item.date.S"`

echo "Date of the cluster ${CLUSTERNAME} creation: ${CLUSTERDATE}"

echo "S3_LOCATION_master ${S3_LOCATION_master}"

NODEID=`aws dynamodb --region ${REGION} update-item \
    --table-name kissc_clusters \
    --key '{"clustername":{"S":"'"${CLUSTERNAME}"'"}}' \
    --update-expression "SET nodeid = nodeid + :incr" \
    --expression-attribute-values '{":incr":{"N":"1"}}' \
    --return-values UPDATED_NEW | jq -r ".Attributes.nodeid.N"`

createddate=$(date '+%Y%m%dT%H%M%SZ')

echo "Starting cluster node with nodeid: ${NODEID} Node creation date: ${createddate}"

NODEID_F=N"$(printf "%05d" $NODEID)"

mkdir -p ${HOMEDIR}
printf ${NODEID} > ${HOMEDIR}/node.id
aws s3 --region ${REGION} cp ${S3_job_envelope_script} ${HOMEDIR}/job_envelope.sh
aws s3 --region ${REGION} cp ${S3_queue_update_script} ${HOMEDIR}/queue_update.sh
chmod +x ${HOMEDIR}/job_envelope.sh
chmod +x ${HOMEDIR}/queue_update.sh


hostname=`curl -s http://169.254.169.254/latest/meta-data/public-hostname`
ip=`curl -s http://169.254.169.254/latest/meta-data/public-ipv4`
ami_id=`curl -s http://169.254.169.254/latest/meta-data/ami-id`
instance_id=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
instance_type=`curl -s http://169.254.169.254/latest/meta-data/instance-type`
iam_profile=`curl -s http://169.254.169.254/latest/meta-data/iam/info | jq -r ".InstanceProfileArn" 2>/dev/null`
privateip=`curl -s http://169.254.169.254/latest/meta-data/local-ipv4`

if [[ -z ${iam_profile} ]]; then
   iam_profile="-"
fi
az=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
security_groups=`curl -s http://169.254.169.254/latest/meta-data/security-groups`
if [[ -z ${security_groups} ]]; then
   security_groups="-"
fi

echo "Node hostname: ${hostname}"
echo "Node ip: ${ip}"
echo "Node ami_id: ${ami_id}"
echo "Node instance_id: ${instance_id}"
echo "Node instance_type: ${instance_type}"
echo "Node iam_profile: ${iam_profile}"
echo "Node availability zone: ${az}"
echo "Configured security groups: ${security_groups}"

sudo install -d -o ${USERNAME} -g ${USERNAME} ${HOMEDIR}/log
logfile="${HOMEDIR}/log/${NODEID_F}_${createddate}.log.txt"

echo "Number of available vCPU cores: `nproc` number of processes: ${max_procs}"

echo "Node information will be written to DynamoFB table: ${NODESTABLE}"
res=`aws dynamodb --region ${REGION} put-item --table-name ${NODESTABLE} \
    --item '{"nodeid":{"N":"'${NODEID}'"},\
            "currentqueueid":{"N":"0"},\
            "nodedate":{"S":"'${createddate}'"},\
            "clusterdate":{"S":"'${CLUSTERDATE}'"},\
            "nproc":{"S":"'${max_procs}'"},"logfile":{"S":"'${logfile}'"},\
            "hostname":{"S":"'${hostname}'"},\
            "privateip":{"S":"'${privateip}'"},\
            "publicip":{"S":"'${ip}'"},"ami_id":{"S":"'${ami_id}'"},\
            "instance_id":{"S":"'${instance_id}'"},\
            "instance_type":{"S":"'${instance_type}'"},\
            "iam_profile":{"S":"'${iam_profile}'"},\
            "az":{"S":"'${az}'"},\
            "security_groups":{"S":"'${security_groups}'"}}'`




echo "Node ${NODEID} has been successfully started."

while true
do
    queueid=`echo ${cluster_data} | jq -r ".Item.queueid.N"`
    if [[ "${queueid}" -gt 0 ]]; then
       break
    fi 
    echo "No queues on the cluster - the main process is sleeping..."
    sleep 15
    cluster_data=`aws dynamodb --region ${REGION} get-item --table-name kissc_clusters --key '{"clustername":{"S":"'"${CLUSTERNAME}"'"}}'`
done

S3_job_envelope_script=`echo ${cluster_data} | jq -r ".Item.S3_job_envelope_script.S"`

flock -n /var/lock/kissc${CLUSTERNAME}.lock ${HOMEDIR}/queue_update.sh ${REGION} ${CLUSTERNAME} ${HOMEDIR} ${NODEID}

nohup seq 1 100000000 | xargs --max-args=1 --max-procs=$max_procs bash ${HOMEDIR}/job_envelope.sh "${REGION}" "${CLUSTERNAME}" "${HOMEDIR}" "${NODEID}" "${S3_LOCATION_master}" "${CLUSTERDATE}" &>> $logfile &

echo "Now monitoring the queues for jobs"
echo "In order to terminate computations on this node look for the xargs process and kill it (pkill -f xargs)"




#!/bin/bash

if [[ $# -ne 5 ]]; then
    echo Usage:
	echo create_cluster.sh clustername region command folder s3_bucket
	echo ""
	echo clustername - name of your computation
	echo region - AWS region where the computations will be carried out
	echo command - command to be executed on each node. \
		An additional parameter jobid will be added \
		to each command executed on the clustername. \
		The command will be executed on nodes within the folder given as the next parameter
	echo folder - folder that contains all files needed to execute the command. \
		The contents of the folder will be copied to each cluster node
	echo s3_bucket - name of an AWS S3 bucket that will be used to store application code \
		and will be used for result collection.
	exit 1
fi


CLUSTERNAME=$1
REGION=$2
COMMAND=$3
HOME_DIR=$4
S3=$5

S3_LOCATION=${S3}/${CLUSTERNAME}

JOBSTABLE="kissc_jobs_${CLUSTERNAME}"
CLUSTERTABLE="kissc_cluster_${CLUSTERNAME}"

RUN_NODE_FILE=./run_node_${CLUSTERNAME}.sh

function wait4table {
    TABLENAME=$1
    while  
		echo "Waiting for DynamoDB table ${TABLENAME} in region ${REGION} to be active"
		sleep 3
		status=`aws dynamodb --region ${REGION} describe-table --table-name ${TABLENAME} 2>/dev/null  | jq -r ".Table.TableStatus"`
		[[ $status != ACTIVE ]]
	do
		:
	done
	echo "DynamoDB table ${TABLENAME} created"
}

set -e

createddate=$(date '+%Y%m%dT%H%M%SZ')

#sudo apt-get update
sudo apt install awscli jq --yes

res=`aws dynamodb --region ${REGION} describe-table --table-name kissc_clusters 2>/dev/null` || echo "DynamoDB table kissc_clusters not found"
if [[ -z "${res// }" ]]; then
  echo "Creating DynamoDB table kissc_clusters"
  res=`aws dynamodb --region ${REGION} create-table --table-name kissc_clusters \
	--attribute-definitions AttributeName=clustername,AttributeType=S \
	--key-schema AttributeName=clustername,KeyType=HASH \
	--provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5`
   wait4table kissc_clusters
fi

echo "Resetting the counters for ${CLUSTERNAME}"

res=`aws dynamodb --region ${REGION} put-item --table-name kissc_clusters \
  --item '{"clustername":{"S":"'"${CLUSTERNAME}"'"},"command":{"S":"'"${COMMAND}"'"} , "jobid":{"N":"0"}, "nodeid":{"N":"0"}, "S3_folder":{"S":"'${S3_LOCATION}'"}, "date":{"S":"'${createddate}'"}, "creator":{"S":"'${USER}'@'${HOSTNAME}'"}}  '`



res=`aws dynamodb --region ${REGION} describe-table --table-name ${JOBSTABLE} 2>/dev/null` || echo "DynamoDB table ${JOBSTABLE} not found"

if [[ ! -z "${res// }" ]]; then
  echo "Dropping DynamoDB table ${JOBSTABLE}"
  res=`aws dynamodb --region ${REGION}  delete-table --table-name ${JOBSTABLE}`
  while  
    echo "Waiting for DynamoDB table ${JOBSTABLE} to be dropped"
    sleep 3
	res=`aws dynamodb --region ${REGION} describe-table --table-name ${JOBSTABLE} 2>/dev/null`
	[[ ! -z "${res// }" ]]
   do
     :
   done
   echo "DynamoDB table ${JOBSTABLE} has been dropped"
fi


res=`aws dynamodb --region ${REGION} describe-table --table-name ${CLUSTERTABLE} 2>/dev/null` || echo "DynamoDB table ${CLUSTERTABLE} not found"

if [[ ! -z "${res// }" ]]; then
  echo "Dropping DynamoDB table ${CLUSTERTABLE}"
  res=`aws dynamodb --region ${REGION}  delete-table --table-name ${CLUSTERTABLE}`
  while  
    echo "Waiting for DynamoDB table ${CLUSTERTABLE} to be dropped"
    sleep 3
	res=`aws dynamodb --region ${REGION} describe-table --table-name ${CLUSTERTABLE} 2>/dev/null`
	[[ ! -z "${res// }" ]]
   do
     :
   done
   echo "DynamoDB table ${CLUSTERTABLE} has been dropped"
fi

echo "Creating DynamoDB table ${JOBSTABLE}"
res=`aws dynamodb --region ${REGION}  create-table --table-name ${JOBSTABLE} \
	--attribute-definitions AttributeName=jobid,AttributeType=N \
	--key-schema AttributeName=jobid,KeyType=HASH \
	--provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5`


echo "Creating DynamoDB table ${CLUSTERTABLE}"
res=`aws dynamodb --region ${REGION}  create-table --table-name ${CLUSTERTABLE} \
	--attribute-definitions AttributeName=nodeid,AttributeType=N \
	--key-schema AttributeName=nodeid,KeyType=HASH \
	--provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1`



wait4table ${JOBSTABLE}
wait4table ${CLUSTERTABLE}
	

echo Deleting S3 folder ${S3_LOCATION}/app
res=`aws s3 --region ${REGION} rm --recursive ${S3_LOCATION}/app`

printf "#!/bin/bash\n\n${COMMAND} \$1" > ${HOME_DIR}/.command.sh
chmod +x ${HOME_DIR}/.command.sh

echo "copying application data to S3" 
aws s3 --region ${REGION} cp --recursive ${HOME_DIR} ${S3_LOCATION}/app


tmpname=`tempfile`
printf "IyEvYmluL2Jhc2gKCkNMVVNURVJOQU1FPSQxClJFR0lPTj0kMgpOT0RFSUQ9JDMKUzNfTE9DQVRJ
T049JDQKSE9NRV9ESVI9JDUKQ0xVU1RFUkRBVEU9JDYKUlVOX0lEPSQ3CgpKT0JTVEFCTEU9Imtp
c3NjX2pvYnNfJHtDTFVTVEVSTkFNRX0iCkNMVVNURVJUQUJMRT0ia2lzc2NfY2x1c3Rlcl8ke0NM
VVNURVJOQU1FfSIKCgoKCkpPQl9JRD1gYXdzIGR5bmFtb2RiIC0tcmVnaW9uICR7UkVHSU9OfSB1
cGRhdGUtaXRlbSBcCiAgICAtLXRhYmxlLW5hbWUga2lzc2NfY2x1c3RlcnMgXAogICAgLS1rZXkg
J3siY2x1c3Rlcm5hbWUiOnsiUyI6IiciJHtDTFVTVEVSTkFNRX0iJyJ9fScgXAogICAgLS11cGRh
dGUtZXhwcmVzc2lvbiAiU0VUIGpvYmlkID0gam9iaWQgKyA6aW5jciIgXAogICAgLS1leHByZXNz
aW9uLWF0dHJpYnV0ZS12YWx1ZXMgJ3siOmluY3IiOnsiTiI6IjEifX0nIFwKICAgIC0tcmV0dXJu
LXZhbHVlcyBVUERBVEVEX05FVyB8IGpxIC1yICIuQXR0cmlidXRlcy5qb2JpZC5OImAKClJVTl9J
RF9GPSIkKHByaW50ZiAiJTA5ZCIgJFJVTl9JRCkiCkpPQl9JRF9GPSIkKHByaW50ZiAiJTA5ZCIg
JEpPQl9JRCkiCk5PREVJRF9GPSIkKHByaW50ZiAiJTA1ZCIgJE5PREVJRCkiCgoKZmlsZW5hbWVf
bG9nPSJOJHtOT0RFSURfRn1fUiR7UlVOX0lEX0Z9X0oke0pPQl9JRF9GfS5sb2cudHh0IgpmaWxl
cGF0aF9sb2c9JHtIT01FX0RJUn0vcmVzLyR7ZmlsZW5hbWVfbG9nfQoKZmlsZW5hbWVfZXJyb3I9
Ik4ke05PREVJRF9GfV9SJHtSVU5fSURfRn1fSiR7Sk9CX0lEX0Z9LmVycm9yLnR4dCIKZmlsZXBh
dGhfZXJyb3I9JHtIT01FX0RJUn0vbG9nLyR7ZmlsZW5hbWVfZXJyb3J9Cgpqb2JzdGFydGRhdGU9
JChkYXRlICcrJVklbSVkVCVIJU0lU1onKQpzdGFydF90aW1lPSQoZGF0ZSArJXMpCgoKcmVzPWBh
d3MgZHluYW1vZGIgLS1yZWdpb24gJHtSRUdJT059IHB1dC1pdGVtIC0tdGFibGUtbmFtZSAke0pP
QlNUQUJMRX0gXAogICAgLS1pdGVtICd7ImpvYmlkIjp7Ik4iOiInJHtKT0JfSUR9JyJ9LCJub2Rl
aWQiOnsiTiI6Iicke05PREVJRH0nIn0sIFwKCQkJInN0YXR1cyI6eyJTIjoicnVubmluZyJ9LFwK
ICAgICAgICAgICAgImpvYnN0YXJ0ZGF0ZSI6eyJTIjoiJyR7am9ic3RhcnRkYXRlfScifSxcCgkJ
CSJTM19sb2ciOnsiUyI6Iicke1MzX2xvZ30vJHtmaWxlbmFtZV9sb2d9Lmd6JyJ9LFwKCQkJIlMz
X2Vycm9yIjp7IlMiOiInJHtTM19lcnJvcn0vJHtmaWxlbmFtZV9lcnJvcn0uZ3onIn19J1wKCQkJ
YAoKCmNkICR7SE9NRV9ESVJ9L2FwcAouLy5jb21tYW5kLnNoICRKT0JfSUQgPiAke2ZpbGVwYXRo
X2xvZ30gMj4gJHtmaWxlcGF0aF9lcnJvcn0KZXhpdF9zdGF0dXM9JD8Kam9iZW5kZGF0ZT0kKGRh
dGUgJyslWSVtJWRUJUglTSVTWicpCmVuZF90aW1lPSQoZGF0ZSArJXMpCmpvYl9kdXJhdGlvbl9z
PSQoKCBlbmRfdGltZSAtIHN0YXJ0X3RpbWUgKSkKCm91dF90eHRfc2l6ZT1gc3RhdCAtLXByaW50
Zj0iJXMiICR7ZmlsZXBhdGhfbG9nfWAKbG9nX2Vycm9yX3NpemU9YHN0YXQgLS1wcmludGY9IiVz
IiAke2ZpbGVwYXRoX2Vycm9yfWAKCiNpZiBbWyAkb3V0X3R4dF9zaXplIC1ndCAyNTYgXV07IHRo
ZW4KCWxvZ190eHQ9JHtsb2dfdHh0fSIoLi4uKSIjCiNmaQoKI2lmIFtbICRsb2dfZXJyb3Jfc2l6
ZSAtZ3QgMjU2IF1dOyB0aGVuCiMJbG9nX2Vycm9yPSR7bG9nX2Vycm9yfSIoLi4uKSIKI2ZpCgoK
Z3ppcCAkZmlsZXBhdGhfbG9nCmd6aXAgJGZpbGVwYXRoX2Vycm9yCgpTM19sb2c9JHtTM19MT0NB
VElPTn0vcmVzLyR7Q0xVU1RFUkRBVEV9ClMzX2Vycm9yPSR7UzNfTE9DQVRJT059L2xvZy9zdGRf
ZXJyb3JfJHtDTFVTVEVSREFURX0KCmF3cyBzMyAtLXJlZ2lvbiAke1JFR0lPTn0gY3AgJHtmaWxl
cGF0aF9sb2d9Lmd6ICR7UzNfbG9nfS8KYXdzIHMzIC0tcmVnaW9uICR7UkVHSU9OfSBjcCAke2Zp
bGVwYXRoX2Vycm9yfS5neiAke1MzX2Vycm9yfS8KCnJlcz1gYXdzIGR5bmFtb2RiIC0tcmVnaW9u
ICR7UkVHSU9OfSBwdXQtaXRlbSAtLXRhYmxlLW5hbWUgJHtKT0JTVEFCTEV9IFwKICAgIC0taXRl
bSAneyJqb2JpZCI6eyJOIjoiJyR7Sk9CX0lEfScifSwibm9kZWlkIjp7Ik4iOiInJHtOT0RFSUR9
JyJ9LCBcCgkJCSJzdGF0dXMiOnsiUyI6ImNvbXBsZXRlZCJ9LFwKICAgICAgICAgICAgImpvYnN0
YXJ0ZGF0ZSI6eyJTIjoiJyR7am9ic3RhcnRkYXRlfScifSxcCiAgICAgICAgICAgICJqb2JlbmRk
YXRlIjp7IlMiOiInJHtqb2JlbmRkYXRlfScifSxcCgkJCSJqb2JfZHVyYXRpb25fcyI6eyJOIjoi
JyR7am9iX2R1cmF0aW9uX3N9JyJ9LFwKCQkJImV4aXRfc3RhdHVzIjp7Ik4iOiInJHtleGl0X3N0
YXR1c30nIn0sXAogICAgICAgICAgICAib3V0X3R4dF9zaXplIjp7Ik4iOiInJHtvdXRfdHh0X3Np
emV9JyJ9LFwKICAgICAgICAgICAgImxvZ19lcnJvcl9zaXplIjp7Ik4iOiInJHtsb2dfZXJyb3Jf
c2l6ZX0nIn0sXAoJCQkiUzNfbG9nIjp7IlMiOiInJHtTM19sb2d9LyR7ZmlsZW5hbWVfbG9nfS5n
eicifSxcCgkJCSJTM19lcnJvciI6eyJTIjoiJyR7UzNfZXJyb3J9LyR7ZmlsZW5hbWVfZXJyb3J9
Lmd6JyJ9fSdcCgkJCWAK" | base64 -d > ${tmpname}
aws s3 --region ${REGION} mv ${tmpname} ${S3_LOCATION}/app/job_envelope.sh

printf "#!/bin/bash\n\n" > ${RUN_NODE_FILE}
printf "CLUSTERNAME=${CLUSTERNAME}\n" >> ${RUN_NODE_FILE}
printf "REGION=${REGION}\n" >> ${RUN_NODE_FILE}
printf "\n" >> ${RUN_NODE_FILE}
printf "CiNDTFVTVEVSTkFNRT1teXNpbQojUkVHSU9OPSJ1cy1lYXN0LTIiCgojYXB0IHVwZGF0ZSAtLXll
cwojYXB0IGluc3RhbGwgYXdzY2xpIGpxIC0teWVzCiNzdSB1YnVudHUKCiNzZXQgLWUKClMzX0xP
Q0FUSU9OPWBhd3MgZHluYW1vZGIgLS1yZWdpb24gJHtSRUdJT059IGdldC1pdGVtIC0tdGFibGUt
bmFtZSBraXNzY19jbHVzdGVycyAtLWtleSAneyJjbHVzdGVybmFtZSI6eyJTIjoiJyIke0NMVVNU
RVJOQU1FfSInIn19JyB8IGpxIC1yICIuSXRlbS5TM19mb2xkZXIuUyJgCkpPQlNUQUJMRT0ia2lz
c2Nfam9ic18ke0NMVVNURVJOQU1FfSIKQ0xVU1RFUlRBQkxFPSJraXNzY19jbHVzdGVyXyR7Q0xV
U1RFUk5BTUV9IgpIT01FX0RJUj0vaG9tZS91YnVudHUva2lzc2MtJHtDTFVTVEVSTkFNRX0KCmVj
aG8gIlMzX0xPQ0FUSU9OICR7UzNfTE9DQVRJT059IgoKCk5PREVJRD1gYXdzIGR5bmFtb2RiIC0t
cmVnaW9uICR7UkVHSU9OfSB1cGRhdGUtaXRlbSBcCiAgICAtLXRhYmxlLW5hbWUga2lzc2NfY2x1
c3RlcnMgXAogICAgLS1rZXkgJ3siY2x1c3Rlcm5hbWUiOnsiUyI6IiciJHtDTFVTVEVSTkFNRX0i
JyJ9fScgXAogICAgLS11cGRhdGUtZXhwcmVzc2lvbiAiU0VUIG5vZGVpZCA9IG5vZGVpZCArIDpp
bmNyIiBcCiAgICAtLWV4cHJlc3Npb24tYXR0cmlidXRlLXZhbHVlcyAneyI6aW5jciI6eyJOIjoi
MSJ9fScgXAogICAgLS1yZXR1cm4tdmFsdWVzIFVQREFURURfTkVXIHwganEgLXIgIi5BdHRyaWJ1
dGVzLm5vZGVpZC5OImAKcHJpbnRmICR7Tk9ERUlEfSA+IC9ob21lL3VidW50dS9ub2RlLmlkCgpj
cmVhdGVkZGF0ZT0kKGRhdGUgJyslWSVtJWRUJUglTSVTWicpCgplY2hvICJTdGFydGluZyBjbHVz
dGVyIG5vZGUgd2l0aCBub2RlaWQ6ICR7Tk9ERUlEfSBOb2RlIGNyZWF0aW9uIGRhdGU6ICR7Y3Jl
YXRlZGRhdGV9IgoKTk9ERUlEX0Y9IiQocHJpbnRmICIlMDVkIiAkTk9ERUlEKSIKCm1rZGlyIC1w
ICR7SE9NRV9ESVJ9Cm1rZGlyIC1wICR7SE9NRV9ESVJ9L2FwcC8KbWtkaXIgLXAgJHtIT01FX0RJ
Un0vcmVzLwpta2RpciAtcCAke0hPTUVfRElSfS9sb2cvCmVjaG8gU3luY2hyb25pemluZyBmaWxl
cy4uLgphd3MgczMgLS1yZWdpb24gJHtSRUdJT059IHN5bmMgJHtTM19MT0NBVElPTn0vYXBwLyAk
e0hPTUVfRElSfS9hcHAvICY+IC9kZXYvbnVsbApjaG1vZCAreCAke0hPTUVfRElSfS9hcHAvLmNv
bW1hbmQuc2gKY2htb2QgK3ggJHtIT01FX0RJUn0vYXBwL2pvYl9lbnZlbG9wZS5zaAoKQ0xVU1RF
UkRBVEU9YGF3cyBkeW5hbW9kYiAtLXJlZ2lvbiAke1JFR0lPTn0gZ2V0LWl0ZW0gXAogICAgLS10
YWJsZS1uYW1lIGtpc3NjX2NsdXN0ZXJzIFwKICAgIC0ta2V5ICd7ImNsdXN0ZXJuYW1lIjp7IlMi
OiInIiR7Q0xVU1RFUk5BTUV9IicifX0nIFwKICAgIHwganEgLXIgIi5JdGVtLmRhdGUuUyJgCgpl
Y2hvICJEYXRlIG9mIHRoZSBjbHVzdGVyICR7Q0xVU1RFUk5BTUV9OiAke0NMVVNURVJEQVRFfSIK
Cgpob3N0bmFtZT1gY3VybCAtcyBodHRwOi8vMTY5LjI1NC4xNjkuMjU0L2xhdGVzdC9tZXRhLWRh
dGEvcHVibGljLWhvc3RuYW1lYAppcD1gY3VybCAtcyBodHRwOi8vMTY5LjI1NC4xNjkuMjU0L2xh
dGVzdC9tZXRhLWRhdGEvcHVibGljLWlwdjRgCmFtaV9pZD1gY3VybCAtcyBodHRwOi8vMTY5LjI1
NC4xNjkuMjU0L2xhdGVzdC9tZXRhLWRhdGEvYW1pLWlkYAppbnN0YW5jZV9pZD1gY3VybCAtcyBo
dHRwOi8vMTY5LjI1NC4xNjkuMjU0L2xhdGVzdC9tZXRhLWRhdGEvaW5zdGFuY2UtaWRgCmluc3Rh
bmNlX3R5cGU9YGN1cmwgLXMgaHR0cDovLzE2OS4yNTQuMTY5LjI1NC9sYXRlc3QvbWV0YS1kYXRh
L2luc3RhbmNlLXR5cGVgCmlhbV9wcm9maWxlPWBjdXJsIC1zIGh0dHA6Ly8xNjkuMjU0LjE2OS4y
NTQvbGF0ZXN0L21ldGEtZGF0YS9pYW0vaW5mbyB8IGpxIC1yICIuSW5zdGFuY2VQcm9maWxlQXJu
IiAyPi9kZXYvbnVsbGAKaWYgW1sgLXogJHtpYW1fcHJvZmlsZX0gXV07IHRoZW4KICAgaWFtX3By
b2ZpbGU9Ii0iCmZpCmF6PWBjdXJsIC1zIGh0dHA6Ly8xNjkuMjU0LjE2OS4yNTQvbGF0ZXN0L21l
dGEtZGF0YS9wbGFjZW1lbnQvYXZhaWxhYmlsaXR5LXpvbmVgCnNlY3VyaXR5X2dyb3Vwcz1gY3Vy
bCAtcyBodHRwOi8vMTY5LjI1NC4xNjkuMjU0L2xhdGVzdC9tZXRhLWRhdGEvc2VjdXJpdHktZ3Jv
dXBzYAppZiBbWyAteiAke3NlY3VyaXR5X2dyb3Vwc30gXV07IHRoZW4KICAgc2VjdXJpdHlfZ3Jv
dXBzPSItIgpmaQoKZWNobyAiTm9kZSBob3N0bmFtZTogJHtob3N0bmFtZX0iCmVjaG8gIk5vZGUg
aXA6ICR7aXB9IgplY2hvICJOb2RlIGFtaV9pZDogJHthbWlfaWR9IgplY2hvICJOb2RlIGluc3Rh
bmNlX2lkOiAke2luc3RhbmNlX2lkfSIKZWNobyAiTm9kZSBpbnN0YW5jZV90eXBlOiAke2luc3Rh
bmNlX3R5cGV9IgplY2hvICJOb2RlIGlhbV9wcm9maWxlOiAke2lhbV9wcm9maWxlfSIKZWNobyAi
Tm9kZSBhdmFpbGFiaWxpdHkgem9uZTogJHthen0iCmVjaG8gIkNvbmZpZ3VyZWQgZWN1cml0eSBn
cm91cHM6ICR7c2VjdXJpdHlfZ3JvdXBzfSIKCk5QUk9DPWBucHJvY2AKbG9nZmlsZT0iJHtIT01F
X0RJUn0vbG9nLyR7Tk9ERUlEX0Z9XyR7Y3JlYXRlZGRhdGV9LmxvZy50eHQiCgplY2hvICJOdW1i
ZXIgb2YgYXZhaWxhYmxlIHZDUFUgY29yZXM6ICR7TlBST0N9IgoKZWNobyAiTm9kZSBpbmZvcm1h
dGlvbiB3aWxsIGJlIHdyaXR0ZW4gdG8gRHluYW1vRkIgdGFibGU6ICR7Q0xVU1RFUlRBQkxFfSIK
cmVzPWBhd3MgZHluYW1vZGIgLS1yZWdpb24gJHtSRUdJT059IHB1dC1pdGVtIC0tdGFibGUtbmFt
ZSAke0NMVVNURVJUQUJMRX0gXAoJLS1pdGVtICd7Im5vZGVpZCI6eyJOIjoiJyR7Tk9ERUlEfSci
fSwibm9kZWRhdGUiOnsiUyI6Iicke2NyZWF0ZWRkYXRlfScifSxcCgkJCSJjbHVzdGVyZGF0ZSI6
eyJTIjoiJyR7Q0xVU1RFUkRBVEV9JyJ9LFwKCQkJIm5wcm9jIjp7IlMiOiInJHtOUFJPQ30nIn0s
ImxvZ2ZpbGUiOnsiUyI6Iicke2xvZ2ZpbGV9JyJ9LFwKCQkJImhvc3RuYW1lIjp7IlMiOiInJHto
b3N0bmFtZX0nIn0sXAoJCQkiaXAiOnsiUyI6Iicke2lwfScifSwiYW1pX2lkIjp7IlMiOiInJHth
bWlfaWR9JyJ9LFwKCQkJImluc3RhbmNlX2lkIjp7IlMiOiInJHtpbnN0YW5jZV9pZH0nIn0sXAoJ
CQkiaW5zdGFuY2VfdHlwZSI6eyJTIjoiJyR7aW5zdGFuY2VfdHlwZX0nIn0sXAoJCQkiaWFtX3By
b2ZpbGUiOnsiUyI6Iicke2lhbV9wcm9maWxlfScifSxcCgkJCSJheiI6eyJTIjoiJyR7YXp9JyJ9
LFwKCQkJInNlY3VyaXR5X2dyb3VwcyI6eyJTIjoiJyR7c2VjdXJpdHlfZ3JvdXBzfScifX0nIGAK
Cm5vaHVwIHNlcSAxIDEwMDAwMDAwMCB8IHhhcmdzIC0tbWF4LWFyZ3M9MSAtLW1heC1wcm9jcz0k
TlBST0MgYmFzaCAke0hPTUVfRElSfS9hcHAvam9iX2VudmVsb3BlLnNoICIke0NMVVNURVJOQU1F
fSIgIiR7UkVHSU9OfSIgIiR7Tk9ERUlEfSIgIiR7UzNfTE9DQVRJT059IiAiJHtIT01FX0RJUn0i
ICIke0NMVVNURVJEQVRFfSIgJj4+ICRsb2dmaWxlICYKCmVjaG8gIk5vZGUgJHtOT0RFSUR9IGhh
cyBiZWVuIHN1Y2Nlc3NmdWxseSBzdGFydGVkLiIKZWNobyAiSW4gb3JkZXIgdG8gdGVybWluYXRl
IGNvbXB1dGF0aW9ucyBvbiB0aGlzIG5vZGUgbG9vayBmb3IgdGhlIHhhcmdzIHByb2Nlc3MgYW5k
IGtpbGwgaXQgKHBraWxsIC1mIHhhcmdzKSI=" | base64 -d >> ${RUN_NODE_FILE}


printf "\nSUCCESS!\n"
printf "The cluster ${CLUSTERNAME} has been successfully build!  \n"
printf "Now you can simply run ${RUN_NODE_FILE} on any AWS EC2 machine to start processing on your cluster. \n"
printf "${RUN_NODE_FILE} can also be used as a cloud-init configuration for EC2 instances. \n"

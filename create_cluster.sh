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

CLOUD_INIT_FILE=./cloud_init_node_${CLUSTERNAME}.sh

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

printf "#!/bin/bash\n\n${COMMAND} \$1" > ${HOME_DIR}/job.sh
chmod +x ${HOME_DIR}/job.sh

echo "copying application data to S3" 
aws s3 --region ${REGION} cp --recursive ${HOME_DIR} ${S3_LOCATION}/app


job_envelope_base64="IyEvYmluL2Jhc2gKCkNMVVNURVJOQU1FPSQxClJFR0lPTj0kMgpOT0RFSUQ9JDMKUzNfTE9DQVRJ
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
YAoKCmNkICR7SE9NRV9ESVJ9L2FwcAouL2pvYi5zaCAkSk9CX0lEID4gJHtmaWxlcGF0aF9sb2d9
IDI+ICR7ZmlsZXBhdGhfZXJyb3J9CmV4aXRfc3RhdHVzPSQ/CmpvYmVuZGRhdGU9JChkYXRlICcr
JVklbSVkVCVIJU0lU1onKQplbmRfdGltZT0kKGRhdGUgKyVzKQpqb2JfZHVyYXRpb25fcz0kKCgg
ZW5kX3RpbWUgLSBzdGFydF90aW1lICkpCgpvdXRfdHh0X3NpemU9YHN0YXQgLS1wcmludGY9IiVz
IiAke2ZpbGVwYXRoX2xvZ31gCmxvZ19lcnJvcl9zaXplPWBzdGF0IC0tcHJpbnRmPSIlcyIgJHtm
aWxlcGF0aF9lcnJvcn1gCgojaWYgW1sgJG91dF90eHRfc2l6ZSAtZ3QgMjU2IF1dOyB0aGVuCgls
b2dfdHh0PSR7bG9nX3R4dH0iKC4uLikiIwojZmkKCiNpZiBbWyAkbG9nX2Vycm9yX3NpemUgLWd0
IDI1NiBdXTsgdGhlbgojCWxvZ19lcnJvcj0ke2xvZ19lcnJvcn0iKC4uLikiCiNmaQoKCmd6aXAg
JGZpbGVwYXRoX2xvZwpnemlwICRmaWxlcGF0aF9lcnJvcgoKUzNfbG9nPSR7UzNfTE9DQVRJT059
L3Jlcy8ke0NMVVNURVJEQVRFfQpTM19lcnJvcj0ke1MzX0xPQ0FUSU9OfS9sb2cvc3RkX2Vycm9y
XyR7Q0xVU1RFUkRBVEV9Cgphd3MgczMgLS1yZWdpb24gJHtSRUdJT059IGNwICR7ZmlsZXBhdGhf
bG9nfS5neiAke1MzX2xvZ30vCmF3cyBzMyAtLXJlZ2lvbiAke1JFR0lPTn0gY3AgJHtmaWxlcGF0
aF9lcnJvcn0uZ3ogJHtTM19lcnJvcn0vCgpyZXM9YGF3cyBkeW5hbW9kYiAtLXJlZ2lvbiAke1JF
R0lPTn0gcHV0LWl0ZW0gLS10YWJsZS1uYW1lICR7Sk9CU1RBQkxFfSBcCiAgICAtLWl0ZW0gJ3si
am9iaWQiOnsiTiI6Iicke0pPQl9JRH0nIn0sIm5vZGVpZCI6eyJOIjoiJyR7Tk9ERUlEfScifSwg
XAoJCQkic3RhdHVzIjp7IlMiOiJjb21wbGV0ZWQifSxcCiAgICAgICAgICAgICJqb2JzdGFydGRh
dGUiOnsiUyI6Iicke2pvYnN0YXJ0ZGF0ZX0nIn0sXAogICAgICAgICAgICAiam9iZW5kZGF0ZSI6
eyJTIjoiJyR7am9iZW5kZGF0ZX0nIn0sXAoJCQkiam9iX2R1cmF0aW9uX3MiOnsiTiI6Iicke2pv
Yl9kdXJhdGlvbl9zfScifSxcCgkJCSJleGl0X3N0YXR1cyI6eyJOIjoiJyR7ZXhpdF9zdGF0dXN9
JyJ9LFwKICAgICAgICAgICAgIm91dF90eHRfc2l6ZSI6eyJOIjoiJyR7b3V0X3R4dF9zaXplfSci
fSxcCiAgICAgICAgICAgICJsb2dfZXJyb3Jfc2l6ZSI6eyJOIjoiJyR7bG9nX2Vycm9yX3NpemV9
JyJ9LFwKCQkJIlMzX2xvZyI6eyJTIjoiJyR7UzNfbG9nfS8ke2ZpbGVuYW1lX2xvZ30uZ3onIn0s
XAoJCQkiUzNfZXJyb3IiOnsiUyI6Iicke1MzX2Vycm9yfS8ke2ZpbGVuYW1lX2Vycm9yfS5neici
fX0nXAoJCQlgCg=="

run_node_template_base64="CiNDTFVTVEVSTkFNRT1teXNpbQojUkVHSU9OPSJ1cy1lYXN0LTIiCgpzZXQgLWUKClMzX0xPQ0FU
SU9OPWBhd3MgZHluYW1vZGIgLS1yZWdpb24gJHtSRUdJT059IGdldC1pdGVtIC0tdGFibGUtbmFt
ZSBraXNzY19jbHVzdGVycyAtLWtleSAneyJjbHVzdGVybmFtZSI6eyJTIjoiJyIke0NMVVNURVJO
QU1FfSInIn19JyB8IGpxIC1yICIuSXRlbS5TM19mb2xkZXIuUyJgCkpPQlNUQUJMRT0ia2lzc2Nf
am9ic18ke0NMVVNURVJOQU1FfSIKQ0xVU1RFUlRBQkxFPSJraXNzY19jbHVzdGVyXyR7Q0xVU1RF
Uk5BTUV9IgpIT01FX0RJUj0vaG9tZS91YnVudHUva2lzc2MtJHtDTFVTVEVSTkFNRX0KCmVjaG8g
IlMzX0xPQ0FUSU9OICR7UzNfTE9DQVRJT059IgoKCk5PREVJRD1gYXdzIGR5bmFtb2RiIC0tcmVn
aW9uICR7UkVHSU9OfSB1cGRhdGUtaXRlbSBcCiAgICAtLXRhYmxlLW5hbWUga2lzc2NfY2x1c3Rl
cnMgXAogICAgLS1rZXkgJ3siY2x1c3Rlcm5hbWUiOnsiUyI6IiciJHtDTFVTVEVSTkFNRX0iJyJ9
fScgXAogICAgLS11cGRhdGUtZXhwcmVzc2lvbiAiU0VUIG5vZGVpZCA9IG5vZGVpZCArIDppbmNy
IiBcCiAgICAtLWV4cHJlc3Npb24tYXR0cmlidXRlLXZhbHVlcyAneyI6aW5jciI6eyJOIjoiMSJ9
fScgXAogICAgLS1yZXR1cm4tdmFsdWVzIFVQREFURURfTkVXIHwganEgLXIgIi5BdHRyaWJ1dGVz
Lm5vZGVpZC5OImAKcHJpbnRmICR7Tk9ERUlEfSA+IC9ob21lL3VidW50dS9ub2RlLmlkCgpjcmVh
dGVkZGF0ZT0kKGRhdGUgJyslWSVtJWRUJUglTSVTWicpCgplY2hvICJTdGFydGluZyBjbHVzdGVy
IG5vZGUgd2l0aCBub2RlaWQ6ICR7Tk9ERUlEfSBOb2RlIGNyZWF0aW9uIGRhdGU6ICR7Y3JlYXRl
ZGRhdGV9IgoKTk9ERUlEX0Y9IiQocHJpbnRmICIlMDVkIiAkTk9ERUlEKSIKCm1rZGlyIC1wICR7
SE9NRV9ESVJ9Cm1rZGlyIC1wICR7SE9NRV9ESVJ9L2FwcC8KbWtkaXIgLXAgJHtIT01FX0RJUn0v
cmVzLwpta2RpciAtcCAke0hPTUVfRElSfS9sb2cvCmVjaG8gU3luY2hyb25pemluZyBmaWxlcy4u
Lgphd3MgczMgLS1yZWdpb24gJHtSRUdJT059IHN5bmMgJHtTM19MT0NBVElPTn0vYXBwLyAke0hP
TUVfRElSfS9hcHAvICY+IC9kZXYvbnVsbApjaG1vZCAreCAke0hPTUVfRElSfS9hcHAvam9iLnNo
CmNobW9kICt4ICR7SE9NRV9ESVJ9L2FwcC9qb2JfZW52ZWxvcGUuc2gKCkNMVVNURVJEQVRFPWBh
d3MgZHluYW1vZGIgLS1yZWdpb24gJHtSRUdJT059IGdldC1pdGVtIFwKICAgIC0tdGFibGUtbmFt
ZSBraXNzY19jbHVzdGVycyBcCiAgICAtLWtleSAneyJjbHVzdGVybmFtZSI6eyJTIjoiJyIke0NM
VVNURVJOQU1FfSInIn19JyBcCiAgICB8IGpxIC1yICIuSXRlbS5kYXRlLlMiYAoKZWNobyAiRGF0
ZSBvZiB0aGUgY2x1c3RlciAke0NMVVNURVJOQU1FfTogJHtDTFVTVEVSREFURX0iCgoKaG9zdG5h
bWU9YGN1cmwgLXMgaHR0cDovLzE2OS4yNTQuMTY5LjI1NC9sYXRlc3QvbWV0YS1kYXRhL3B1Ymxp
Yy1ob3N0bmFtZWAKaXA9YGN1cmwgLXMgaHR0cDovLzE2OS4yNTQuMTY5LjI1NC9sYXRlc3QvbWV0
YS1kYXRhL3B1YmxpYy1pcHY0YAphbWlfaWQ9YGN1cmwgLXMgaHR0cDovLzE2OS4yNTQuMTY5LjI1
NC9sYXRlc3QvbWV0YS1kYXRhL2FtaS1pZGAKaW5zdGFuY2VfaWQ9YGN1cmwgLXMgaHR0cDovLzE2
OS4yNTQuMTY5LjI1NC9sYXRlc3QvbWV0YS1kYXRhL2luc3RhbmNlLWlkYAppbnN0YW5jZV90eXBl
PWBjdXJsIC1zIGh0dHA6Ly8xNjkuMjU0LjE2OS4yNTQvbGF0ZXN0L21ldGEtZGF0YS9pbnN0YW5j
ZS10eXBlYAppYW1fcHJvZmlsZT1gY3VybCAtcyBodHRwOi8vMTY5LjI1NC4xNjkuMjU0L2xhdGVz
dC9tZXRhLWRhdGEvaWFtL2luZm8gfCBqcSAtciAiLkluc3RhbmNlUHJvZmlsZUFybiIgMj4vZGV2
L251bGxgCmlmIFtbIC16ICR7aWFtX3Byb2ZpbGV9IF1dOyB0aGVuCiAgIGlhbV9wcm9maWxlPSIt
IgpmaQphej1gY3VybCAtcyBodHRwOi8vMTY5LjI1NC4xNjkuMjU0L2xhdGVzdC9tZXRhLWRhdGEv
cGxhY2VtZW50L2F2YWlsYWJpbGl0eS16b25lYApzZWN1cml0eV9ncm91cHM9YGN1cmwgLXMgaHR0
cDovLzE2OS4yNTQuMTY5LjI1NC9sYXRlc3QvbWV0YS1kYXRhL3NlY3VyaXR5LWdyb3Vwc2AKaWYg
W1sgLXogJHtzZWN1cml0eV9ncm91cHN9IF1dOyB0aGVuCiAgIHNlY3VyaXR5X2dyb3Vwcz0iLSIK
ZmkKCmVjaG8gIk5vZGUgaG9zdG5hbWU6ICR7aG9zdG5hbWV9IgplY2hvICJOb2RlIGlwOiAke2lw
fSIKZWNobyAiTm9kZSBhbWlfaWQ6ICR7YW1pX2lkfSIKZWNobyAiTm9kZSBpbnN0YW5jZV9pZDog
JHtpbnN0YW5jZV9pZH0iCmVjaG8gIk5vZGUgaW5zdGFuY2VfdHlwZTogJHtpbnN0YW5jZV90eXBl
fSIKZWNobyAiTm9kZSBpYW1fcHJvZmlsZTogJHtpYW1fcHJvZmlsZX0iCmVjaG8gIk5vZGUgYXZh
aWxhYmlsaXR5IHpvbmU6ICR7YXp9IgplY2hvICJDb25maWd1cmVkIGVjdXJpdHkgZ3JvdXBzOiAk
e3NlY3VyaXR5X2dyb3Vwc30iCgpOUFJPQz1gbnByb2NgCmxvZ2ZpbGU9IiR7SE9NRV9ESVJ9L2xv
Zy8ke05PREVJRF9GfV8ke2NyZWF0ZWRkYXRlfS5sb2cudHh0IgoKZWNobyAiTnVtYmVyIG9mIGF2
YWlsYWJsZSB2Q1BVIGNvcmVzOiAke05QUk9DfSIKCmVjaG8gIk5vZGUgaW5mb3JtYXRpb24gd2ls
bCBiZSB3cml0dGVuIHRvIER5bmFtb0ZCIHRhYmxlOiAke0NMVVNURVJUQUJMRX0iCnJlcz1gYXdz
IGR5bmFtb2RiIC0tcmVnaW9uICR7UkVHSU9OfSBwdXQtaXRlbSAtLXRhYmxlLW5hbWUgJHtDTFVT
VEVSVEFCTEV9IFwKCS0taXRlbSAneyJub2RlaWQiOnsiTiI6Iicke05PREVJRH0nIn0sIm5vZGVk
YXRlIjp7IlMiOiInJHtjcmVhdGVkZGF0ZX0nIn0sXAoJCQkiY2x1c3RlcmRhdGUiOnsiUyI6Iick
e0NMVVNURVJEQVRFfScifSxcCgkJCSJucHJvYyI6eyJTIjoiJyR7TlBST0N9JyJ9LCJsb2dmaWxl
Ijp7IlMiOiInJHtsb2dmaWxlfScifSxcCgkJCSJob3N0bmFtZSI6eyJTIjoiJyR7aG9zdG5hbWV9
JyJ9LFwKCQkJImlwIjp7IlMiOiInJHtpcH0nIn0sImFtaV9pZCI6eyJTIjoiJyR7YW1pX2lkfSci
fSxcCgkJCSJpbnN0YW5jZV9pZCI6eyJTIjoiJyR7aW5zdGFuY2VfaWR9JyJ9LFwKCQkJImluc3Rh
bmNlX3R5cGUiOnsiUyI6Iicke2luc3RhbmNlX3R5cGV9JyJ9LFwKCQkJImlhbV9wcm9maWxlIjp7
IlMiOiInJHtpYW1fcHJvZmlsZX0nIn0sXAoJCQkiYXoiOnsiUyI6Iicke2F6fScifSxcCgkJCSJz
ZWN1cml0eV9ncm91cHMiOnsiUyI6Iicke3NlY3VyaXR5X2dyb3Vwc30nIn19JyBgCgpub2h1cCBz
ZXEgMSAxMDAwMDAwMDAgfCB4YXJncyAtLW1heC1hcmdzPTEgLS1tYXgtcHJvY3M9JE5QUk9DIGJh
c2ggJHtIT01FX0RJUn0vYXBwL2pvYl9lbnZlbG9wZS5zaCAiJHtDTFVTVEVSTkFNRX0iICIke1JF
R0lPTn0iICIke05PREVJRH0iICIke1MzX0xPQ0FUSU9OfSIgIiR7SE9NRV9ESVJ9IiAiJHtDTFVT
VEVSREFURX0iICY+PiAkbG9nZmlsZSAmCgplY2hvICJOb2RlICR7Tk9ERUlEfSBoYXMgYmVlbiBz
dWNjZXNzZnVsbHkgc3RhcnRlZC4iCmVjaG8gIkluIG9yZGVyIHRvIHRlcm1pbmF0ZSBjb21wdXRh
dGlvbnMgb24gdGhpcyBub2RlIGxvb2sgZm9yIHRoZSB4YXJncyBwcm9jZXNzIGFuZCBraWxsIGl0
IChwa2lsbCAtZiB4YXJncyki"

cloud_init_base64="CnN1ZG8gYXB0IHVwZGF0ZSAtLXllcwpzdWRvIGFwdCBpbnN0YWxsIGF3c2NsaSBqcSAtLXllcwpz
dWRvIHN1IHVidW50dQoKYXdzICAtLXJlZ2lvbiAke1JFR0lPTn0gczMgY3AgJHtTM19SVU5fTk9E
RV9TQ1JJUFR9IC9ob21lL3VidW50dS9ydW5fbm9kZV8ke0NMVVNURVJOQU1FfS5zaApjZCAvaG9t
ZS91YnVudHUKYmFzaCBydW5fbm9kZV8ke0NMVVNURVJOQU1FfS5zaA=="

tmpname=`tempfile`
printf "${job_envelope_base64}" | base64 -d > ${tmpname}
aws s3 --region ${REGION} mv ${tmpname} ${S3_LOCATION}/app/job_envelope.sh

S3_RUN_NODE_SCRIPT=${S3_LOCATION}/app/run_node_${CLUSTERNAME}.sh

printf "#!/bin/bash\n\n" > ${tmpname}
printf "CLUSTERNAME=${CLUSTERNAME}\n" >> ${tmpname}
printf "REGION=${REGION}\n" >> ${tmpname}
printf "${run_node_template_base64}" | base64 -d >> ${tmpname}
aws s3 --region ${REGION} mv ${tmpname} ${S3_RUN_NODE_SCRIPT}

printf "#!/bin/bash\n\n" > ${CLOUD_INIT_FILE}
printf "CLUSTERNAME=${CLUSTERNAME}\n" >> ${CLOUD_INIT_FILE}
printf "S3_RUN_NODE_SCRIPT=${S3_RUN_NODE_SCRIPT}\n\n" >> ${CLOUD_INIT_FILE}

printf  "${cloud_init_base64}" | base64 -d >> ${CLOUD_INIT_FILE}
chmod +x ${CLOUD_INIT_FILE}

printf "\nSUCCESS!\n"
printf "The cluster ${CLUSTERNAME} has been successfully build!  \n"
printf "Now you can simply run ${CLOUD_INIT_FILE} on any AWS EC2 machine to start processing on your cluster. \n"
printf "${CLOUD_INIT_FILE} can also be used as a cloud-init configuration for EC2 instances. \n"

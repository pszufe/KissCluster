function contains {
    [[ $1 =~ (^|[[:space:]])$2($|[[:space:]]) ]] && return 0 || return 1
}


function checkinstall {
  PKG_NAME=$1
  PKG_OK=$(dpkg-query -W --showformat='${Status}\n' ${PKG_NAME}|grep "install ok installed")
  if [ "" == "$PKG_OK" ]; then
    echo "Missing package ${PKG_NAME}. "
	echo "Trying to install ${PKG_NAME}. "
    sudo apt --yes install $PKG_NAME
  fi
}


function dynamoDBwait4table {
    TABLENAME=$1
    while
        status=`aws dynamodb --region ${REGION} describe-table --table-name ${TABLENAME} 2>/dev/null  | jq -r ".Table.TableStatus"`
		if [[ $status != "ACTIVE" ]]; then
			echo "Waiting for DynamoDB table ${TABLENAME} in region ${REGION} to be active"
			sleep 3
		fi
        [[ $status != "ACTIVE" ]]
    do
        :
    done
    echo "DynamoDB table ${TABLENAME} created"
}

function dynamoDBdroptable {
    params="$1"
    tablearr=(${params})
    tablearr2=()
    for TABLENAME in ${tablearr[*]};do
	res=`aws dynamodb --region ${REGION} describe-table --table-name ${TABLENAME} 2>/dev/null` || echo "DynamoDB table ${TABLENAME} not found"
	if [[ ! -z "${res// }" ]]; then
	  echo "Dropping DynamoDB table ${TABLENAME}"
	  res=`aws dynamodb --region ${REGION}  delete-table --table-name ${TABLENAME}`
          tablearr2+=(${TABLENAME})
        fi
    done
    for TABLENAME in ${tablearr2[*]};do
	  while
	    res=`aws dynamodb --region ${REGION} describe-table --table-name ${TABLENAME} 2>/dev/null`
		echo "Waiting for DynamoDB table ${TABLENAME} to be dropped"
		sleep 3
		if [[ ! -z "${res// }" ]]; then
			echo "Waiting for DynamoDB table ${TABLENAME} to be dropped"
			sleep 3
		fi
		[[ ! -z "${res// }" ]]
	   do
		 :
	   done
	   echo "DynamoDB table ${TABLENAME} has been dropped"
    done
}

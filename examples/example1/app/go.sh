sleep 3
x=$(( ( RANDOM % 100 )  + 1 ))
printf "${1}\tD\t${HOSTNAME}\t${x}\n"


#!/bin/bash

JOB_ID=$1

if [[ -z "$JOB_ID" ]];then
    echo "missing JOB_ID parameter"
    exit 1
fi

set -e

#The jobid contains information about execution number. It is being increase by one for each NetLogo runn across our cluster


num=$JOB_ID   # we will caluclate parameter values fo the sweep.

n_unforgiving=$(( num % 10 + 5))  #10 values: 5,6,6,...14
num=$(( num / 10 ))
n_defect=$(( num % 9 + 4)) #9 values: 4,5,6,...12
num=$(( num / 9 ))
n_tit_for_tat=$(( num % 11 +  5)) #11 values: 5,6,...,15
num=$(( num / 11 ))
## you can add more variables the same way


## now we safe the expermient configs to the file setups.xml

sed 's/\r$//' setup.xml |
  xmlstarlet ed --pf --ps --omit-decl --update "/experiments/experiment[@name='experiment']/enumeratedValueSet[@variable='JOB_ID']/value[@value=0]/@value" -v $JOB_ID |
  xmlstarlet ed --pf --ps --omit-decl --update "/experiments/experiment[@name='experiment']/enumeratedValueSet[@variable='n-unforgiving']/value[@value=10]/@value" -v $n_unforgiving |
  xmlstarlet ed --pf --ps --omit-decl --update "/experiments/experiment[@name='experiment']/enumeratedValueSet[@variable='n-defect']/value[@value=10]/@value" -v $n_defect |
  xmlstarlet ed --pf --ps --omit-decl --update "/experiments/experiment[@name='experiment']/enumeratedValueSet[@variable='n-tit_for-tat']/value[@value=10]/@value" -v $n_tit_for_tat |
  cat > setups${JOB_ID}.xml


## now running the experiment 

/home/ubuntu/NetLogo6.0.2/netlogo-headless.sh --threads 1 --model PDN-PersonIterated.nlogo  --setup-file setups${JOB_ID}.xml --table -

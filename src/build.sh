#!/bin/bash

set -e
cp create_cluster_header.sh ../create_cluster.sh

printf      "job_envelope_base64=\""`cat job_envelope.sh      | base64`"\"\n"  >> ../create_cluster.sh
printf "run_node_template_base64=\""`cat run_node_template.sh | base64`"\"\n"  >> ../create_cluster.sh
cat create_cluster_footer.sh >> ../create_cluster.sh

chmod +x ../create_cluster.sh
echo The build process has been successfully completed!
echo The ../create_cluster.sh is ready.

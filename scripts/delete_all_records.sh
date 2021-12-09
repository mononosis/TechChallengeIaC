#!/bin/bash

dns=$(terraform output --raw lb_dns_name)
ids=$(curl -s "http://${dns}/api/task/" | jq .[].id)
echo -e "Please wait this process can take some minutes."
for i in $ids
do 
  curl "http://$dns/api/task/$i/"\
    -X 'DELETE' \
    --compressed \
    --insecure > /dev/null 2>&1
done

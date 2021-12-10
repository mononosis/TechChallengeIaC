#!/bin/bash

application_url=$(terraform -chdir=../ output --raw application_url)
ids=$(curl -s "${application_url}/api/task/" | jq .[].id)
echo -e "Please wait this process can take some minutes."
for i in $ids
do 
  curl "$application_url/api/task/$i/"\
    -X 'DELETE' \
    --compressed \
    --insecure > /dev/null 2>&1
done

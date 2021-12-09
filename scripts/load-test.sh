#!/bin/bash

# The scrip will first create 1000 records or check if the number of 
# records is less than that. Then make 50 parallel GET request every 
# second. It takes around 10 mins to scale up the number of tasks if 
# 10% of CPU usage is set as the trigger for the autoscaling policy. 
# This is set as default for the Chaos Testing environment.

# jq and aws cli are required in order to perform the test 
echo -e "\nChecking for dependencies...\n"
which jq 

if [ "${?}" != 0 ]
then 
   echo "Please install jq before running the script"
   exit 1
fi

which aws

if [ "${?}" != 0 ]
then 
   echo "Please install aws cli before running the script"
   exit 1
fi

which watch

if [ "${?}" != 0 ]
then 
   echo "Please install watch before running the script"
   exit 1
fi

echo -e "\nRequired dependencies installed\n"

dns=$(terraform output --raw lb_dns_name)
cluster_name=$(terraform output --raw cluster_name)
profile=$(terraform output --raw profile)
region=$(terraform output --raw region)

get_data_new_title(){
cat <<EOF
  { 
    "title":"",
    "priority":1000,
    "completed":false,
    "Title":"$1"
  }
EOF
}

create_new_record(){
  curl "http://${dns}/api/task/" \
    -H 'Content-Type: application/json' \
    --data-raw "$(get_data_new_title $RANDOM)" \
    --insecure > /dev/null 2>&1 
}

get_records(){
  curl "http://${dns}/api/task/" > /dev/null 2>&1
}

length=$(curl -s "http://${dns}/api/task/" | jq length)
remainder=$(( 1000 - $length ))

echo "$length records already in the database"

if [ $length -lt 1000 ]
then 
  echo "Creating ${remainder} records..."
  for i in range `seq 1 $remainder` 
  do 
    $(create_new_record)
    if [ $(($i%4)) == 0 ]
    then 
      length=$(curl -s "http://${dns}/api/task/" | jq length)
      remainder=$(( 1000 - $length ))
      echo -ne "${remainder} remaining records to be created  "\\r
    fi
  done 
else 
  echo "Skipping the creation of new records. The database contains ${length}"
fi

echo -e "\nIn order to watch the number of tasks scaling up and down over time please leave this script running and run the following command in another terminal:"
echo ""
echo "    watch aws ecs list-tasks --cluster ${cluster_name} --profile ${profile} --region ${region}"
echo ""

for i in range {1..10000} 
do 
  for i in range {1..90} 
  do 
    $(get_records) &
  done
  sleep 1
done 



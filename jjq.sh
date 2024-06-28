#!/usr/bin/env bash


results=$(jq -n '')
_test_dir="root"
_test_id=1984
_success=1
#results=$(echo $results | jq --arg "_test_dir" $_test_dir '. += {($_test_dir) : {}}')
results=$(echo $results | jq --arg "_test_dir" $_test_dir \
--arg _test_id $_test_id \
--arg _success $_success \
'. += {($_test_dir) : {"test_id" : ($_test_id), "success" : ($_success) }}'\
)
echo $results
#restored_run_data=$(echo $results | jq '.["test_dir"]')
restored_run_data=$(echo $results | jq --arg "_test_dir" $_test_dir '.[($_test_dir)]')
echo $restored_run_data
_test_id=$(echo $restored_run_data | jq '.test_id' -r)
echo "_test_id is $_test_id"

echo $restored_run_data | jq '.success' -r
str=$'Hello World\n==========='
b64=$(echo "$str" | base64)
echo $b64 | base64 --decode
long_arg="my very long string\
 which does not fit\
 on the screen"

echo $long_arg
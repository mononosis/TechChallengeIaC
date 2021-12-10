# TechChallengeIaC
Declaration of AWS resources for the TechChallengeApp's infrastructure provided by Servian.

## Dependencies & Requirements 

In order to run this terraform module the following dependencies are required:

- An AWS account.
- No more than 4 VPC in the region when the infrastructure will be created.
- Terraform CLI version >= 0.14.9
- AWS CLI version 1
- OSX or Linux
- bash

The AWS CLI must be configured with a profile by setting the security credentials  of a service 
account. For the convenience of this test, the service account might have attached an
AdministratorAccess role. However, for more security constrains and least privilege access please
refer to the infrastructure diagram within the docs folder to assign role policies accordingly. 

## Optional Dependencies

To run a load test and confirm auto scaling policies the following dependencies are required: 

- jq
- watch
- curl 

## Instructions

This module already have some variables declared in tfvars files for testing and production environments.
The variables can be changed at any time to modify the infrastructure parameters. 

To do a quick confirmation of Resiliency run the following within the root module.(please check optional 
dependencies for this step)
        
```
        terraform apply -var-file="testing.tfvars"
```

After the creation of resources have been completed then execute within the scripts folder the load-test.sh
script 
        
```
        cd ./scripts
        ./load-test.sh
```

The load test script will create 1000 records in the database and then fetch those records by making 50 request
in parallel every second.

In order to make the environment more robust please tweak the default values for the variables task_def_cpu, 
task_def_memory, min_capacity, max_capacity, minimum_acu_range, maximum_acu_range and scaling_policy_target_value.

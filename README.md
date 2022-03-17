# Deploying AWS ECS Fargate Service

Provisions a docker container into an ECS(AWS Elastic Container Service) cluster with networking, service discovery registration and healthchecks provided. It also provides settings on how to run and configure the container (e.g., private / public, inject secrets, cpu and memory).

It creates:

- *Secret Manager*: Secret Manager is used to store service secrets with encryption, using KMS key

- *Service*: Creates a public OR a private service based on whether it would be attached to a load balancer or not

- *Load Balancer listener Rule*: Listener Rule is attached to the Load balancer which is passed in from the variables

- *Log Group*: Log group in Cloudwatch where all the application logs are stored

- *Alarms*: For monitoring service metrics. Alarms can send notifications to multiple emails. Type of nofications which can be received are:
  - Average container CPU utilization over last 5 minutes >80%
  - Average container memory utilization over last 5 minutes >80%
  - Average container CPU utilization over last 5 minutes >80%
  - Average container memory utilization over last 5 minutes >80%

- *X-Ray APM*: Attaches a X-Ray APM sidecar container which collects the traces and shows information like latency, error rate, fault rate, ok rates for service to service communication

## Architecture

- X-Ray Sidecar Architecture

![x-ray-sidecar-architecture](https://media.github.mdl.cloud/user/372/files/ffa53400-a5b2-11ea-8c73-eaa6fd875eea)

## Run-Book

### Pre-requisites

#### IMPORTANT NOTE

1. Required version of Terraform is mentioned in `meta.tf`.
2. Go through `variables.tf` for understanding each terraform variable before running this component.

#### Complex Variables in variables.tf

1. `log_aggregation_s3`: Value can be retrived from terraform outputs of "Estate Base" Blueprint Run
2. `service_discovery_namespace`: DNS Namespace to deploy to. Usually it is kept same for the whole application where an application is composed of multiple services. E.g. "demo"
3. `apm_config`: Configuration for X-Ray APM sidecar container. This variable should be set if `attach_apm` is set to true. Format: `{
    service_port = 9000
    image_url    = ""
    cpu          = 0
    memory       = 0
  }` where `service_port` is the port your container would be listening to and defaults to `9000`, `image_url` is the repository url for the apm sidecar container

#### Resources needed before deploying this component

1. VPC with Private Subnets
2. ECS Fargate Cluster
3. Log Aggregation S3 Bucket in AWS Logging Account
4. AWS Application Load Balancer (Optional)

#### Dependent Components

- *KMS key*: Used to encrypt secrets in Secrets Manager
- *SNS notification*: Used to create an SNS topic where alarm notifications can be published

#### AWS Accounts

1. Logging account (AWS account where fargate logs would be aggregated for audit purpose)
2. Spoke/Service account (AWS account where fargate service is to be created)

#### Understanding Complex Variables

##### Secrets

This component gives the ability to create 1 or multiple Secrets Manager secrets and have their values automatically injected into the service container at startup. This is done by way of environment variables defined in the service's ECS Task Definition and pointing to their respective Secrets Manager secret.

Variables are used to make this work:

- `secrets`: Map which contains `secret_name` in AWS Secrets Manager and `secret_json` which is the value containing key/value pair that will become the name and value of the environment variables injected into the container at startup.

Each item in the `secrets` map will become a Secrets Manager secret whose name is provided by the map `key` and whose value will be provided by the `value` of map. The map `value` is a JSON-encoded string that will contain a map of all values for that secret.

At runtime, the container will be injected with environment variables named after the `name` field and whose value will be the content of the `value` (or similarly the JSON-encoded version of the corresponding Secrets Manager secret value).

##### Example

```terraform
locals {
  secret_this_value = {
     this_value = "something"
  }

  secret_that_value = {
     that_value = "something else"
  }
}

module "service" {
  source = "git::https://...../terraform-aws-fargate-service"

  ...
  secrets = {
      "SECRET_THIS": "${jsonencode(local.secret_this_value)}"
      "SECRET_THAT": "${jsonencode(local.secret_that_value)}"
    }
  json_secrets = {
    
  }
}
```

The container will then receive the following environment variables:

```terraform
SECRET_THIS="{\"this_value\":\"something\"}"
SECRET_THAT="{\"that_value\":\"something else\"}"
```

In NodeJS, the code could simply do something like this to retrieve the content of them:

```terraform
let this_value, that_value;
try{
this_value = JSON.parse(process.env['SECRET_THIS']);
that_value = JSON.parse(process.env['SECRET_THAT']);
} catch(e){
...
}
```

#### How to use this component in a blueprint

IMPORTANT: We periodically release versions for the components. Since, master branch may have on-going changes, best practice would be to use a released version in form of a tag (e.g. ?ref=x.y.z)

```terraform
module "service" {
  source = "git::https://<YOUR_VCS_URL>/components/terraform-aws-fargate-service?ref=v6.1.0"

  service_name = "${var.application_name}-${var.service_name}"

  cpu    = var.service_info["cpu_allocation"]
  memory = var.service_info["mem_allocation"]

  service_count = var.service_info["num_containers"]
  service_port  = var.service_info["port"]
  service_image = var.ecr_repository_url
  envvars       = var.service_envvars
  email_ids     = var.monitoring_email_ids

  attach_lb        = var.is_public_service
  alb_path         = var.alb_path
  alb_priority     = var.alb_priority
  alb_listener_arn = var.ecs_cluster["alb_listener_arn"]

  ecs_cluster_name = var.ecs_cluster["cluster_name"]
  vpc_id           = var.ecs_cluster["cluster_vpc_id"]
  subnets          = split(",", var.ecs_cluster["vpc_subnet_ids"])
  security_groups  = split(",", var.ecs_cluster["task_security_group_ids"])

  service_discovery_namespace = var.ecs_cluster["service_discovery_namespace"]

  ecs_task_role_policy_arns_count = var.ecs_task_role_policy_arns_count
  ecs_task_role_policy_arns       = var.ecs_task_role_policy_arns

  health_check = var.health_check

  secret_enabled = var.secret_enabled
  secret_name    = local.secret_name
  secret_value   = var.secret_value

  account_alias      = var.source_name
  log_aggregation_s3 = var.log_aggregation_s3

  attach_apm = var.attach_apm
  apm_config = var.apm_config

  providers {
    aws.service = "aws.source"
    aws.logging = "aws.logging"
  }
}
```

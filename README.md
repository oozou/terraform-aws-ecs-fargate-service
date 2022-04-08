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

## Usage

```terraform
module "fargate_service" {
  source = "git::ssh://git@github.com/oozou/terraform-aws-ecs-fargate-service.git?ref=<version_or_branch>"

  # Generics
  prefix      = "sbth"
  environment = "test"
  name        = "demo"

  # IAM Role
  is_create_iam_role                             = true # Default is `true`
  exists_task_role_arn                           = ""   # Required when is_create_iam_role is `false`
  additional_ecs_task_role_policy_arns           = []   # Default is `[]`, already attaced ["arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"]
  exists_task_execution_role_arn                 = ""   # Required when is_create_iam_role is `false`
  additional_ecs_task_execution_role_policy_arns = []   # Default is `[]`, already attaced ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]

  # ALB
  is_attach_service_with_lb = true # Default is `true`
  ## If is_attach_service_with_lb is set to 'false,' the subsequent parameters are ignored.
  alb_listener_arn = module.ecs_cluster.alb_listener_http_arn
  alb_path         = "/*"
  alb_priority     = "100"
  alb_host_header  = "demo-big.sbth-develop.millenium-m.me"
  custom_header_token = "" # Default is `""`, specific for only allow header with given token ex. "asdskjhekewhdk"
  ## Target group that listener will take action
  vpc_id = module.vpc.vpc_id
  health_check = {
    interval            = 30
    path                = "/health"
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200,201,204"
  }

  # Logging
  is_create_cloudwatch_log_group = true # Default is `true`

  # Task definition
  service_info = {
    containers_num = 2
    cpu_allocation = 256
    mem_allocation = 512
    port           = 8080
    image          = "nginx"
  }
  apm_sidecar_ecr_url = "" # Default is `""`. If specific, the APM is auto enable
  apm_config          = {} # There's default value, ignore if apm_sidecar_ecr_url is `""`

  # Secret
  secrets = {
    "DB_PASSWORD"         = "aa"
    "REDIS_PASSWORD"      = "vv"
    "API_SB_CRM_PASSWORD" = "cc"
    "S3_KMS_KEY_ID"       = "dd"
  }
  json_secrets = {
    "DB_PASSWORD"         = "aa"
    "REDIS_PASSWORD"      = "vv"
    "API_SB_CRM_PASSWORD" = "cc"
    "S3_KMS_KEY_ID"       = "dd"
  }

  # ECS service
  ecs_cluster_name            = module.ecs_cluster.ecs_cluster_name
  service_discovery_namespace = module.ecs_cluster.service_discovery_namespace
  service_count               = 1     # Default is `1`
  is_enable_execute_command   = false # Default is `false`
  application_subnet_ids      = module.vpc.private_subnet_ids
  security_groups = [
    module.ecs_fargate_cluster.ecs_task_security_group_id,
    module.rds_mssql.db_client_security_group_id,
    module.redis.db_client_security_group_id
  ]

  tags = {
    "Workspace" = "custom-workspace"
  }
}
```


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name                                                                      | Version  |
|---------------------------------------------------------------------------|----------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws)                   | >= 4.00  |
| <a name="requirement_random"></a> [random](#requirement\_random)          | >= 2.3.0 |

## Providers

| Name                                                       | Version |
|------------------------------------------------------------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws)          | 4.6.0   |
| <a name="provider_random"></a> [random](#provider\_random) | 3.1.2   |

## Modules

| Name                                                                               | Source                                         | Version |
|------------------------------------------------------------------------------------|------------------------------------------------|---------|
| <a name="module_secret_kms_key"></a> [secret\_kms\_key](#module\_secret\_kms\_key) | git@github.com:oozou/terraform-aws-kms-key.git | v0.0.1  |

## Resources

| Name                                                                                                                                                                | Type        |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------|
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group)                                   | resource    |
| [aws_ecs_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service)                                                     | resource    |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition)                                     | resource    |
| [aws_iam_role.task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                            | resource    |
| [aws_iam_role.task_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                                      | resource    |
| [aws_iam_role_policy.task_execution_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy)                           | resource    |
| [aws_iam_role_policy_attachment.task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment)        | resource    |
| [aws_iam_role_policy_attachment.task_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment)                  | resource    |
| [aws_lb_listener_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule)                                           | resource    |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group)                                             | resource    |
| [aws_secretsmanager_secret.service_json_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret)                 | resource    |
| [aws_secretsmanager_secret.service_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret)                      | resource    |
| [aws_secretsmanager_secret_version.service_json_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource    |
| [aws_secretsmanager_secret_version.service_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version)      | resource    |
| [aws_service_discovery_service.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service)                      | resource    |
| [random_string.service_secret_random_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string)                                 | resource    |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity)                                       | data source |
| [aws_iam_policy_document.task_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)               | data source |
| [aws_iam_policy_document.task_execution_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)     | data source |
| [aws_iam_role.get_ecs_task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role)                                 | data source |
| [aws_iam_role.get_ecs_task_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role)                                           | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region)                                                         | data source |

## Inputs

| Name                                                                                                                                                                                     | Description                                                                                                                          | Type                                                                                                                                                                                   | Default                                                                                 | Required |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------|:--------:|
| <a name="input_additional_ecs_task_execution_role_policy_arns"></a> [additional\_ecs\_task\_execution\_role\_policy\_arns](#input\_additional\_ecs\_task\_execution\_role\_policy\_arns) | List of policies ARNs to attach to the ECS Task Role. eg: { rds\_arn = module.postgres\_db.rds\_policy\_arn }                        | `list(string)`                                                                                                                                                                         | `[]`                                                                                    |    no    |
| <a name="input_additional_ecs_task_role_policy_arns"></a> [additional\_ecs\_task\_role\_policy\_arns](#input\_additional\_ecs\_task\_role\_policy\_arns)                                 | List of policies ARNs to attach to the ECS Task Role. eg: { rds\_arn = module.postgres\_db.rds\_policy\_arn }                        | `list(string)`                                                                                                                                                                         | `[]`                                                                                    |    no    |
| <a name="input_alb_host_header"></a> [alb\_host\_header](#input\_alb\_host\_header)                                                                                                      | Mention host header for api endpoint                                                                                                 | `string`                                                                                                                                                                               | `null`                                                                                  |    no    |
| <a name="input_alb_listener_arn"></a> [alb\_listener\_arn](#input\_alb\_listener\_arn)                                                                                                   | The ALB listener to attach to                                                                                                        | `string`                                                                                                                                                                               | `""`                                                                                    |    no    |
| <a name="input_alb_path"></a> [alb\_path](#input\_alb\_path)                                                                                                                             | Mention Path For ALB routing eg: / or /route1                                                                                        | `string`                                                                                                                                                                               | `""`                                                                                    |    no    |
| <a name="input_alb_priority"></a> [alb\_priority](#input\_alb\_priority)                                                                                                                 | Priority of ALB rule https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html#listener-rules | `string`                                                                                                                                                                               | `"100"`                                                                                 |    no    |
| <a name="input_apm_config"></a> [apm\_config](#input\_apm\_config)                                                                                                                       | Config for X-Ray sidecar container for APM and traceability                                                                          | <pre>object({<br>    service_port = number<br>    cpu          = number<br>    memory       = number<br>  })</pre>                                                                     | <pre>{<br>  "cpu": 256,<br>  "memory": 512,<br>  "service_port": 9000<br>}</pre>        |    no    |
| <a name="input_apm_sidecar_ecr_url"></a> [apm\_sidecar\_ecr\_url](#input\_apm\_sidecar\_ecr\_url)                                                                                        | [Optional] To enable APM, set Sidecar ECR URL                                                                                        | `string`                                                                                                                                                                               | `""`                                                                                    |    no    |
| <a name="input_application_subnet_ids"></a> [application\_subnet\_ids](#input\_application\_subnet\_ids)                                                                                 | Subnet IDs to deploy into                                                                                                            | `list(string)`                                                                                                                                                                         | n/a                                                                                     |   yes    |
| <a name="input_custom_header_token"></a> [custom\_header\_token](#input\_custom\_header\_token)                                                                                          | [Required] Specify secret value for custom header                                                                                    | `string`                                                                                                                                                                               | `""`                                                                                    |    no    |
| <a name="input_ecs_cluster_name"></a> [ecs\_cluster\_name](#input\_ecs\_cluster\_name)                                                                                                   | ECS Cluster name to deploy in                                                                                                        | `string`                                                                                                                                                                               | n/a                                                                                     |   yes    |
| <a name="input_environment"></a> [environment](#input\_environment)                                                                                                                      | Environment Variable used as a prefix                                                                                                | `string`                                                                                                                                                                               | n/a                                                                                     |   yes    |
| <a name="input_envvars"></a> [envvars](#input\_envvars)                                                                                                                                  | List of [{name = "", value = ""}] pairs of environment variables                                                                     | <pre>set(object({<br>    name  = string<br>    value = string<br>  }))</pre>                                                                                                           | <pre>[<br>  {<br>    "name": "EXAMPLE_ENV",<br>    "value": "example"<br>  }<br>]</pre> |    no    |
| <a name="input_exists_task_execution_role_arn"></a> [exists\_task\_execution\_role\_arn](#input\_exists\_task\_execution\_role\_arn)                                                     | The existing arn of task exec role                                                                                                   | `string`                                                                                                                                                                               | `null`                                                                                  |    no    |
| <a name="input_exists_task_role_arn"></a> [exists\_task\_role\_arn](#input\_exists\_task\_role\_arn)                                                                                     | The existing arn of task role                                                                                                        | `string`                                                                                                                                                                               | `""`                                                                                    |    no    |
| <a name="input_health_check"></a> [health\_check](#input\_health\_check)                                                                                                                 | Health Check Config for the service                                                                                                  | `map(string)`                                                                                                                                                                          | `{}`                                                                                    |    no    |
| <a name="input_is_attach_service_with_lb"></a> [is\_attach\_service\_with\_lb](#input\_is\_attach\_service\_with\_lb)                                                                    | Attach the container to the public ALB? (true/false)                                                                                 | `bool`                                                                                                                                                                                 | n/a                                                                                     |   yes    |
| <a name="input_is_create_cloudwatch_log_group"></a> [is\_create\_cloudwatch\_log\_group](#input\_is\_create\_cloudwatch\_log\_group)                                                     | Whether to create cloudwatch log group or not                                                                                        | `bool`                                                                                                                                                                                 | `true`                                                                                  |    no    |
| <a name="input_is_create_iam_role"></a> [is\_create\_iam\_role](#input\_is\_create\_iam\_role)                                                                                           | Create the built in IAM role for task role and task exec role                                                                        | `bool`                                                                                                                                                                                 | `true`                                                                                  |    no    |
| <a name="input_is_enable_execute_command"></a> [is\_enable\_execute\_command](#input\_is\_enable\_execute\_command)                                                                      | Specifies whether to enable Amazon ECS Exec for the tasks within the service.                                                        | `bool`                                                                                                                                                                                 | `false`                                                                                 |    no    |
| <a name="input_json_secrets"></a> [json\_secrets](#input\_json\_secrets)                                                                                                                 | Map of secret name(as reflected in Secrets Manager) and secret JSON string associated                                                | `map(string)`                                                                                                                                                                          | `{}`                                                                                    |    no    |
| <a name="input_name"></a> [name](#input\_name)                                                                                                                                           | Name of the ECS cluster to create                                                                                                    | `string`                                                                                                                                                                               | n/a                                                                                     |   yes    |
| <a name="input_prefix"></a> [prefix](#input\_prefix)                                                                                                                                     | The prefix name of customer to be displayed in AWS console and resource                                                              | `string`                                                                                                                                                                               | n/a                                                                                     |   yes    |
| <a name="input_secrets"></a> [secrets](#input\_secrets)                                                                                                                                  | Map of secret name(as reflected in Secrets Manager) and secret JSON string associated                                                | `map(string)`                                                                                                                                                                          | `{}`                                                                                    |    no    |
| <a name="input_security_groups"></a> [security\_groups](#input\_security\_groups)                                                                                                        | Security groups to apply to service                                                                                                  | `list(string)`                                                                                                                                                                         | n/a                                                                                     |   yes    |
| <a name="input_service_count"></a> [service\_count](#input\_service\_count)                                                                                                              | Number of containers to deploy                                                                                                       | `number`                                                                                                                                                                               | `1`                                                                                     |    no    |
| <a name="input_service_discovery_namespace"></a> [service\_discovery\_namespace](#input\_service\_discovery\_namespace)                                                                  | DNS Namespace to deploy to                                                                                                           | `string`                                                                                                                                                                               | n/a                                                                                     |   yes    |
| <a name="input_service_info"></a> [service\_info](#input\_service\_info)                                                                                                                 | The configuration of service                                                                                                         | <pre>object({<br>    cpu_allocation = number<br>    mem_allocation = number<br>    containers_num = number<br>    port           = number<br>    image          = string<br>  })</pre> | n/a                                                                                     |   yes    |
| <a name="input_tags"></a> [tags](#input\_tags)                                                                                                                                           | Custom tags which can be passed on to the AWS resources. They should be key value pairs having distinct keys                         | `map(any)`                                                                                                                                                                             | `{}`                                                                                    |    no    |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id)                                                                                                                                   | VPC id where security group is created                                                                                               | `string`                                                                                                                                                                               | `""`                                                                                    |    no    |

## Outputs

| Name                                                                                                            | Description                                     |
|-----------------------------------------------------------------------------------------------------------------|-------------------------------------------------|
| <a name="output_secret_arns"></a> [secret\_arns](#output\_secret\_arns)                                         | List of ARNs of the SecretsManager secrets      |
| <a name="output_secret_json_arn"></a> [secret\_json\_arn](#output\_secret\_json\_arn)                           | List of ARNs of the SecretsManager json secrets |
| <a name="output_task_execution_role_arn"></a> [task\_execution\_role\_arn](#output\_task\_execution\_role\_arn) | ECS Task execution role ARN                     |
| <a name="output_task_execution_role_id"></a> [task\_execution\_role\_id](#output\_task\_execution\_role\_id)    | ECS Task execution role ID                      |
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn)                                 | ECS Task role ARN                               |
| <a name="output_task_role_id"></a> [task\_role\_id](#output\_task\_role\_id)                                    | ECS Task role ID                                |
<!-- END_TF_DOCS -->

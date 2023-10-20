<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0.0, < 5.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 2.3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 4.67.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_api_service"></a> [api\_service](#module\_api\_service) | ../.. | n/a |
| <a name="module_fargate_cluster"></a> [fargate\_cluster](#module\_fargate\_cluster) | oozou/ecs-fargate-cluster/aws | 1.0.7 |
| <a name="module_payment_service"></a> [payment\_service](#module\_payment\_service) | ../.. | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | oozou/vpc/aws | 1.2.4 |

## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_custom_tags"></a> [custom\_tags](#input\_custom\_tags) | Custom tags which can be passed on to the AWS resources. They should be key value pairs having distinct keys. | `map(string)` | `{}` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | [Required] Name prefix used for resource naming in this component | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | [Required] Name of Platfrom or application | `string` | n/a | yes |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | [Required] Name prefix used for resource naming in this component | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->

# Change Log

## [v1.1.11] - 2022-12-22

### Added

- Add outputs `target_group_arn` and `target_group_id`

## [v1.1.10] - 2022-12-13

### Added

- Support naming override with `var.name_override`; raise exception if naming override or formatted name is not given
    - `local.empty_prefix`
    - `local.empty_environment`
    - `local.empty_name`
    - `local.raise_empty_name`
- Add new variables `var.name_override`
- Add support step scaling alarm in module `step_alarm`
    - `concat([aws_appautoscaling_policy.step_scaling_policies[each.key].arn], lookup(each.value, "alarm_actions", lookup(var.scaling_configuration, "default_alarm_actions", [])))`

### Changed

- Update data sources 
    - `data.aws_caller_identity.current` to `data.aws_caller_identity.this`
    - `data.aws_region.current` to `data.aws_region.this`
- Rename variables in local {...}
    - `local.service_name` to `local.name`
- Update how to struct task definition 
    - Remove `local.container_definitions`
    - Update `local.container_definitions_ec2`
    - Add `local.pre_container_definitions_template`, `local.apm_template`, `local.ec2_template`, `local.ec2_template` and `local.render_container_definitions`
- Update variables description and default value for `var.prefix`, `var.environment` and `var.name`
- Rename variables
    - `var.secrets` to `var.secret_variables`
    - `var.json_secrets` to `var.json_secret_variables`
    - `var.envvars` to `var.environment_variables` *data structure is changed*
- Update resource `aws_lb_listener_rule.this`'s argument
    - `name` from `format("%s-service-secrets", local.service_name)` to `format("%s-ecs", var.name)`
    - `tags` from `merge(local.tags, { "Name" : format("%s-service-secrets", local.service_name) })` to `merge(local.tags, { "Name" : format("%s-ecs", local.name) })`
- Update resource `aws_appautoscaling_policy.target_tracking_scaling_policies`'s argument
    - `name` from `format("%s-%s-scaling-policy", local.service_name, each.key)` to `format("%s-%s-scaling-policy", local.name, replace(each.key, "_", "-"))`
- Update resource `aws_appautoscaling_policy.step_scaling_policies`'s argument
    - `name` from `format("%s-%s-scaling-policy", local.service_name, each.key)` to `format("%s-%s-scaling-policy", local.name, replace(each.key, "_", "-"))`
- Update module `module.step_alarm`'s argument
    - `name` from `format("%s-%s-alarm", local.service_name, each.key)` to `replace(each.key, "_", "-")`
    - `statistic` from `lookup(each.value, "statistic", "Average")` to `lookup(each.value, "statistic", null)`
- Update parameter in file `task-definitions/*.json` to match with others

### Removed

- Remove role validator (Let's AWS API handle this)
    - `data.aws_iam_role.get_ecs_task_role`
    - `data.aws_iam_role.get_ecs_task_execution_role`

## [v1.1.9] - 2022-11-23

### Changed

- Update meta-argument to count on resource `aws_iam_role_policy_attachment.task_role`
- Update resource `aws_lb_target_group.this` to auto substr if service name is longer than 29

### Removed

- Remove local `service_name_tmp`
- Remove local `ecs_task_role_policy_arns` (change to count)

## [v1.1.8] - 2022-11-17

### Changed

- Update `.pre-commit-config.yaml`
- Migrate resource `aws_appautoscaling_policy.step_scaling_policies.step_adjustment` to dynamic `step_adjustment` block
- Update resource `aws_cloudwatch_metric_alarm.step_alarm` to be module `step_alarm` (v1.0.0)

### Removed

- Remove `local.ecs_default_task_role_policy_arns`

## [v1.1.7] - 2022-10-10

### Added

- Add variable `var.is_application_scratch_volume_enabled` to support enabled temporary storage on ecs

### Changed

- On variable `var.service_info` to support additional mount point

## [v1.1.6] - 2022-09-22

### Added

- Add variable `var.target_group_deregistration_delay` to support setting deregistration delay time

### Changed

- Update resource `aws_lb_target_group.this` to support setting deregistration delay time with attribute `deregistration_delay`
- Update file `.pre-commit-config.yaml`

## [v1.1.5] - 2022-09-21

### Changed

- Change `KMS` to use from public module
- CHange ALB to auto strip name when name is too longer than 32 chars

## [v1.1.4] - 2022-09-05

### Changed

- Update `.pre-commit-config.yaml` to support `--args=--only=terraform_unused_declarations`
- Update `CHANGELOG.md` to all previous version
- Fix pre-commit issue

### Removed

- Remove `containers_num` attribute from variable `var.service_info`
- Add description for variables `var.ordered_placement_strategy`

## [v1.1.3] - 2022-08-03

### Added

- Add file `.github/ISSUE_TEMPLATE/bug_report.md`
- Add file `.github/ISSUE_TEMPLATE/feature_request.md`
- Add file `.github/PULL_REQUEST_TEMPLATE.md`
- Add file `CONTRIBUTING.md`
- Add file `CHANGELOG.md`
- Add file `LICENSE`
- Add file `SECURITY.md`
- Add file `task-definitions/service-main-container-ec2.json`
- Add example under `examples/*` dir
- Add local `local.volumes` support mount with efs
- Add local `local.raise_enable_exec_on_cp` to raise exception when integrating with EC2 launch type
- Add support for `entry_point`, `command` and EC2 launch type for task definition
- Add attribute for resource `aws_ecs_service.this`
    - `enable_ecs_managed_tags` is `true`
    -  Dynamic `ordered_placement_strategy`
    -  Dynamic `capacity_provider_strategy`
    -  `deployment_circuit_breaker` block
- Add variable `var.capacity_provider_strategy`
- Add variable `var.ordered_placement_strategy`
- Add variable `var.unix_max_connection`
- Add variable `var.entry_point`
- Add variable `var.command`
- Add variable `var.efs_volumes`
- Add variable `var.deployment_circuit_breaker`

### Changed

- Update file `.gitignore` to ignore file with regex `terraform.*example*.tfvars`
- Update file `task-definitions/service-main-container.json` and `task-definitions/service-with-sidecar-container.json` to support entry point, command  
- Update `.pre-commit-config.yaml` to un-support `--args=--only=terraform_unused_declarations`
- Upgrade KMS version from `v0.0.1` to `v1.0.0`
- Update `aws_ecs_task_definition.this` to support EC2 compatibilities
- Update variables `var.envvars` not to create unneeded secret

### Removed

- Remove content in `README.md`
- Remove file `archive README.md`

## [v1.1.2] - 2022-06-30

### Added

- Add variable `var.cloudwatch_log_retention_in_days`
- Add variable `var.cloudwatch_log_kms_key_id`

### Changed

- Fix KMS issue

## [v1.1.1] - 2022-06-02

### Added

- Added file `.github/workflows/code-scan.yml`

### Changed

- Update tagging on resource `aws_cloudwatch_metric_alarm.step_alarm`

## [v1.1.0] - 2022-05-30

### Added

- Add local `local.comparison_operators` to make it easier for future use
- Add resource `aws_appautoscaling_target.this`
- Add resource `aws_appautoscaling_policy.target_tracking_scaling_policies`
- Add resource `aws_appautoscaling_policy.step_scaling_policies`
- Add resource `aws_cloudwatch_metric_alarm.step_alarm`
- Add variable `scaling_configuration` to configure the scaling behavior

### Changed

- Update `.pre-commit-config.yaml` to support `--args=--only=terraform_unused_declarations`

## [v1.0.1] - 2022-05-04

### Changed

- Update variable's name `var.alb_path` to `var.alb_paths`
- Update resource `aws_lb_listener_rule.this` to support multiple paths

### Removed

- Remove `local.raise_alb_host_header_empty` for support empty host header

## [v1.0.0] - 2022-05-04

### Changed

- Restructure of ECS module

## [v0.0.1]

### Added

- init terraform-aws-ecs-fargate-service

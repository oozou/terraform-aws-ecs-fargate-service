# Terraform AWS ECS Fargate Service Tests

This directory contains automated tests for the Terraform AWS ECS Fargate Service module using [Terratest](https://terratest.gruntwork.io/).

## Test Coverage

The test suite validates the following components:

### 1. ECS Service Creation
- Verifies that the ECS service is created successfully
- Validates service name and ARN
- Confirms service status is ACTIVE
- Checks service uses Fargate launch type
- Validates desired count is greater than 0

### 2. ECS Service Attachment to ALB
- Verifies that the ECS service is properly attached to the Application Load Balancer
- Validates target group creation and configuration
- Confirms target group is attached to the correct ALB
- Checks load balancer configuration in ECS service
- Validates container name and port mapping

### 3. ECS Task Creation and Execution
- Verifies that ECS tasks are created and running
- Validates task definition ARN matches expected value
- Confirms tasks use Fargate launch type
- Checks container status within tasks
- Waits for tasks to reach RUNNING state with timeout

### 4. Application Accessibility via ALB
- Verifies that the application is accessible through the ALB DNS name
- Tests HTTP connectivity to the application
- Validates successful HTTP response (2xx or 3xx status codes)
- Checks response headers for proper server configuration
- Implements retry logic with timeout for application startup

## Prerequisites

Before running the tests, ensure you have:

1. **Go installed** (version 1.21 or later)
2. **AWS credentials configured** with appropriate permissions
3. **Terraform installed** (version compatible with the module)

### Required AWS Permissions

The test user/role needs permissions for:
- ECS (DescribeClusters, DescribeServices, ListTasks, DescribeTasks)
- ELBv2 (DescribeLoadBalancers, DescribeTargetGroups, DescribeListeners)
- EC2 (for VPC and security group operations)
- IAM (for role operations)
- CloudWatch Logs (for log group operations)
- SecretsManager (for secret operations)

## Running the Tests

### Using Make (Recommended)

```bash
# Run all tests
make test

# Run tests with coverage report
make test-coverage

# Run tests with HTML report generation
make test-report

# Install dependencies
make deps

# Clean up generated files
make clean

# Run all checks (format, vet, test)
make check
```

### Using Go directly

```bash
# Install dependencies
go mod download

# Run tests
go test -v -timeout 30m

# Run tests with report generation
go test -v -timeout 30m -report -report-file=test-report.json -html-file=test-report.html
```

## Test Configuration

The tests use the following configuration:

- **AWS Region**: `ap-southeast-1`
- **Test Domain**: `test.example.com`
- **Hosted Zone**: `example.com`
- **VPC CIDR**: `10.0.0.0/16`
- **Public Subnets**: `10.0.1.0/24`, `10.0.2.0/24`
- **Private Subnets**: `10.0.3.0/24`, `10.0.4.0/24`

## Test Reports

The tests generate comprehensive reports:

- **JSON Report**: `test-report.json` - Machine-readable test results
- **HTML Report**: `test-report.html` - Human-readable test results with styling
- **Coverage Report**: `coverage.html` - Code coverage analysis (when using `make test-coverage`)

## Test Structure

```
tests/
├── terraform_test.go    # Main test file with all test cases
├── go.mod              # Go module dependencies
├── Makefile           # Build and test automation
└── README.md          # This file
```

## Troubleshooting

### Common Issues

1. **Timeout Errors**: Tests have a 30-minute timeout. If tests are timing out, check AWS resource creation times.

2. **Permission Errors**: Ensure your AWS credentials have all required permissions listed above.

3. **DNS Test Skipping**: The DNS record test will skip if the `example.com` hosted zone doesn't exist. This is expected in test environments.

4. **Certificate Validation**: ACM certificates may be in `PENDING_VALIDATION` state during tests, which is acceptable.

### Debug Mode

To run tests with more verbose output:

```bash
go test -v -timeout 30m -args -test.v
```

## Cleanup

Tests automatically clean up resources using Terraform destroy in a defer block. If tests are interrupted, you may need to manually clean up AWS resources.

To clean up test artifacts:

```bash
make clean
```

## Contributing

When adding new tests:

1. Follow the existing test pattern
2. Add appropriate AWS SDK clients and permissions
3. Include proper error handling and assertions
4. Update this README with new test coverage
5. Ensure tests clean up resources properly

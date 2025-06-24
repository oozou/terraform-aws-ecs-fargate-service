package test

import (
	"context"
	"flag"
	"fmt"
	"net/http"
	"os"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ecs"
	"github.com/aws/aws-sdk-go-v2/service/ecs/types"
	"github.com/aws/aws-sdk-go-v2/service/elasticloadbalancingv2"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/oozou/terraform-test-util"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Global variables for test reporting
var (
	generateReport bool
	reportFile     string
	htmlFile       string
)

// TestMain enables custom test runner with reporting
func TestMain(m *testing.M) {
	flag.BoolVar(&generateReport, "report", false, "Generate test report")
	flag.StringVar(&reportFile, "report-file", "test-report.json", "Test report JSON file")
	flag.StringVar(&htmlFile, "html-file", "test-report.html", "Test report HTML file")
	flag.Parse()

	exitCode := m.Run()
	os.Exit(exitCode)
}

func TestTerraformAWSECSFargateClusterModule(t *testing.T) {
	t.Parallel()

	// Record test start time
	startTime := time.Now()
	var testResults []testutil.TestResult

	// Pick a random AWS region to test in
	awsRegion := "ap-southeast-1"

	// Construct the terraform options with default retryable errors to handle the most common
	// retryable errors in terraform testing.
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: "../examples/terraform-test",

		// Environment variables to set when running Terraform
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	})

	// At the end of the test, run `terraform destroy` to clean up any resources that were created
	defer func() {
		terraform.Destroy(t, terraformOptions)
	}()

	// This will run `terraform init` and `terraform apply` and fail the test if there are any errors
	terraform.InitAndApply(t, terraformOptions)

	// Define test cases with their functions
	testCases := []struct {
		name string
		fn   func(*testing.T, *terraform.Options, string)
	}{
		{"TestECSServiceCreated", testECSServiceCreated},
		{"TestECSServiceAttachedToALB", testECSServiceAttachedToALB},
		{"TestECSTaskCreated", testECSTaskCreated},
		{"TestAppAccessibleFromALB", testAppAccessibleFromALB},
	}

	// Run all test cases and collect results
	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			testStart := time.Now()

			// Capture test result
			defer func() {
				testEnd := time.Now()
				duration := testEnd.Sub(testStart)

				result := testutil.TestResult{
					Name:     tc.name,
					Duration: duration.String(),
				}

				if r := recover(); r != nil {
					result.Status = "FAIL"
					result.Error = fmt.Sprintf("Panic: %v", r)
				} else if t.Failed() {
					result.Status = "FAIL"
					result.Error = "Test assertions failed"
				} else if t.Skipped() {
					result.Status = "SKIP"
				} else {
					result.Status = "PASS"
				}

				testResults = append(testResults, result)
			}()

			// Run the actual test
			tc.fn(t, terraformOptions, awsRegion)
		})
	}

	// Generate and display test report
	endTime := time.Now()
	report := testutil.GenerateTestReport(testResults, startTime, endTime)
	report.TestSuite = "Terraform AWS ECS Fargate Service Tests"
	report.PrintReport()

	// Save reports to files
	if err := report.SaveReportToFile("test-report.json"); err != nil {
		t.Errorf("failed to save report to file: %v", err)
	}

	if err := report.SaveReportToHTML("test-report.html"); err != nil {
		t.Errorf("failed to save report to HTML: %v", err)
	}
}

// Helper function to create AWS config
func createAWSConfig(t *testing.T, region string) aws.Config {
	cfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithRegion(region),
	)
	require.NoError(t, err, "Failed to create AWS config")
	return cfg
}

// Test that ECS service is created successfully
func testECSServiceCreated(t *testing.T, terraformOptions *terraform.Options, region string) {
	// Get terraform outputs
	clusterName := terraform.Output(t, terraformOptions, "ecs_cluster_name")
	serviceName := terraform.Output(t, terraformOptions, "service_name")
	serviceArn := terraform.Output(t, terraformOptions, "service_arn")

	// Verify outputs are not empty
	assert.NotEmpty(t, clusterName, "ECS cluster name should not be empty")
	assert.NotEmpty(t, serviceName, "ECS service name should not be empty")
	assert.NotEmpty(t, serviceArn, "ECS service ARN should not be empty")

	// Create AWS config and ECS client
	cfg := createAWSConfig(t, region)
	ecsClient := ecs.NewFromConfig(cfg)

	// Describe the ECS service
	describeInput := &ecs.DescribeServicesInput{
		Cluster:  aws.String(clusterName),
		Services: []string{serviceName},
	}

	result, err := ecsClient.DescribeServices(context.TODO(), describeInput)
	require.NoError(t, err, "Failed to describe ECS service")
	require.Len(t, result.Services, 1, "Expected exactly one service")

	service := result.Services[0]
	
	// Verify service properties
	assert.Equal(t, serviceName, *service.ServiceName, "Service name should match")
	assert.Equal(t, serviceArn, *service.ServiceArn, "Service ARN should match")
	assert.Equal(t, "ACTIVE", *service.Status, "Service should be active")
	assert.Equal(t, types.LaunchTypeFargate, service.LaunchType, "Service should use Fargate launch type")
	assert.Greater(t, service.DesiredCount, int32(0), "Service should have desired count > 0")
	
	t.Logf("✅ ECS Service verified: %s (Status: %s, Desired: %d, Running: %d)", 
		*service.ServiceName, *service.Status, service.DesiredCount, service.RunningCount)
}

// Test that ECS service is attached to ALB
func testECSServiceAttachedToALB(t *testing.T, terraformOptions *terraform.Options, region string) {
	// Get terraform outputs
	clusterName := terraform.Output(t, terraformOptions, "ecs_cluster_name")
	serviceName := terraform.Output(t, terraformOptions, "service_name")
	targetGroupArn := terraform.Output(t, terraformOptions, "target_group_arn")
	albArn := terraform.Output(t, terraformOptions, "alb_arn")

	// Verify outputs are not empty
	assert.NotEmpty(t, targetGroupArn, "Target group ARN should not be empty")
	assert.NotEmpty(t, albArn, "ALB ARN should not be empty")

	// Create AWS config and clients
	cfg := createAWSConfig(t, region)
	ecsClient := ecs.NewFromConfig(cfg)
	elbClient := elasticloadbalancingv2.NewFromConfig(cfg)

	// Verify ECS service has load balancer configuration
	describeInput := &ecs.DescribeServicesInput{
		Cluster:  aws.String(clusterName),
		Services: []string{serviceName},
	}

	result, err := ecsClient.DescribeServices(context.TODO(), describeInput)
	require.NoError(t, err, "Failed to describe ECS service")
	require.Len(t, result.Services, 1, "Expected exactly one service")

	service := result.Services[0]
	require.NotEmpty(t, service.LoadBalancers, "Service should have load balancer configuration")

	// Verify load balancer configuration
	loadBalancer := service.LoadBalancers[0]
	assert.Equal(t, targetGroupArn, *loadBalancer.TargetGroupArn, "Target group ARN should match")
	assert.NotEmpty(t, *loadBalancer.ContainerName, "Container name should be specified")
	assert.Greater(t, *loadBalancer.ContainerPort, int32(0), "Container port should be > 0")

	// Verify target group exists and is attached to ALB
	describeTargetGroupsInput := &elasticloadbalancingv2.DescribeTargetGroupsInput{
		TargetGroupArns: []string{targetGroupArn},
	}

	tgResult, err := elbClient.DescribeTargetGroups(context.TODO(), describeTargetGroupsInput)
	require.NoError(t, err, "Failed to describe target groups")
	require.Len(t, tgResult.TargetGroups, 1, "Expected exactly one target group")

	targetGroup := tgResult.TargetGroups[0]
	assert.NotEmpty(t, targetGroup.LoadBalancerArns, "Target group should be attached to load balancer")
	
	// Verify the target group is attached to the correct ALB
	found := false
	for _, lbArn := range targetGroup.LoadBalancerArns {
		if lbArn == albArn {
			found = true
			break
		}
	}
	assert.True(t, found, "Target group should be attached to the specified ALB")

	t.Logf("✅ ECS Service ALB attachment verified: Service %s attached to Target Group %s", 
		serviceName, *targetGroup.TargetGroupName)
}

// Test that ECS tasks are created and running
func testECSTaskCreated(t *testing.T, terraformOptions *terraform.Options, region string) {
	// Get terraform outputs
	clusterName := terraform.Output(t, terraformOptions, "ecs_cluster_name")
	serviceName := terraform.Output(t, terraformOptions, "service_name")
	taskDefinitionArn := terraform.Output(t, terraformOptions, "task_definition_arn")

	// Verify outputs are not empty
	assert.NotEmpty(t, taskDefinitionArn, "Task definition ARN should not be empty")

	// Create AWS config and ECS client
	cfg := createAWSConfig(t, region)
	ecsClient := ecs.NewFromConfig(cfg)

	// Wait for tasks to be running (with timeout)
	maxRetries := 30
	retryInterval := 10 * time.Second
	
	for i := 0; i < maxRetries; i++ {
		// List tasks for the service
		listTasksInput := &ecs.ListTasksInput{
			Cluster:     aws.String(clusterName),
			ServiceName: aws.String(serviceName),
		}

		listResult, err := ecsClient.ListTasks(context.TODO(), listTasksInput)
		require.NoError(t, err, "Failed to list tasks")

		if len(listResult.TaskArns) > 0 {
			// Describe the tasks
			describeTasksInput := &ecs.DescribeTasksInput{
				Cluster: aws.String(clusterName),
				Tasks:   listResult.TaskArns,
			}

			describeResult, err := ecsClient.DescribeTasks(context.TODO(), describeTasksInput)
			require.NoError(t, err, "Failed to describe tasks")

			runningTasks := 0
			for _, task := range describeResult.Tasks {
				if task.LastStatus != nil && *task.LastStatus == "RUNNING" {
					runningTasks++
					
					// Verify task properties
					assert.Equal(t, types.LaunchTypeFargate, task.LaunchType, "Task should use Fargate launch type")
					assert.NotEmpty(t, task.TaskDefinitionArn, "Task should have task definition ARN")
					assert.Contains(t, *task.TaskDefinitionArn, taskDefinitionArn, "Task should use the correct task definition")
					assert.NotEmpty(t, task.Containers, "Task should have containers")
					
					// Verify container status
					for _, container := range task.Containers {
						if container.LastStatus != nil {
							t.Logf("Container %s status: %s", *container.Name, *container.LastStatus)
						}
					}
				}
			}

			if runningTasks > 0 {
				t.Logf("✅ ECS Tasks verified: %d running tasks found", runningTasks)
				return
			}
		}

		if i < maxRetries-1 {
			t.Logf("Waiting for tasks to be running... (attempt %d/%d)", i+1, maxRetries)
			time.Sleep(retryInterval)
		}
	}

	t.Fatalf("No running tasks found after %d attempts", maxRetries)
}

// Test that the application is accessible from ALB DNS
func testAppAccessibleFromALB(t *testing.T, terraformOptions *terraform.Options, region string) {
	// Get terraform outputs
	albDnsName := terraform.Output(t, terraformOptions, "alb_dns_name")
	
	// Verify output is not empty
	assert.NotEmpty(t, albDnsName, "ALB DNS name should not be empty")

	// Construct the URL
	url := fmt.Sprintf("http://%s", "terraform-test.devops.team.oozou.com")
	
	// Wait for the application to be accessible (with timeout)
	maxRetries := 30
	retryInterval := 10 * time.Second
	
	client := &http.Client{
		Timeout: 30 * time.Second,
	}

	for i := 0; i < maxRetries; i++ {
		resp, err := client.Get(url)
		if err == nil {
			defer func() {
				_ = resp.Body.Close()
			}()
			
			// Check if we get a successful response (2xx or 3xx)
			if resp.StatusCode >= 200 && resp.StatusCode < 400 {
				t.Logf("✅ Application accessible via ALB: %s (Status: %d %s)", 
					url, resp.StatusCode, resp.Status)
				
				// Additional checks
				assert.NotEmpty(t, resp.Header.Get("Server"), "Response should have Server header")
				return
			}
			
			t.Logf("Received HTTP %d from %s, retrying...", resp.StatusCode, url)
		} else {
			t.Logf("Failed to connect to %s: %v, retrying...", url, err)
		}

		if i < maxRetries-1 {
			time.Sleep(retryInterval)
		}
	}

	t.Fatalf("Application not accessible via ALB after %d attempts. URL: %s", maxRetries, url)
}

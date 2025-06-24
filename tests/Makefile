.PHONY: test clean deps

# Default target
test: deps
	go test -v -timeout 30m

# Run tests with coverage
test-coverage: deps
	go test -v -timeout 30m -coverprofile=coverage.out
	go tool cover -html=coverage.out -o coverage.html

# Run tests with report generation
test-report: deps
	go test -v -timeout 30m -report -report-file=test-report.json -html-file=test-report.html

# Install dependencies
deps:
	go mod download
	go mod tidy

# Clean up generated files
clean:
	rm -f test-report.json
	rm -f test-report.html
	rm -f coverage.out
	rm -f coverage.html

# Format Go code
fmt:
	go fmt ./...

# Run Go vet
vet: deps
	go vet ./...

# Run all checks
check: fmt vet test

# Help target
help:
	@echo "Available targets:"
	@echo "  test         - Run tests"
	@echo "  test-coverage - Run tests with coverage report"
	@echo "  test-report  - Run tests with HTML report generation"
	@echo "  deps         - Install dependencies"
	@echo "  clean        - Clean up generated files"
	@echo "  fmt          - Format Go code"
	@echo "  vet          - Run Go vet"
	@echo "  check        - Run fmt, vet, and test"
	@echo "  help         - Show this help message"

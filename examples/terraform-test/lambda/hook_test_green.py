import urllib3
import os

http = urllib3.PoolManager()

def lambda_handler(event, context):
    """
    Tests blue/green deployment.
    """
    try:
        alb_dns_name = os.environ.get('ALB_DNS_NAME')
        response = http.request(
            "GET",
            f"https://{alb_dns_name}/",
            headers={"x-amzn-ecs-bluegreen-test": "test-green"},
            timeout=urllib3.Timeout(connect=2.0, read=5.0)
        )
        print(response.status)
        
        if response.status == 200:
            print("SUCCEEDED")
            return {"hookStatus": "SUCCEEDED"}
        else:
            return {"hookStatus": "IN_PROGRESS"}
            print("IN_PROGRESS")
    except Exception as e:
        print(f"Error: {str(e)}")
        return {"hookStatus": "FAILED"}

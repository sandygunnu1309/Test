# List the files in S3 bucket
import boto3

def list_files_in_bucket(bucketName):
    # Create an S3 client
    s3 = boto3.client('s3')

    # List objects in the bucket
    response = s3.list_objects_v2(Bucket=bucketName)

    # Print the names of the files in the bucket
    if 'Contents' in response:
        print("Files in bucket '{}':".format(bucketName))
        for obj in response['Contents']:
            print(obj['Key'])
    else:
        print("No files found in bucket '{}'.".format(bucketName))

if __name__ == "__main__":
    # Replace 'your-bucket-name' with the name of your S3 bucket
    bucketName = 'your-bucket-name'
    
    list_files_in_bucket(bucketName)
	
----------------------------------------------------------
#One command lists the versions of the ECS task definition for the service created

import boto3

def list_task_definition_versions(cluster_name, service_name):
    # Create an ECS client
    ecs_client = boto3.client('ecs')

    # Describe the service to get the task definition family and revision
    response = ecs_client.describe_services(
        cluster=cluster_name,
        services=[service_name]
    )

    if 'services' not in response or not response['services']:
        print(f"No service found with the name '{service_name}' in the cluster '{cluster_name}'.")
        return

    task_definition_arn = response['services'][0]['taskDefinition']

   
    family, revision = task_definition_arn.split(':')[-2:]     //  Extract the family and revision from the task definition ARN

    
    response = ecs_client.list_task_definitions(family=family, status='ACTIVE')  // List all the revisions of the task definition family

    task_definition_versions = response.get('taskDefinitionArns', [])

    if not task_definition_versions:
        print(f"No task definition versions found for the family '{family}'.")
        return

    print(f"Task definition versions for the family '{family}':")
    for version in task_definition_versions:
        print(version)

if __name__ == "__main__":
    
    cluster_name = 'your-cluster-name'  //Replace these with your ECS cluster name and service name
    service_name = 'your-service-name'

    list_task_definition_versions(cluster_name, service_name)

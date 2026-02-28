aws_region  = "us-east-1"
environment = "dev"
vpc_id      = "vpc-01ebffb1cf75da0ec"
vpc_cidr    = "10.0.0.0/16"
private_subnet_ids = [
  "subnet-0a82db787a1a1167a",
  "subnet-0ec2594a375722805",
  "subnet-0c81283c4a554f044"
]
deployment_bucket  = "oncokb-deployment-data-270327054051"
aws_account_id     = "270327054051"
rds_instance_class = "db.t3.small"

# ECS Service Connect - using existing corporate namespace
service_connect_namespace_arn  = "arn:aws:servicediscovery:us-east-1:270327054051:namespace/ns-u42x25abybpjh7yf"
service_connect_namespace_name = "cggt-dev.vrtx.com"

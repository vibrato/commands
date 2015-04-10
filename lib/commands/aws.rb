

$credentials = Aws::Credentials.new(ENV["AWS_ACCESS_KEY"], ENV["AWS_SECRET_KEY"])

$rds = Aws::RDS::Client.new(
  region: "ap-southeast-2",
  credentials: $credentials)

$cloudformation = Aws::CloudFormation::Client.new(
  region: "ap-southeast-2",
  credentials: $credentials)

$ec2 = Aws::EC2::Client.new(
  region: "ap-southeast-2",
  credentials: $credentials)

$elasticache = Aws::ElastiCache::Client.new(
  region: "ap-southeast-2",
  credentials: $credentials)

$iam = Aws::IAM::Client.new(
  region: "ap-southeast-2",
  credentials: $credentials)

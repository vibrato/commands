

$credentials = Aws::Credentials.new(ENV["AWS_ACCESS_KEY"], ENV["AWS_SECRET_KEY"])

$rds = Aws::RDS::Client.new(
  region: ENV["REGION"],
  credentials: $credentials)

$cloudformation = Aws::CloudFormation::Client.new(
  region: ENV["REGION"],
  credentials: $credentials)

$ec2 = Aws::EC2::Client.new(
  region: ENV["REGION"],
  credentials: $credentials)

$elasticache = Aws::ElastiCache::Client.new(
  region: ENV["REGION"],
  credentials: $credentials)

$iam = Aws::IAM::Client.new(
  region: ENV["REGION"],
  credentials: $credentials)

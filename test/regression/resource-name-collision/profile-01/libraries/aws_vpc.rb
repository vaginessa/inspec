class MyAwsVpc < Inspec.resource(1)
  name 'aws_vpc'
  desc 'Dummy class to collide with core aws_vpc'

  supports platform: 'aws'

  include AwsSingularResourceMixin

  def to_s
    "My Own VPC Implementation"
  end

  def validate_params(raw_params)
    raw_params
  end

  def fetch_from_api
    # Do nothing, this is a dummy class.
  end
end
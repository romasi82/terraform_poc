environment = "func"
application = "search"

network = {
  cidr_block = "10.0.0.0/16"
  availability_zones = ["us-west-2a"] // , "us-west-2b", "us-west-2c"]
  public_subnets = ["10.0.0.0/24"] // , "10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.10.0/24"] // , "10.0.11.0/24", "10.0.12.0/24"]
}

services = {
  vpn = {
    ami_id = "ami-0c81dd687824b02b6"
    instance_type = "t3.micro"
    availability_zones = ["us-west-2a"]
  }

  bastion = {
    ami_id = "ami-07849040363c51a9a"
    instance_type = "t3.micro"
    availability_zones = ["us-west-2a"]
  }

  consul = {
    ami_id = "ami-02565365479fc0ab5"
    instance_type = "t3.micro"
    availability_zones = ["us-west-2a"] // , "us-west-2b", "us-west-2c"]
  }

  nomad = {
    ami_id = "ami-00963718b77fc138b"
    instance_type = "t3.micro"
    availability_zones = ["us-west-2a"] // , "us-west-2b", "us-west-2c"]
  }

  nomad-client = {
    ami_id = "ami-0cf4242438b9d3b34"
    instance_type = "t3.micro"
    availability_zones = ["us-west-2a"] // , "us-west-2b", "us-west-2c"]
  }
}

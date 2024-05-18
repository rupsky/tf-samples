# Define the provider
provider "aws" {
  region = "us-west-2" # Using us-west-2 region
}

locals {
    tags = {
        Name = "robbie-fips"
        email = "robbie@rafay.co"
        env = "dev"
    }
}

# Create a VPC
resource "aws_vpc" "robbie_fips_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = local.tags
}

data "aws_availability_zones" "available" {
  state = "available"
}


# Create a public subnet
resource "aws_subnet" "robbie_fips_public_subnet" {
  vpc_id                  = aws_vpc.robbie_fips_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-west-2a"

  tags = local.tags
}

# Create a private subnet
resource "aws_subnet" "robbie_fips_private_subnet" {
  vpc_id     = aws_vpc.robbie_fips_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-west-2a"

  tags = local.tags
}

# Create an internet gateway
resource "aws_internet_gateway" "robbie_fips_igw" {
  vpc_id = aws_vpc.robbie_fips_vpc.id

  tags = local.tags
}

# Create a route table for the public subnet
resource "aws_route_table" "robbie_fips_public_rt" {
  vpc_id = aws_vpc.robbie_fips_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.robbie_fips_igw.id
  }

  tags = local.tags
}

# Associate the public subnet with the public route table
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.robbie_fips_public_subnet.id
  route_table_id = aws_route_table.robbie_fips_public_rt.id
}

# Create a security group for the instance
resource "aws_security_group" "robbie_fips_sg" {
  name_prefix = "robbie-fips-sg-"
  vpc_id      = aws_vpc.robbie_fips_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = local.tags
}

# Create an Elastic IP
resource "aws_eip" "robbie_fips_instance_eip" {
  domain = "vpc"
  tags = local.tags
}

resource "aws_key_pair" "robbie_fips_sshkey" {
  key_name   = "robbie_fips_sshkey"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCr/bRBFgLj5l7JiX/0H0uqLUa50x14iWXGKxrqjzPy5UYP9mIqLS4udxf5uvTpB5QsWp9Xn0r3gch0es8QVSG8g0aEHjRhxMD3sW/KhpU4fvCMXLa/ccVQA7OvvYmaoc4aKQXk/kksNQE68+UaVd/gClMq4TMlDH0KlJUADZ3+ZduBKTjKYcme24QD7wHEMipFLuA+NZ0DeMgBlU9zqVI5RX9PW+jheKzII+LZywDlSocNIxoWvgTUJAil1GUlqzWngLZiMBd1xfuJ9BahwlridMOtpbGnamHbZbfE7KKY+eiazfpTERO/T9SYJE/c2U468mO1eggRQjdw0GfcxMgy1ppcL0R80qkxtWxkFaWWxLx1Rh0BO1f+VuRuJiTdOdymmttCqBnCGmsSjIf8zmDr+r1Xmgs3W1KevIyCgezCLhdGPXFkXRAD2VDW1Qo26BDqmhv39M2CPXXil0ifMsdd0T4nIiguaAF4vzYPmmcajCyWNLqaZv4TqBFSwKN6+YE= rgill@Robbies-MBP"
}


resource "aws_instance" "robbie_fips_instance" {
  ami           = "ami-0a283ac1aafe112d5" # Amazon Linux 2 Kernel 5.10 AMI 2.0.20240503.0 x86_64 HVM gp2
  #ami           = "ami-01cd4de4363ab6ee8" # Amazon Linux 2023 AMI 2023.4.20240513.0 x86_64 HVM kernel-6.1

  instance_type = "t3.xlarge"
  key_name = "robbie_fips_sshkey"
  security_groups = [aws_security_group.robbie_fips_sg.id]
  subnet_id = aws_subnet.robbie_fips_public_subnet.id
  volume_tags = local.tags

  root_block_device  {
    volume_size = 100
    #tags = local.tags

  }

  tags = local.tags
}

resource "aws_eip" "eip" {
  domain = "vpc"
  instance = aws_instance.robbie_fips_instance.id
  network_border_group = "us-west-2"
  tags = local.tags
}


output "instance_public_ip" {
  description = "instance public IP address"
  value       = aws_eip.eip.public_ip
}

resource "aws_vpc" "main" {
  cidr_block = var.cidr_block

  tags = {
    Name = "vpc_default"
  }
}

resource "aws_subnet" "subnet_public" {
  vpc_id                  = aws_vpc.main.id
  availability_zone       = "us-east-1a"
  cidr_block              = var.cidr
  map_public_ip_on_launch = true

}
resource "aws_subnet" "subnet_public2" {
  vpc_id                  = aws_vpc.main.id
  availability_zone       = "us-east-1b"
  cidr_block              = var.cidr2
  map_public_ip_on_launch = true

}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

}

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

}

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.subnet_public2.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.subnet_public.id
  route_table_id = aws_route_table.RT.id
}
resource "aws_security_group" "webSg" {
  name   = "web"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web-sg"
  }
}
resource "aws_s3_bucket" "example" {
  bucket = "s3bucketgolbal0123"
}

resource "aws_instance" "webServer1" {
  ami                    = "ami-084568db4383264d4"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.webSg.id]
  subnet_id              = aws_subnet.subnet_public.id
  user_data              = base64encode(file("userdate.sh"))
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  tags = {
    Name = "HelloWorld"
  }
}

resource "aws_instance" "webServer2" {
  ami                    = "ami-084568db4383264d4"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.webSg.id]
  subnet_id              = aws_subnet.subnet_public2.id
  user_data              = base64encode(file("userdata2.sh"))
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  tags = {
    Name = "HelloWorld2"
  }
}

resource "aws_lb" "load" {
  name               = "loadsbalancer"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.webSg.id]
  subnets         = [aws_subnet.subnet_public.id, aws_subnet.subnet_public2.id]
  tags = {
    Name = "web"
  }

}
resource "aws_lb_target_group" "tg" {
  name     = "myTg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "attact" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webServer1.id
  port             = 80

}
resource "aws_lb_target_group_attachment" "attact2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webServer2.id
  port             = 80

}
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.load.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"


  }

}
output "loadsbalancer" {
  value = aws_lb.load.dns_name

}
resource "aws_iam_role" "ec2_role" {
  name = "ec2-access-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = {
    Name = "role"
  }
}
resource "aws_iam_policy" "s3_access_policy" {
  name        = "S3AccessPolicy"
  description = "Allow EC2 to access S3 bucket"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.example.arn
        ]
      }
    ]
  })
  tags = {
    Name = "policy"
  }
}
resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

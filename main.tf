provider"aws"{
  region=var.region
}

resource "aws_vpc" "main" {
  cidr_block="10.0.0.0/24"
  tags={
    Name="MyVPC"
  }
}

resource "aws_subnet" "public_subnet_az1" {
  vpc_id=aws_vpc.main.id
  cidr_block="10.0.0.0/26"
  availability_zone="us-east-1a"
  map_public_ip_on_launch=true  

  tags={
    Name="Public Subnet AZ1"
  }
}
resource "aws_subnet" "public_subnet_az2" {
  vpc_id=aws_vpc.main.id
  cidr_block="10.0.0.64/26"
  availability_zone="us-east-1b"
  map_public_ip_on_launch=true  

  tags={
    
    Name="Public Subnet AZ2"
  }
}
resource "aws_subnet" "private_subnet_az1" {
  vpc_id=aws_vpc.main.id
  cidr_block="10.0.0.128/26"
  availability_zone="us-east-1a"

  tags={
    Name="Private Subnet AZ1"
  }
}
resource "aws_subnet" "private_subnet_az2" {
  vpc_id=aws_vpc.main.id
  cidr_block="10.0.0.192/26"
  availability_zone="us-east-1b"

  tags ={
    Name="Private Subnet AZ2"
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id=aws_vpc.main.id

  tags={
    Name="MyInternetGateway"
  }
}
resource"aws_route_table" "public_rt" {
  vpc_id=aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags={
    Name="Public Route Table"
  }
}
resource "aws_route_table_association" "public_assoc_az1" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_az2" {
  subnet_id=aws_subnet.public_subnet_az2.id
  route_table_id=aws_route_table.public_rt.id
}


resource "aws_security_group" "alb_sg" {
  name="alb-security-group"
  vpc_id=aws_vpc.main.id

  ingress {
    from_port=80
    to_port=80
    protocol="tcp"
    cidr_blocks=["0.0.0.0/0"]
  }

  egress {
    from_port=0
    to_port=0
    protocol="-1"
    cidr_blocks=["0.0.0.0/0"]
  }

  tags = { Name = "ALB-SG" }
}
resource "aws_security_group" "app_sg" {
  name="app-security-group"
  vpc_id=aws_vpc.main.id

  ingress {
    from_port=80
    to_port=80
    protocol="tcp"
    security_groups=[aws_security_group.alb_sg.id]
  }

  egress{
    from_port=0
    to_port=0
    protocol="-1"
    cidr_blocks=["0.0.0.0/0"]
  }

  tags={Name="App-SG"}
}
resource "aws_lb" "app_alb" {
  name="app-load-balancer"
  internal=false  # External ALB
  load_balancer_type="application"
  security_groups=[aws_security_group.alb_sg.id]
  subnets=[aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id]
  tags={
    Name="App-ALB"
  }
}
resource "aws_lb_target_group" "alb_target_group" {
  name="alb-target-group"
  port = 80
  protocol="HTTP"
  vpc_id=aws_vpc.main.id
  target_type= "instance"

  health_check {
    path= "/"
    interval=30
    timeout=5
    healthy_threshold=2
    unhealthy_threshold=2
  }

  tags = {
    Name = "TargetGroup"
  }
}
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn=aws_lb.app_alb.arn
  port=80
  protocol="HTTP"

  default_action {
    type="forward"
    target_group_arn=aws_lb_target_group.alb_target_group.arn
  }
}

resource "aws_launch_template" "app_launch_template" {
  name_prefix ="app-instance-"
  image_id=var.ami
  instance_type=var.instance_type
  vpc_security_group_ids=[aws_security_group.app_sg.id]

  tag_specifications {
    resource_type = "instance"
    tags={
      Name="AppInstance"
    }
  }
}
resource "aws_autoscaling_group" "app_asg" {
  desired_capacity=2
  max_size =3
  min_size =0
  vpc_zone_identifier=[aws_subnet.private_subnet_az1.id, aws_subnet.private_subnet_az2.id]

  launch_template {
    id=aws_launch_template.app_launch_template.id
    version="$Latest"
  }

  target_group_arns=[aws_lb_target_group.alb_target_group.arn]

  tag {
    key = "Name"
    value="App-ASG-Instance"
    propagate_at_launch = true
  }
}

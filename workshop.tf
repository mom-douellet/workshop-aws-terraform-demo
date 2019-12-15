variable "rds_admin_username" {
  description = "Compte administrateur RDS"
  default = "admin"
}

variable "rds_admin_password" {
  description = "Compte administrateur RDS, mot de passe"
}

variable "public_key" {
  description = "Votre clé publique"
}

variable "workshop_id" {
  description = "Votre clé publique"
}

variable "vnet_offest" {
  description = "Incrément pour les sous réseaux"
}

variable "workshop_vpc_id" {
  description = "ID du VPC auquel on doit s'attcaché"
}

provider aws {
  region = "ca-central-1"
  version = "~> 2.42"
}

data "aws_region" "current" {}

locals {
  project_tags = {
    project = "workshop-mom"
    builder = "terraform"
    env     = "test"
    owner = "${var.workshop_id}"
  }

  aws_ami = "ami-007dbcbce3118978b"
}

resource "aws_subnet" "workshop-vpc-public-a" {
  vpc_id            = var.workshop_vpc_id
  cidr_block        = "10.1.${var.vnet_offest + 0}.0/24"
  availability_zone = "${data.aws_region.current.name}a"
  tags              = merge(map("Name", "${var.workshop_id}-public-a"), local.project_tags)
  map_public_ip_on_launch = true
}

resource "aws_subnet" "workshop-vpc-public-b" {
  vpc_id            = var.workshop_vpc_id
  cidr_block        = "10.1.${var.vnet_offest + 1}.0/24"
  availability_zone = "${data.aws_region.current.name}b"
  tags              = merge(map("Name", "${var.workshop_id}-public-b"), local.project_tags)
  map_public_ip_on_launch  = true
}

resource "aws_subnet" "workshop-vpc-private-a" {
  vpc_id            = var.workshop_vpc_id
  cidr_block        = "10.1.${var.vnet_offest + 2}.0/24"
  availability_zone = "${data.aws_region.current.name}a"
  tags              = merge(map("Name", "${var.workshop_id}-private-a"), local.project_tags)
}

resource "aws_subnet" "workshop-vpc-private-b" {
  vpc_id            = var.workshop_vpc_id
  cidr_block        = "10.1.${var.vnet_offest + 3}.0/24"
  availability_zone = "${data.aws_region.current.name}b"
  tags              = merge(map("Name", "${var.workshop_id}-private-b"), local.project_tags)
}

resource "aws_key_pair" "workshop" {
  key_name   = "${var.workshop_id}-ssh-key"
  public_key = var.public_key
}

resource "aws_db_subnet_group" "workshop-rds-subnet" {
  name       = "${var.workshop_id}-rds-subnet"
  subnet_ids = [aws_subnet.workshop-vpc-private-a.id, aws_subnet.workshop-vpc-private-b.id]

  tags = merge(map("Name", "${var.workshop_id}-rds-subnet"), local.project_tags)
}

resource "aws_rds_cluster_instance" "workshop-instances" {
  count              = 1
  identifier         = "${var.workshop_id}-database-1-inst-${count.index}"
  cluster_identifier = aws_rds_cluster.workshop-cluster.id
  instance_class     = "db.t2.small"

  tags = merge(map("Name", "${var.workshop_id}-database-1-inst-${count.index}"), local.project_tags)
}

resource "aws_rds_cluster" "workshop-cluster" {
  cluster_identifier = "${var.workshop_id}-database-cluster-1"
  availability_zones = ["ca-central-1a","ca-central-1b"]
  database_name      = "DBName"
  master_username    = var.rds_admin_username
  master_password    = var.rds_admin_password
  vpc_security_group_ids = [aws_security_group.workshop-mysql.id]
  db_subnet_group_name = aws_db_subnet_group.workshop-rds-subnet.id
  skip_final_snapshot  = true

  tags = merge(map("Name", "${var.workshop_id}-rds-cluster"), local.project_tags)
}

resource "aws_s3_bucket" "database-config" {
  bucket = "ca.momentumtechnologies.aws.workshop.${var.workshop_id}"
  acl    = "private"
  tags = local.project_tags
}

resource "aws_s3_bucket_object" "database-comfig" {
  key    = "quickstart-database-cred.yaml"
  bucket = aws_s3_bucket.database-config.id
  content = <<EOF
username: "${var.rds_admin_username}"
password: "${var.rds_admin_password}"
host: "${aws_rds_cluster.workshop-cluster.endpoint}"
EOF
}

resource "aws_security_group" "workshop-webservers" {
  name   = "${var.workshop_id}-webservers"
  vpc_id = var.workshop_vpc_id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = "80"
    to_port     = "80"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = "443"
    to_port     = "443"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    from_port   = "22"
    to_port     = "22"
  }
  tags = local.project_tags
}

resource "aws_security_group" "workshop-mysql" {
  name   = "ssh-allow-admin"
  vpc_id = var.workshop_vpc_id
  ingress {
    security_groups = [aws_security_group.workshop-webservers.id]
    protocol    = "tcp"
    from_port   = "3306"
    to_port     = "3306"
  }
  tags = local.project_tags
}

resource "aws_default_security_group" "workshop-vpc" {
  vpc_id = var.workshop_vpc_id

  ingress {
    self      = true
    protocol  = -1
    from_port = 0
    to_port   = 0
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol   = -1
    from_port  = 0
    to_port    = 0
  }
}

resource "aws_iam_role_policy" "workshop-s3-access" {
  name        = "${var.workshop_id}-s3-database-config"
  role = aws_iam_role.workshop-webserver.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "S3ListDatabaseConfig",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::ca.momentumtechnologies.aws.workshop.${var.workshop_id}"
            ]
        },
        {
            "Sid": "S3GetDatabaseConfig",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws:s3:::ca.momentumtechnologies.aws.workshop.${var.workshop_id}/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role" "workshop-webserver" {
  name = "${var.workshop_id}-webserver-role"
  tags  = local.project_tags

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_instance_profile" "workshop-webserver" {
  name = "${var.workshop_id}-instance-profile"
  role = aws_iam_role.workshop-webserver.name
}

resource "aws_instance" "webserver" {
  ami                         = local.aws_ami
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.workshop-vpc-public-a.id
  key_name                    = aws_key_pair.workshop.key_name
  associate_public_ip_address = true

  depends_on = [
    aws_rds_cluster_instance.workshop-instances,
    ]

  vpc_security_group_ids = [
    aws_security_group.workshop-webservers.id,
    aws_default_security_group.workshop-vpc.id
  ]
  count = 1
  tags  = merge(map("Name", "${var.workshop_id}-webserver"), local.project_tags)
  iam_instance_profile = aws_iam_instance_profile.workshop-webserver.name

  lifecycle {
    create_before_destroy = true
  }
  user_data = <<EOF
#!/bin/bash
echo -n ${var.workshop_id} > /etc/demo_identifiant

amazon-linux-extras install -y ansible2=2.8
yum -y install git

git clone https://github.com/mom-douellet/workshop-aws-ansible-deploy.git /ansible-deploy
cd /ansible-deploy

ansible-playbook site.yml
EOF

}

output "instances_map" {
  value = "${aws_instance.webserver}"
}

output "instances_ip" {
  value = aws_instance.webserver.0.public_ip
}

output "instances_dns" {
  value = aws_instance.webserver.0.public_dns
}
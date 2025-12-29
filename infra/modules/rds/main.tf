resource "aws_db_subnet_group" "this" {
  name       = "${var.db_identifier}-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.db_identifier}-subnet-group"
  }
}

resource "aws_security_group" "db" {
  name        = "${var.db_identifier}-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  # Allow PostgreSQL from EKS worker nodes SG
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.allowed_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.db_identifier}-sg"
  }
}

resource "random_password" "db" {
  length  = 16
  special = false 
}

resource "aws_db_instance" "this" {
  identifier           = var.db_identifier
  engine               = "postgres"
  #engine_version is intentiionally omitted so AWS uses a valid default
  instance_class       = var.db_instance_class
  allocated_storage    = 20
  db_name              = var.db_name
  username             = var.db_username
  password             = random_password.db.result
  db_subnet_group_name = aws_db_subnet_group.this.name

  vpc_security_group_ids = [aws_security_group.db.id]

  publicly_accessible = false
  skip_final_snapshot = true

  deletion_protection = false

  tags = {
    Name = var.db_identifier
  }
}

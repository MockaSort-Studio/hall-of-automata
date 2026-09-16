
data "aws_kms_key" "rds" {
  key_id = "alias/aws/rds"
}

# ── DB Subnet Group ───────────────────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "a2t-mrv-db"
  subnet_ids = var.db_subnet_ids
  tags       = merge(var.tags, { Name = "a2t-mrv-db-subnet-group" })
}

# ── Parameter Group ───────────────────────────────────────────────────────────
# PostGIS 3.x and TimescaleDB are trusted extensions on RDS PostgreSQL 15 and
# do not require shared_preload_libraries. rds.allowed_extensions explicitly
# whitelists them so non-superusers can run CREATE EXTENSION.
resource "aws_db_parameter_group" "main" {
  name        = "a2t-mrv-postgres15"
  family      = "postgres15"
  description = "a2t-mrv: PostGIS workload with connection logging"

  parameter {
    name  = "rds.allowed_extensions"
    value = "address_standardizer,address_standardizer_data_us,fuzzystrmatch,postgis,postgis_tiger_geocoder,postgis_topology"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = var.tags
}

# ── RDS Security Group ────────────────────────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "a2t-mrv-rds-sg"
  description = "PostgreSQL inbound from app EC2 only; all outbound."
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from app"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.app_security_group_id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "a2t-mrv-rds-sg" })
}

# ── Enhanced Monitoring IAM Role ──────────────────────────────────────────────
data "aws_iam_policy_document" "rds_monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name               = "a2t-mrv-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ── RDS PostgreSQL Instance ───────────────────────────────────────────────────
resource "aws_db_instance" "main" {
  identifier     = "a2t-mrv-db"
  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t4g.small"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = data.aws_kms_key.rds.arn

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  multi_az                = false
  deletion_protection     = true
  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = data.aws_kms_key.rds.arn
  performance_insights_retention_period = 7

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  skip_final_snapshot       = false
  final_snapshot_identifier = "a2t-mrv-db-final-snapshot"

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.rds_monitoring]
}

# ── Secrets Manager: DB credentials ──────────────────────────────────────────
# Single secret with all fields needed to open a connection: username, password,
# host, port, dbname. Matches the AWS RDS-managed secret JSON shape so tooling
# (console, rotation Lambdas) understands the format.
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "a2t-mrv/db-credentials"
  description = "RDS master-user credentials and connection info for a2t-mrv."
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
  })
}

# ── Secrets Manager: SECRET_KEY_BASE ─────────────────────────────────────────
# The actual value must be set manually or via CI after first provisioning.
resource "aws_secretsmanager_secret" "secret_key_base" {
  name        = "a2t-mrv/secret-key-base"
  description = "Phoenix SECRET_KEY_BASE for a2t-mrv livedata."
  tags        = var.tags
}

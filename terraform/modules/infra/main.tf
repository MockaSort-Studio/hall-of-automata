
# ── AZs ──────────────────────────────────────────────────────────────────────
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

# ── AMI ──────────────────────────────────────────────────────────────────────
# Amazon Linux 2023: first-class CodeDeploy, SSM, and CloudWatch support with
# zero custom configuration. The Mix release bundles the BEAM runtime so no
# Elixir/Erlang packages are needed on the host.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Network ──────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(var.tags, { Name = "a2t-mrv-vpc" })
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags                    = merge(var.tags, { Name = "a2t-mrv-subnet" })
}

# Private subnets for the RDS DB subnet group (must span two AZs).
resource "aws_subnet" "db_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = merge(var.tags, { Name = "a2t-mrv-db-subnet-a" })
}

resource "aws_subnet" "db_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags              = merge(var.tags, { Name = "a2t-mrv-db-subnet-b" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "a2t-mrv-igw" })
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, { Name = "a2t-mrv-rt" })
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# ── Security Group ───────────────────────────────────────────────────────────
resource "aws_security_group" "main" {
  name        = "a2t-mrv-sg"
  description = "SSH, HTTP, HTTPS inbound; all outbound."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "a2t-mrv-sg" })
}

# ── EC2 Instance ─────────────────────────────────────────────────────────────
resource "aws_instance" "main" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.main.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  # user_data installs the CodeDeploy agent at first boot.
  # Replace-on-change enabled: the instance is stateless (all state in RDS/S3);
  # a user_data change means the host config changed, so replace is correct.
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    region                      = data.aws_region.current.name
    db_credentials_secret_name  = var.db_credentials_secret_name
    secret_key_base_secret_name = var.secret_key_base_secret_name
  })
  user_data_replace_on_change = true

  # Enforce IMDSv2 (token-required). Deploy scripts read region from
  # /etc/livedata/region (written by user_data) instead of querying IMDS.
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  # Root volume — OS only; app is deployed to /opt/livedata by CodeDeploy.
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
  }

  # CodeDeployApp tag is the selector used by the CodeDeploy deployment group (#148).
  tags = merge(var.tags, { Name = "a2t-mrv-vm", CodeDeployApp = "livedata" })
}

# ── Post-provision verification ───────────────────────────────────────────────
# Waits for SSM to register the instance and then verifies the CodeDeploy agent
# is active. If user_data fails silently, this makes terraform apply fail loudly.
resource "null_resource" "verify_codedeploy_agent" {
  depends_on = [aws_instance.main, aws_eip.main, aws_iam_role_policy_attachment.ec2_ssm]

  triggers = {
    instance_id = aws_instance.main.id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      INSTANCE_ID="${aws_instance.main.id}"
      REGION="${data.aws_region.current.name}"

      echo "Waiting for SSM registration of $INSTANCE_ID (up to 5 min)..."
      for i in $(seq 1 30); do
        STATUS=$(aws ssm describe-instance-information \
          --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
          --region "$REGION" \
          --query 'InstanceInformationList[0].PingStatus' \
          --output text 2>/dev/null || echo "NotReady")
        [ "$STATUS" = "Online" ] && break
        echo "  attempt $i/30 — $STATUS"
        sleep 10
      done
      [ "$STATUS" = "Online" ] || { echo "ERROR: instance never joined SSM — check /var/log/user-data.log"; exit 1; }

      # Poll until codedeploy-agent is active (user_data installs ruby + agent, ~90s).
      echo "Waiting for CodeDeploy agent to start (up to 6 min)..."
      AGENT_OK=false
      for j in $(seq 1 24); do
        CMD_ID=$(aws ssm send-command \
          --instance-ids "$INSTANCE_ID" \
          --region "$REGION" \
          --document-name AWS-RunShellScript \
          --parameters 'commands=["systemctl is-active codedeploy-agent"]' \
          --output text --query 'Command.CommandId' 2>/dev/null || echo "SEND_FAILED")
        [ "$CMD_ID" = "SEND_FAILED" ] && { echo "  check $j/24 — SSM send failed, retrying"; sleep 15; continue; }
        sleep 15
        RESULT=$(aws ssm get-command-invocation \
          --command-id "$CMD_ID" \
          --instance-id "$INSTANCE_ID" \
          --region "$REGION" \
          --query 'Status' --output text 2>/dev/null || echo "ERROR")
        [ "$RESULT" = "Success" ] && { AGENT_OK=true; break; }
        echo "  check $j/24 — $RESULT"
      done
      $AGENT_OK || { echo "ERROR: CodeDeploy agent not active on $INSTANCE_ID after 6 min"; exit 1; }
      echo "OK — CodeDeploy agent verified running on $INSTANCE_ID."
    EOT
  }
}

# ── Elastic IP ───────────────────────────────────────────────────────────────
resource "aws_eip" "main" {
  domain   = "vpc"
  instance = aws_instance.main.id
  tags     = merge(var.tags, { Name = "a2t-mrv-eip" })

  depends_on = [aws_internet_gateway.main]
}

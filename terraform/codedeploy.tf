# ── CodeDeploy service role ────────────────────────────────────────────────────
resource "aws_iam_role" "codedeploy_service" {
  name = "a2t-mrv-codedeploy-service"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "codedeploy_service" {
  role       = aws_iam_role.codedeploy_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# ── CodeDeploy application ─────────────────────────────────────────────────────
resource "aws_codedeploy_app" "livedata" {
  name             = "a2t-mrv-livedata"
  compute_platform = "Server"
}

# ── CodeDeploy deployment group ────────────────────────────────────────────────
# Targets EC2 instances tagged CodeDeployApp=livedata (set by the infra module).
# AutoRollback fires on DEPLOYMENT_FAILURE, restoring the previous revision.
resource "aws_codedeploy_deployment_group" "livedata" {
  app_name               = aws_codedeploy_app.livedata.name
  deployment_group_name  = "a2t-mrv-livedata-dg"
  service_role_arn       = aws_iam_role.codedeploy_service.arn
  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  ec2_tag_filter {
    key   = "CodeDeployApp"
    value = "livedata"
    type  = "KEY_AND_VALUE"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  deployment_style {
    deployment_type   = "IN_PLACE"
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
  }
}

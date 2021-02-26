#
# Create IAM Role
#

data "aws_iam_policy_document" "bigip_role" {
  version = "2012-10-17"
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bigip_role" {
  name               = format("%s-bigip-role", var.prefix)
  assume_role_policy = data.aws_iam_policy_document.bigip_role.json

  tags = {
    tag-key = "tag-value"
  }
}

resource "aws_iam_instance_profile" "bigip_profile" {
  name = format("%s-bigip-profile", var.prefix)
  role = aws_iam_role.bigip_role.name
}

resource "aws_iam_role_policy" "bigip_policy" {
  name   = format("%s-bigip-policy", var.prefix)
  role   = aws_iam_role.bigip_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": [
            "ec2:DescribeInstances",
            "ec2:DescribeInstanceStatus",
            "ec2:DescribeAddresses",
            "ec2:AssociateAddress",
            "ec2:DisassociateAddress",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DescribeNetworkInterfaceAttribute",
            "ec2:DescribeRouteTables",
            "ec2:ReplaceRoute",
            "ec2:CreateRoute",
            "ec2:assignprivateipaddresses",
            "sts:AssumeRole",
            "s3:ListAllMyBuckets"
        ],
        "Resource": [
            "*"
        ],
        "Effect": "Allow"
    },
    {
        "Effect": "Allow",
        "Action": [
            "secretsmanager:GetResourcePolicy",
            "secretsmanager:GetSecretValue",
            "secretsmanager:DescribeSecret",
            "secretsmanager:ListSecretVersionIds",
            "secretsmanager:UpdateSecretVersionStage"
        ],
        "Resource": [
            "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:*"
        ]
    }
  ]
}
EOF
}

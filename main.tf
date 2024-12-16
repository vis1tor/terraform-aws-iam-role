locals {
  # merge(...)를 사용하여 list를 map로 변환 
  # 변환 전
  # [
  #   {
  #     "AmazonEC2ReadOnlyAccess" = "role-glb-bedrock-mkkim-lambda-01"
  #     "AmazonElastiCacheReadOnlyAccess" = "role-glb-bedrock-mkkim-lambda-01"
  #   },
  # ]
  # 변환 후
  # {
  #   "AmazonEC2ReadOnlyAccess" = "role-glb-bedrock-mkkim-lambda-01"
  #   "AmazonElastiCacheReadOnlyAccess" = "role-glb-bedrock-mkkim-lambda-01"
  # }

  managed_policys = merge([for k, v in var.iam_info : { for index, value in v.iam_managed_policy :
  value => v.iam_role_name }]...)

  custom_policys = merge([for k, v in var.iam_info : { for index, value in v.iam_custom_policy :
  value.iam_custom_policy_name => merge(value, { "iam_role_name" = v.iam_role_name }) }]...)
}


###########################
# Role
###########################
resource "aws_iam_role" "this" {
  for_each = { for k, v in var.iam_info : v.iam_role_name => v if v.iam_assume_role_policy != {} }

  name               = each.value.iam_role_name
  assume_role_policy = jsonencode(each.value.iam_assume_role_policy)

  tags = {
    Name = each.value.iam_role_name
  }
}

# instance_profile 생성 시에만 사용
resource "aws_iam_instance_profile" "this" {
  for_each = { for k, v in var.iam_info : v.iam_role_name => v if v.iam_instance_profile_role == "true" }

  name = each.value.iam_role_name
  role = aws_iam_role.this[each.value.iam_role_name].name
}

###########################
# Managed Policy
###########################
resource "aws_iam_role_policy_attachment" "managed" {
  for_each = { for k, v in local.managed_policys : k => v if local.managed_policys != null }

  role       = aws_iam_role.this[each.value].name
  policy_arn = each.key

  depends_on = [aws_iam_role.this]
}

###########################
# Custom Policy
###########################
resource "aws_iam_policy" "custom" {
  for_each = { for k, v in local.custom_policys : v.iam_custom_policy_name => v if local.custom_policys != {} }

  name        = each.value.iam_custom_policy_name
  path        = "/"
  description = each.value.iam_custom_policy_description
  policy      = jsonencode(each.value.iam_custom_policy)
  tags = {
    "Name" = each.value.iam_custom_policy_name
  }
}

resource "aws_iam_role_policy_attachment" "custom" {
  for_each = { for k, v in local.custom_policys : k => v if local.custom_policys != null }

  role       = aws_iam_role.this[each.value.iam_role_name].name
  policy_arn = aws_iam_policy.custom[each.value.iam_custom_policy_name].arn

  depends_on = [aws_iam_role.this]
}

# 변경 전
# aws_iam_policy_attachment 사용 시, 해당 정책에 포함되는 모른 group, user, role에서 해당 정책을 제거하려는 문제 발생!!!
# https://qiita.com/bilzard/items/8b54c40351e2ff39afa0
# resource "aws_iam_policy_attachment" "custom" {
#   for_each   = { for k, v in local.custom_policys : k => v if v.iam_policy != {} && v.iam_assume_role_policy != {} }
#   name       = "test"
#   roles      = [aws_iam_role.this[each.value.iam_role_name].name]
#   policy_arn = aws_iam_policy.this[each.value.iam_policy_name].arn
# }

# resource "aws_iam_policy_attachment" "managed" {
#   for_each   = { for k, v in local.managed_policys : k=>v if local.managed_policys != null }

#   name       = "test-attachment"
#   roles      = [aws_iam_role.this[each.value].name]
#   policy_arn = "arn:aws:iam::aws:policy/${each.key}"
# }
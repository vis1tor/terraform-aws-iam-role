variable "iam_info" {
  type = map(object({
    iam_role_name             = string
    iam_instance_profile_role = string
    iam_assume_role_policy    = any
    iam_managed_policy        = list(string)
    iam_custom_policy = list(object({
      iam_custom_policy_name        = string
      iam_custom_policy_description = string
      iam_custom_policy             = any
    }))
  }))
}
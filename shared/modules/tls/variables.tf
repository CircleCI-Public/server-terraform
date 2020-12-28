variable "basename" {
  type        = string
  description = "Name of deployment to be used as a base for naming resources."
}

variable "enabled" {
  type        = number
  description = "Enable mTLS for Nomad communication. Disabling this comes with inherit risk and is not recommended."
  default     = 1
}
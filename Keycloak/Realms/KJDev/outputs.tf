#
# Storage
#

output "MinioClient" {
  value = module.MinioClient
}

#
# TODO: Stolon
#

#
# TODO: Hashicorp Boundary
#

#
# Hashicorp
# 

#
# Hashicorp Vault
# 

output "CoreVaultClientModule" {
  value = module.CoreVaultClient
}

output "VaultClientModule" {
  value = module.VaultClient
}

#
# NextCloud
#

# output "NextCloudClientModule" {
#   value = module.NextCloudClient
# }



# output "PostgresDatabaseService" {
#   value = docker_service.postgresDatabase
# }
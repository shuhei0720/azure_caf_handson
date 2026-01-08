using '../modules/identity/policy-managed-identity.bicep'

param managedIdentityName = 'id-policy-remediation-prod-jpe-001'
param location = 'japaneast'
param tags = {
  Environment: 'Production'
  ManagedBy: 'Bicep'
  Component: 'Identity'
}

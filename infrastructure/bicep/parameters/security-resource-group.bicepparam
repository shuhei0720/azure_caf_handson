using '../modules/resource-group/resource-group.bicep'

param resourceGroupName = 'rg-platform-security-prod-jpe-001'
param location = 'japaneast'
param tags = {
  Environment: 'Production'
  ManagedBy: 'Bicep'
  Component: 'Security'
}

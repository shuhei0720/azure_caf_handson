using '../modules/resource-group/resource-group.bicep'

param resourceGroupName = 'rg-platform-connectivity-prod-jpe-001'
param location = 'japaneast'
param tags = {
  Environment: 'Production'
  ManagedBy: 'Bicep'
  Component: 'Connectivity'
}

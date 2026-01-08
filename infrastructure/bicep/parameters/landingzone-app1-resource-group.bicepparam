using '../modules/resource-group/resource-group.bicep'

param resourceGroupName = 'rg-app1-prod-jpe-001'
param location = 'japaneast'
param tags = {
  Environment: 'Production'
  ManagedBy: 'Bicep'
  Application: 'App1'
}

using '../modules/monitoring/log-analytics.bicep'

param workspaceName = 'log-platform-prod-jpe-001'
param location = 'japaneast'
param retentionInDays = 90
param tags = {
  Environment: 'Production'
  ManagedBy: 'Bicep'
  Component: 'Monitoring'
}

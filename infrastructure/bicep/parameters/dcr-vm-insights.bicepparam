using '../modules/monitoring/dcr-vm-insights.bicep'

param dcrName = 'dcr-vm-insights-prod-jpe-001'
param location = 'japaneast'
param workspaceId = '/subscriptions/YOUR_SUB_ID/resourceGroups/rg-platform-management-prod-jpe-001/providers/Microsoft.OperationalInsights/workspaces/log-platform-prod-jpe-001'
param tags = {
  Environment: 'Production'
  ManagedBy: 'Bicep'
  Component: 'Monitoring'
}

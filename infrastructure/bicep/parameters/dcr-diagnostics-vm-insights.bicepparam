using '../modules/monitoring/dcr-diagnostics.bicep'

param dcrName = 'dcr-vm-insights-prod-jpe-001'
param destinationWorkspaceId = '/subscriptions/YOUR_SUB_ID/resourceGroups/rg-platform-management-prod-jpe-001/providers/Microsoft.OperationalInsights/workspaces/log-platform-prod-jpe-001'
param diagnosticSettingName = 'send-to-log-analytics'

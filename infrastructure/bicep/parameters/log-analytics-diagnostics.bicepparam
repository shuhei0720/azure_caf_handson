using '../modules/monitoring/log-analytics-diagnostics.bicep'

param workspaceName = 'log-platform-prod-jpe-001'
param destinationWorkspaceId = '/subscriptions/YOUR_SUB_ID/resourceGroups/rg-platform-management-prod-jpe-001/providers/Microsoft.OperationalInsights/workspaces/log-platform-prod-jpe-001'
param diagnosticSettingName = 'send-to-log-analytics'

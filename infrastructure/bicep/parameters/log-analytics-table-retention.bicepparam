using '../modules/monitoring/log-analytics-table-retention.bicep'

param workspaceName = 'log-platform-prod-jpe-001'
param tableName = 'AzureActivity'
param retentionInDays = 90
param totalRetentionInDays = 730

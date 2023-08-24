param location string = resourceGroup().location
param storageName string = 'vs${uniqueString(resourceGroup().name)}'
param appConfigName string = 'vs${uniqueString(resourceGroup().name)}'
param keyVaultName string = 'vs${uniqueString(resourceGroup().name)}'
param containerRegistryName string = 'vs${uniqueString(resourceGroup().name)}'
param sharedIdentityName string = 'vs${uniqueString(resourceGroup().name)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
  }
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource appsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobServices
  name: 'apps'
}

resource certsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobServices
  name: 'certs'
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    // Have to enable Admin user in order for Container Apps to access ACR.
    adminUserEnabled: true
    anonymousPullEnabled: false
    policies: {
      retentionPolicy: {
        days: 3
      }
    }
  }
}

resource keyvault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }
    // This was originally set to false as I don't need this feature for this
    // demo key vault, but it is now enabled because App GW allows us to reference
    // Certs stored there and it requires enableSoftDelete.
    enableSoftDelete: true
    enableRbacAuthorization: true
    enabledForTemplateDeployment: true
    enablePurgeProtection: true
    tenantId: subscription().tenantId
  }
}

resource config 'Microsoft.AppConfiguration/configurationStores@2023-03-01' = {
  location: location
  name: appConfigName
  sku: {
    name: 'free'
  }
  properties: {
    disableLocalAuth: true
    enablePurgeProtection: false
    publicNetworkAccess: 'Enabled'
  }
}

resource sharedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: sharedIdentityName
  location: location
}

# Introduction

In order to automate most of the infra and app setup and deployment to Azure for my github repos/projects, I have created (AzSolutionManager or ASM)[https://github.com/seekdavidlee/az-solution-manager]. 

ASM works by reading your manifest to create the necessary resource group(s) and applying tagging policies to ensure we can lookup specific resources used in the deployment.

Each project contains a specific manifest pertaining to the solution. However, there are also external references such as to an Azure KeyVault or App Configuration to get setup secrets/data. If the project is a Container based solution, it requries a Azure Container Registry. The shared-services directory contains a manifest in order to apply tagging policies to those resources, a bicep to deploy those resources in your Azure Subscription and a postDeployment powershell script to apply role assignments. 

In order to faciliate the ochestration of the work needed to run all of the following, I have created this (utility)[README.md] using Powershell. You can run the command below to create a shared-services solution in your Azure Subscription.

```powershell
.\LoadASMToSession.ps1
$a = az account show | ConvertFrom-Json
Invoke-ASMSetup -TENANT $a.tenantId -SUBSCRIPTION $a.Id -DIRECTORY shared-services
```
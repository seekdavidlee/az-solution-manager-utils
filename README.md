# Introduction

When we create a solution, we have some code as well as deployment artifacts such as a bicep, some deployment scripts etc. We can assign a Service Principal as part of the process which has Contributor role assigned in a specific resource group. All these could be part of our automated process aks CI/CD. 

With AzSolutionManager (ASM), we have a manifest that specify the tagging policies for resources (resource id), enviroment, region etc so we can use the lookup function of ASM to get those resources. ASM also takes care of creating the resource group and performs appropriate tagging. This requires a higher level of access and we would usually perform this operation as part of initial setup. Obviously, new resources could be added, and we would update the manifest and re-run. 

We also need to create resources that can be shared across solutions. Once these shared resources are created, we will need to be able to perform appropriate role assignments which requires a higher level of permission. For example, we may want to create a shared key vault that can be used by a few solutions as some secrets may be shared. Hence, a managed identity could be created and assign the KeyVault Secrets User role. These would be referenced in your solution's deployment process such as using a resource Id to identify your Key Vault as well as that managed identity created by someone such as an Owner of Azure Subscription(s) or Admins. These shared resources do not need to be part of your solution's CI/CD process.

This utility is for those Admins. As an Admin, you can create those shared resources with this tool using a Convention based approach to managing your managed solutions.

* Your manifest file MUST be named 'manifest.json'
* Your bicep parameter files must end with 'bicep.json'
* Your post deployment script must be named 'postDeployment.ps1' - Usually used to perform role assignments

# Usage

This module contains Utility powershell scripts for AzSolutionManager. Follow the one-time setup if you have not done so. 

## One-Time setup

To begin, you need to install ASM. ASM is currently in beta so you need to be explicit about the version.

```
dotnet tool install --global AzSolutionManager --version 0.1.4-beta
```

Next, you need to initialize ASM in each of the Azure Subscription you wish to use ASM.

```
asm init --resource-group-name asm --location centralus --managed-identity asm-identity
```

Now you are ready for the next section.

## Load utility in your PowerShell session

Next, you can load this utility into your current powershell session by running the following:

```powershell
.\LoadASMToSession.ps1
```

You should see the following output:

```bash
VERBOSE: Loading module from path '<YOUR_PATH>\ASMUtil.psm1'.
VERBOSE: Importing function ...
...
```

You can use the Get-Help command to track how each command can help you.

```powershell
Get-Help Invoke-ASMSetup
```

See the Example folder in this github repo.

```powershell
Invoke-ASMSetup -TENANT <TENANT_ID> -SUBSCRIPTION <SUBSCRIPTION_ID> -DIRECTORY .\Example
```
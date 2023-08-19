function ApplyManifest {
    param(
        [Parameter(Mandatory = $true)][string]$DIRECTORY,
        [Parameter(Mandatory = $true)][string]$SUBSCRIPTION,
        [Parameter(Mandatory = $false)][string]$ENVIRONMENT,
        [Parameter(Mandatory = $false)][string]$REGION
    )
    $filePath = (Get-Location).Path + "\$DIRECTORY\manifest.json"
    $addArgs = @()

    if ($ENVIRONMENT) {
        $addArgs += "--asm-env"
        $addArgs += $ENVIRONMENT
    }

    if ($REGION) {
        $addArgs += "--asm-reg"
        $addArgs += $REGION
    }

    asm manifest apply -f $filePath -s $SUBSCRIPTION -t $TENANT $addArgs --logging Info
    if ($LastExitCode -ne 0) {
        Pop-Location
        throw "Unable to apply manifest."
    }
    Write-Host "$filePath Manifest applied."
}

function GetDeploymentInput {
    param(
        [Parameter(Mandatory = $true)][string]$bicepFilePath,
        [Parameter(Mandatory = $true)][string]$DIRECTORY,
        [Parameter(Mandatory = $true)][string]$SUBSCRIPTION,
        [Parameter(Mandatory = $false)][string]$ENVIRONMENT,
        [Parameter(Mandatory = $false)][string]$REGION
    )

    $addArgs = @()

    if ($ENVIRONMENT) {
        $addArgs += "--asm-env"
        $addArgs += $ENVIRONMENT

        Write-Host "Set environment: $ENVIRONMENT"
    }

    if ($REGION) {
        $addArgs += "--asm-reg"
        $addArgs += $REGION

        Write-Host "Set region: $REGION"
    }
    
    $json = asm deployment parameters -f $bicepFilePath -s $SUBSCRIPTION -t $TENANT $addArgs --logging Info
    if ($LastExitCode -ne 0) {
        Pop-Location
        throw "Unable to generate deployment input."
    }

    $obj = $json | ConvertFrom-Json
    return $obj
}

<#
.SYNOPSIS
Apply ASM specific manifest definations and optionally run Bicep deployments and post deployment script.

.DESCRIPTION
Convention based approach to managing your managed solutions. 
* Your manifest file MUST be named 'manifest.json'
* Your bicep parameter files must end with 'bicep.json'
* Your post deployment script must be named 'postDeployment.ps1'

.PARAMETER DIRECTORY
Directory where your artifacts of manifest file, and optionally bicep and postDeployment.ps1 script resides.

.PARAMETER SUBSCRIPTION
Subscription Id.

.PARAMETER TENANT
Tenant Id.

.EXAMPLE
N/A

#>
function Invoke-ASMSetup {
    param(
        [Parameter(Mandatory = $true)][string]$DIRECTORY,
        [Parameter(Mandatory = $true)][string]$SUBSCRIPTION,
        [Parameter(Mandatory = $true)][string]$TENANT,
        [Parameter(Mandatory = $false)][string]$ENVIRONMENT,
        [Parameter(Mandatory = $false)][string]$REGION,
        [switch]$SkipManifest)

    $ErrorActionPreference = "Stop"

    if (!$SkipManifest) {
        ApplyManifest  -DIRECTORY $DIRECTORY -SUBSCRIPTION $SUBSCRIPTION -ENVIRONMENT $ENVIRONMENT -REGION $REGION
    }

    Get-ChildItem -Path $DIRECTORY -Filter "*.json"-File | Where-Object { $_.Name -like "*_bicep.json" -or $_.Name -eq "bicep.json" } | ForEach-Object {
        $current = $_
        Write-Host "Processing $current"
        $deploymentInput = GetDeploymentInput -bicepFilePath $current.FullName -DIRECTORY $DIRECTORY -SUBSCRIPTION $SUBSCRIPTION -ENVIRONMENT $ENVIRONMENT -REGION $REGION

        if (!$deploymentInput) {
            throw "Unable to generate deployment input!";
        }

        if (!$deploymentInput.GroupName) {
            throw "Group name is not configured! $deploymentInput"
        }

        $addArgs = @()
        $deploymentName = $DIRECTORY + (Get-Date).ToString("yyyyMMddHHmmss")
        if ($deploymentInput.Parameters) {
            $json = $deploymentInput.Parameters | ConvertTo-Json -Compress
            $json = $json.Replace('"', '\"')

            $addArgs += "--parameters"
            $addArgs += $json
        }

        az deployment group create --name $deploymentName --resource-group $deploymentInput.GroupName --template-file "$DIRECTORY\deploy.bicep" $addArgs
        if ($LastExitCode -ne 0) {
            throw "Error with deployment."
        }
    }

    Push-Location $DIRECTORY
    if (Test-Path .\postDeployment.ps1) {
        
        if ($ENVIRONMENT) {
            Write-Host "Set post-deployment var environment: $ENVIRONMENT"
        }
    
        if ($REGION) {
            Write-Host "Set post-deployment var region: $REGION"
        }

        .\postDeployment.ps1 -SUBSCRIPTION $SUBSCRIPTION -TENANT $TENANT -ENVIRONMENT $ENVIRONMENT -REGION $REGION
    }
    Pop-Location
}

Export-ModuleMember -Function Invoke-ASMSetup

<#
.SYNOPSIS
Setup GitHub Repo service principal in your tenant.

.DESCRIPTION
Create a service principal (sp) and assign sp to a AAD Group for the purpose of using this sp to connect to our Azure Subscription. 
Now, we can assign Subscription level roles to this group instead of directly with the service principal. There are 2 benefits to this approach.
First, we can ensure if the sp is compromised, we simply remove the sp from the Group. Second, anyone or other sp who needs the same level of acces
can just be assigned to this group instead of reworking the role assignments, thus minimizing wrong assignments per user or new sp.

When we first create the SP, we would show the actual json formatted azure credentials you can set as a Secret in your github repo as a secret.
Hence, this script should only be run once.

.PARAMETER SHOW
If we need to show the json formatted azure credentials (without password) a second time, we can just use this switch. No password will be shown. 
Go to the Azure Portal and get the password manually.

.EXAMPLE
N/A

#>
function Add-ASMGitHubDeployment {

    param([switch]$SHOW)

    $ErrorActionPreference = "Stop"

    $spName = "GitHub Deployment"
    $sp = az ad sp list --display-name "GitHub Deployment" | ConvertFrom-Json
    if ($sp.Length -eq 0) {
        $sp = az ad sp create-for-rbac --display-name $spName --years 1 | ConvertFrom-Json
        $password = $sp.password

        Write-Host "App password: $password"

        $sp = az ad sp show --id $sp.appId | ConvertFrom-Json
    }

    if ($Show) {
        $sub = az account show | ConvertFrom-Json

        $o = @{
            "clientId"       = $sp.appId;
            "clientSecret"   = "";
            "tenantId"       = $sp.appOwnerOrganizationId;
            "subscriptionId" = $sub.id;
        }

        $o | ConvertTo-Json

        return
    }

    $appId = $sp.id

    $groupName = "GitHub Deployment"
    $groups = az ad group list --display-name $groupName | ConvertFrom-Json
    if ($groups.Length -eq 0) {
        az ad group create --display-name $groupName --mail-nickname "github-deployment" | ConvertFrom-Json
        if ($LastExitCode -ne 0) {
            Pop-Location
            throw "Unable to create group $groupName."
        }
    }

    Write-Host "Adding member to group"

    az ad group member add --group $groupName --member-id $appId

    $o = @{
        "clientId"       = $sp.appId;
        "clientSecret"   = $password;
        "tenantId"       = $sp.appOwnerOrganizationId;
        "subscriptionId" = $sub.id;
    }

    $o | ConvertTo-Json
}

Export-ModuleMember -Function Add-ASMGitHubDeployment
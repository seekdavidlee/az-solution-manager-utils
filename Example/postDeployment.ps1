param(
    [Parameter(Mandatory = $true)][string]$SUBSCRIPTION,
    [Parameter(Mandatory = $true)][string]$TENANT,
    [Parameter(Mandatory = $false)][string]$ENVIRONMENT,
    [Parameter(Mandatory = $false)][string]$REGION)


function GetResource {
    param (
        [string]$solutionId,
        [string]$environmentName,
        [string]$resourceId,
        [string]$SUBSCRIPTION,
        [string]$TENANT
    )
    
    $obj = asm lookup resource --asm-rid $resourceId --asm-sol $solutionId --asm-env $environmentName -s $SUBSCRIPTION -t $TENANT --logging Info | ConvertFrom-Json
    if ($LastExitCode -ne 0) {
        Pop-Location
        throw "Unable to lookup resource."
    }
    
    return $obj
}

$ErrorActionPreference = "Stop"

$ghgroups = az ad group list --display-name "GitHub Deployment" | ConvertFrom-Json
if ($ghgroups.Length -eq 0) {
    throw "Run SetupGitHub.ps1 to create GitHub Deployment and its AAD group before running this script!"
}

$solutionId = "shared-services"
$environmentName = "prod"

$fsp = GetResource -solutionId $solutionId -environmentName $environmentName -resourceId "shared-managed-identity" -SUBSCRIPTION $SUBSCRIPTION -TENANT $TENANT
$sp = az identity show -g $fsp.GroupName -n $fsp.Name | ConvertFrom-Json
$kv = GetResource -solutionId $solutionId -environmentName $environmentName -resourceId "shared-key-vault" -SUBSCRIPTION $SUBSCRIPTION -TENANT $TENANT

$groupName = "shared-key-vault Secrets Admins"
$groups = az ad group list --display-name $groupName | ConvertFrom-Json
if ($groups.Length -eq 0) {
    $result = az ad group create --display-name $groupName --mail-nickname "shared-key-vault-secrets-admin" | ConvertFrom-Json
    if ($LastExitCode -ne 0) {
        Pop-Location
        throw "Unable to create group $groupName."
    }
    $groupId = $result.id
}
else {
    $groupId = $groups.id
}

az role assignment create --assignee $groupId --role "Key Vault Secrets Officer" --scope $kv.ResourceId

$acr = GetResource -solutionId $solutionId -environmentName $environmentName -resourceId "shared-container-registry" -SUBSCRIPTION $SUBSCRIPTION -TENANT $TENANT
az role assignment create --assignee $sp.principalId --role "Key Vault Secrets User" --scope $kv.ResourceId
if ($LastExitCode -ne 0) {
    Pop-Location
    throw "Unable to assign 'Key Vault Secrets User' role."
}

az role assignment create --assignee $sp.principalId --role "AcrPull" --scope $acr.ResourceId
if ($LastExitCode -ne 0) {
    Pop-Location
    throw "Unable to assign 'AcrPull' role."
}

asm role assign --role-name "Reader" `
    --principal-id $ghgroups.id `
    --principal-type "Group" `
    --asm-sol $solutionId `
    --asm-env $environmentName `
    -s $SUBSCRIPTION `
    -t $TENANT --logging Info

if ($LastExitCode -ne 0) {
    Pop-Location
    throw "Unable to assign 'Reader' role."
}

asm role assign --role-name "Managed Identity Operator" `
    --principal-id $ghgroups.id `
    --principal-type "Group" `
    --asm-sol $solutionId `
    --asm-env $environmentName `
    -s $SUBSCRIPTION `
    -t $TENANT --logging Info

if ($LastExitCode -ne 0) {
    Pop-Location
    throw "Unable to assign 'Managed Identity Operator' role."
}
<#
.SYNOPSIS
Builds and pushes a Docker image to Azure Container Registry (ACR), 
then updates an Azure Web App to use that image.

.DESCRIPTION
1. Checks if user is logged into Azure and confirms subscription.
2. Reads UNIQUE_APP_NAME from the .env file to identify resources.
3. Builds/pushes a container image (via ACR tasks).
4. Configures the Web App's container settings to point to this new image.
5. Restarts the Web App so changes take effect.

.PARAMETER EnvFile
Path to the .env file (defaults to "./.env").

.PARAMETER ResourceGroupLocation
Azure region used for resource group. Must match the region used during infra deployment.
Defaults to "eastus".
#>

Param(
    [string]$EnvFile = "./.env",
    [string]$ResourceGroupLocation = "eastus"
)

# ----------------------------------------------------------------------------------------
# 0. Check Azure Login and Subscription
# ----------------------------------------------------------------------------------------
# This section checks that you are authenticated to Azure and have the right subscription set.

$accountInfo = az account show --query "{name:name, id:id}" -o json 2>$null | ConvertFrom-Json
if (-not $accountInfo) {
    Write-Host "You are not logged in to Azure. Please log in and set the subscription you want to use." -ForegroundColor Red
    Write-Host "Run the following commands to log in and set your subscription:"
    Write-Host "  az login"
    Write-Host "  az account set --subscription <subscription-id>"
    exit 1
}

Write-Host "You are currently logged in with the following subscription:" -ForegroundColor Yellow
Write-Host "  Subscription Name: $($accountInfo.name)"
Write-Host "  Subscription ID:   $($accountInfo.id)"
Write-Host ""

$confirmation = Read-Host "Do you want to continue with this subscription? (yes/no)"
if ($confirmation -notin @("yes", "y", "Yes", "Y")) {
    Write-Host "Exiting. To change the subscription, use the following command:" -ForegroundColor Cyan
    Write-Host "  az account set --subscription <subscription-id>"
    exit 1
}
Write-Host "Continuing with subscription: $($accountInfo.name) ($($accountInfo.id))" -ForegroundColor Green

# ----------------------------------------------------------------------------------------
# 1. Helper Function
# ----------------------------------------------------------------------------------------

# Function to check the last exit code and print an error message if it's not 0
function Check-LastExitCode {
    Param([string]$ErrorMessage)
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: $ErrorMessage" -ForegroundColor Red
        exit 1
    }
}

# Function to get the value of an environment variable from a .env file         
function Get-EnvValue {
    Param(
        [string]$FilePath,
        [string]$KeyName
    )
    if (-not (Test-Path $FilePath)) {
        Write-Host "Error: .env file not found at '$FilePath'." -ForegroundColor Red
        exit 1
    }
    $content = Get-Content $FilePath -Raw
    $valueLine = ($content -split "`n" | Where-Object { $_ -match "^$KeyName=" })
    if (-not $valueLine) {
        return $null
    }
    # Strip the key name plus quotes/spaces
    $parsedValue = $valueLine -replace "^$KeyName=", "" | ForEach-Object { $_.Trim().Replace('"','') }
    return $parsedValue
}

# ----------------------------------------------------------------------------------------
# 2. Retrieve App Name from .env
# ----------------------------------------------------------------------------------------

# Check if the .env file exists
if (-not (Test-Path $EnvFile)) {
    Write-Host "Error: .env file not found at '$EnvFile'." -ForegroundColor Red
    exit 1
}

# Get the UNIQUE_APP_NAME from the .env file
$rawAppName = Get-EnvValue -FilePath $EnvFile -KeyName "UNIQUE_APP_NAME"
if (-not $rawAppName) {
    Write-Host "Error: UNIQUE_APP_NAME is not defined in the .env file." -ForegroundColor Red
    exit 1
}

# Clean up the app name
$uniqueAppName         = $rawAppName.ToLower().Trim() -replace '"',''
$uniqueAppNameNoDashes = $uniqueAppName -replace '-', ''

# By convention, we use the same resource group name as the app name
$resourceGroupName = $uniqueAppName
$acrName           = $uniqueAppNameNoDashes

# Our container image name follows the pattern below
$containerImage    = "$($acrName).azurecr.io/$($uniqueAppName)-container:latest"

# ----------------------------------------------------------------------------------------
# 3. Build & Push the Container Image to ACR
# ----------------------------------------------------------------------------------------
Write-Host "Building and pushing container image '$containerImage' to ACR '$acrName'..."
az acr build --registry $acrName --resource-group $resourceGroupName --image $containerImage .
Check-LastExitCode "Failed to build and push the container image to ACR '$acrName'."

Write-Host "Container image '$containerImage' built and pushed successfully." -ForegroundColor Green

# ----------------------------------------------------------------------------------------
# 4. Configure the Azure Web App to Use This Container
# ----------------------------------------------------------------------------------------
Write-Host "Configuring App Service '$uniqueAppName' to use container image '$containerImage'..."

# Retrieve ACR credentials
$acrPassword = az acr credential show --name $acrName --query "passwords[0].value" -o tsv
Check-LastExitCode "Failed to retrieve ACR credentials for '$acrName'."

# Set the container for the App Service
az webapp config container set `
    --name $uniqueAppName `
    --resource-group $resourceGroupName `
    --container-image-name $containerImage `
    --container-registry-url "https://$($acrName).azurecr.io" `
    --container-registry-user $acrName `
    --container-registry-password $acrPassword
Check-LastExitCode "Failed to configure the App Service to use the container image."
Write-Host "App Service '$uniqueAppName' is now set to use the container image." -ForegroundColor Green

# ----------------------------------------------------------------------------------------
# 5. Restart the App Service to Apply Changes
# ----------------------------------------------------------------------------------------
Write-Host "Restarting App Service '$uniqueAppName'..."
az webapp restart --name $uniqueAppName --resource-group $resourceGroupName
Check-LastExitCode "Failed to restart App Service '$uniqueAppName'."

Write-Host "App Service '$uniqueAppName' restarted successfully." -ForegroundColor Green

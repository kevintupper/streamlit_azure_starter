<#
.SYNOPSIS
Deploys or updates Azure infrastructure (Resource Group, ACR, App Service, etc.)
and configures an Azure AD App Registration. Updates .env with generated secrets.

.DESCRIPTION
1. Checks if user is logged into Azure and confirms subscription.
2. Reads UNIQUE_APP_NAME (and optional config) from .env.
3. Creates/Updates:
   - Resource Group
   - Container Registry (ACR)
   - App Service Plan
   - App Service (Linux Container)
   - Azure AD App Registration (client ID & secret)
   - Storage Account
4. Writes the new or updated credentials (Client ID, Client Secret, Tenant ID, 
   storage account keys) back into the .env file.

.PARAMETER ResourceGroupLocation
Azure region for all resources (defaults to "eastus").

.PARAMETER EnvFile
Path to the .env file (defaults to "./.env").

.PARAMETER AppTenantType
Azure AD tenant type: "single" (AzureADMyOrg) or "multi" (AzureADMultipleOrgs). 
Default is "multi".
#>

Param(
    [string]$ResourceGroupLocation = "eastus",
    [string]$EnvFile = "./.env",
    [string]$AppTenantType = "multi"
)

# ----------------------------------------------------------------------------------------
# 0. Check Azure Login and Subscription
# ----------------------------------------------------------------------------------------
# This section checks that you are authenticated to Azure and have the right subscription set.
# If you're not logged in or want to switch subscriptions, follow the prompts.

# Check if the user is logged in to Azure
$accountInfo = az account show --query "{name:name, id:id}" -o json 2>$null | ConvertFrom-Json
if (-not $accountInfo) {
    Write-Host "You are not logged in to Azure. Please log in and set the subscription you want to use." -ForegroundColor Red
    Write-Host "Run the following commands to log in and set your subscription:"
    Write-Host "  az login"
    Write-Host "  az account set --subscription <subscription-id>"
    exit 1
}

# Display the current subscription details
Write-Host "You are currently logged in with the following subscription:" -ForegroundColor Yellow
Write-Host "  Subscription Name: $($accountInfo.name)"
Write-Host "  Subscription ID:   $($accountInfo.id)"
Write-Host ""

# Prompt the user to confirm or exit
$confirmation = Read-Host "Do you want to continue with this subscription? (yes/no)"
if ($confirmation -notin @("yes", "y", "Yes", "Y")) {
    Write-Host "Exiting. To change the subscription, use the following command:" -ForegroundColor Cyan
    Write-Host "  az account set --subscription <subscription-id>"
    exit 1
}
Write-Host "Continuing with subscription: $($accountInfo.name) ($($accountInfo.id))" -ForegroundColor Green

# ----------------------------------------------------------------------------------------
# 1. Helper Functions
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
    # Strip key name plus any quotes/spaces
    $parsedValue = $valueLine -replace "^$KeyName=", "" | ForEach-Object { $_.Trim().Replace('"','') }
    return $parsedValue
}

# Function to set the value of an environment variable in a .env file
function Set-EnvValue {
    Param(
        [string]$FilePath,
        [string]$KeyName,
        [string]$NewValue
    )
    if (-not (Test-Path $FilePath)) {
        Write-Host "Error: .env file not found at '$FilePath'." -ForegroundColor Red
        exit 1
    }
    $envContent = Get-Content $FilePath
    if ($envContent -match "^$KeyName=") {
        # Replace existing line
        $envContent = $envContent -replace "^$KeyName=.*", "$KeyName=`"$NewValue`""
    }
    else {
        # Append new line
        $envContent += "`r`n$KeyName=`"$NewValue`""
    }
    $envContent | Set-Content $FilePath
}

# Function to resolve the sign-in audience based on the AppTenantType
function Resolve-SignInAudience {
    Param([string]$AppTenantType)
    switch ($AppTenantType) {
        "multi"  { return "AzureADMultipleOrgs" }
        "single" { return "AzureADMyOrg" }
        default  {
            Write-Host "Error: Invalid value for AppTenantType. Use 'single' or 'multi'." -ForegroundColor Red
            exit 1
        }
    }
}

# ----------------------------------------------------------------------------------------
# 2. Read .env and Prepare Resource Names
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

# Clean up the app name for resource naming
$uniqueAppName         = $rawAppName.ToLower().Trim() -replace '"',''
$uniqueAppNameNoDashes = $uniqueAppName -replace '-', ''

# Construct resource names
$resourceGroupName   = $uniqueAppName
$appServicePlanName  = "$uniqueAppName-app-plan"
$appServiceName      = $uniqueAppName
$appRegistrationName = "$uniqueAppName-app-reg"
$acrName             = $uniqueAppNameNoDashes
$storageAccountName  = $uniqueAppNameNoDashes

# Container image name for reference in App Service
$containerImage = "$acrName.azurecr.io/$uniqueAppName-container:latest"

# Tenant type => sign-in audience
$signInAudience = Resolve-SignInAudience -AppTenantType $AppTenantType

# Typically for local dev and Azure-based usage
$redirectUris = @(
    "http://localhost:8000",
    "http://localhost:8501",
    "https://$uniqueAppName.azurewebsites.net"
)

# ----------------------------------------------------------------------------------------
# 3. Create or Validate Azure Resources
# ----------------------------------------------------------------------------------------

# 3.1 Check if Resource Group exists; create if needed
$rgExists = az group exists --name $resourceGroupName | ConvertFrom-Json
if (-not $rgExists) {
    az group create --name $resourceGroupName --location $ResourceGroupLocation --output none
    Check-LastExitCode "Failed to create Resource Group '$resourceGroupName'."
    Write-Host "Resource Group '$resourceGroupName' created successfully."
}
else {
    Write-Host "Resource Group '$resourceGroupName' already exists."
}

# 3.2 Create or check Azure Container Registry (ACR)
$acrExists = az acr show --name $acrName --resource-group $resourceGroupName --query "name" --output tsv 2>$null
if (-not $acrExists) {
    az acr create --name $acrName --resource-group $resourceGroupName --sku Basic --location $ResourceGroupLocation --output none
    Check-LastExitCode "Failed to create ACR '$acrName'."
    Write-Host "Azure Container Registry '$acrName' created."
}
else {
    Write-Host "Azure Container Registry '$acrName' already exists."
}

# Enable admin user for ACR so we can push images
az acr update --name $acrName --admin-enabled true --output none
Check-LastExitCode "Failed to enable admin user for ACR '$acrName'."
Write-Host "Admin user enabled for ACR '$acrName'."

# Fetch ACR credentials
$acrCredentials = az acr credential show `
    --name $acrName `
    --resource-group $resourceGroupName `
    --query "{username:username, password:passwords[0].value}" -o json | ConvertFrom-Json
if (-not $acrCredentials) {
    Write-Host "Error: Failed to retrieve ACR credentials for '$acrName'." -ForegroundColor Red
    exit 1
}
Write-Host "ACR credentials retrieved."

# 3.3 Create or check App Service Plan
$appServicePlanExists = az appservice plan show --name $appServicePlanName --resource-group $resourceGroupName --query "name" -o tsv 2>$null
if (-not $appServicePlanExists) {
    az appservice plan create --name $appServicePlanName --resource-group $resourceGroupName --sku B3 --is-linux --output none
    Check-LastExitCode "Failed to create App Service Plan '$appServicePlanName'."
    Write-Host "App Service Plan '$appServicePlanName' created."
}
else {
    Write-Host "App Service Plan '$appServicePlanName' already exists."
}

# 3.4 Create or check App Service (Linux Container)
$appServiceExists = az webapp show --name $appServiceName --resource-group $resourceGroupName --query "name" -o tsv 2>$null
if (-not $appServiceExists) {
    az webapp create `
        --name $appServiceName `
        --resource-group $resourceGroupName `
        --plan $appServicePlanName `
        --container-image-name $containerImage `
        --container-registry-url "https://$acrName.azurecr.io" `
        --container-registry-user $acrCredentials.username `
        --container-registry-password $acrCredentials.password `
        --output none
    Check-LastExitCode "Failed to create Linux App Service '$appServiceName'."
    Write-Host "Linux App Service '$appServiceName' created."
}
else {
    Write-Host "Linux App Service '$appServiceName' already exists."
}

# ----------------------------------------------------------------------------------------
# 4. Configure Azure AD App Registration
# ----------------------------------------------------------------------------------------

# 4.1 Check if the Azure AD App Registration exists; create or update
$appRegistration = az ad app list --display-name $appRegistrationName --query "[0]" -o json | ConvertFrom-Json
if (-not $appRegistration) {
    $appRegistration = az ad app create `
        --display-name $appRegistrationName `
        --sign-in-audience $signInAudience `
        --query "{appId: appId}" -o json | ConvertFrom-Json
    Check-LastExitCode "Failed to create App Registration '$appRegistrationName'."
    Write-Host "App Registration '$appRegistrationName' created with App ID: $($appRegistration.appId)."
}
else {
    Write-Host "App Registration '$appRegistrationName' already exists with App ID: $($appRegistration.appId)."
    az ad app update --id $appRegistration.appId --sign-in-audience $signInAudience --output none
    Check-LastExitCode "Failed to update the sign-in audience for '$appRegistrationName'."
    Write-Host "Sign-in audience updated to $signInAudience."
}

# 4.2 Get the Tenant ID
$tenantId = az account show --query "tenantId" -o tsv
if (-not $tenantId) {
    Write-Host "Error: Failed to retrieve the Tenant ID." -ForegroundColor Red
    exit 1
}
Write-Host "Tenant ID retrieved: $tenantId"

# 4.3 Create a client secret for this registration
$clientSecret = az ad app credential reset `
    --id $appRegistration.appId `
    --query "password" -o tsv
Check-LastExitCode "Failed to create client secret for '$appRegistrationName'."
Write-Host "Client secret created."

# 4.4 Update redirect URIs
az ad app update --id $appRegistration.appId --web-redirect-uris $redirectUris --output none
Check-LastExitCode "Failed to update redirect URIs."
Write-Host "Redirect URIs updated for '$appRegistrationName'."

# 4.5 Store the new credentials in .env
Set-EnvValue -FilePath $EnvFile -KeyName "APP_CLIENT_ID"     -NewValue $($appRegistration.appId)
Set-EnvValue -FilePath $EnvFile -KeyName "APP_CLIENT_SECRET" -NewValue $clientSecret
Set-EnvValue -FilePath $EnvFile -KeyName "APP_TENANT_ID"     -NewValue $tenantId

# ----------------------------------------------------------------------------------------
# 5. Create or Check Storage Account
# ----------------------------------------------------------------------------------------

# 5.1 Check if the storage account exists; create if needed
$storageAccountExists = az storage account show --name $storageAccountName --resource-group $resourceGroupName --query "name" -o tsv 2>$null
if (-not $storageAccountExists) {
    az storage account create `
        --name $storageAccountName `
        --resource-group $resourceGroupName `
        --location $ResourceGroupLocation `
        --sku Standard_LRS `
        --output none
    Check-LastExitCode "Failed to create the storage account '$storageAccountName'."
    Write-Host "Storage account '$storageAccountName' created."
}
else {
    Write-Host "Storage account '$storageAccountName' already exists."
}

# 5.2 Retrieve the storage account key
$storageAccountKey = az storage account keys list `
    --account-name $storageAccountName `
    --resource-group $resourceGroupName `
    --query "[0].value" -o tsv
Check-LastExitCode "Failed to retrieve storage account key."

# 5.3 Retrieve the storage account connection string
$storageConnectionString = az storage account show-connection-string `
    --name $storageAccountName `
    --resource-group $resourceGroupName `
    --query "connectionString" -o tsv
Check-LastExitCode "Failed to retrieve storage account connection string."

# 5.4 Store the storage account name, key, and connection string in the .env file
Set-EnvValue -FilePath $EnvFile -KeyName "STORAGE_ACCOUNT_NAME"      -NewValue $storageAccountName
Set-EnvValue -FilePath $EnvFile -KeyName "STORAGE_ACCOUNT_KEY"       -NewValue $storageAccountKey
Set-EnvValue -FilePath $EnvFile -KeyName "STORAGE_CONNECTION_STRING" -NewValue $storageConnectionString

# ----------------------------------------------------------------------------------------
# If you have any additional resources to create, add them here.
# ----------------------------------------------------------------------------------------
    

# ----------------------------------------------------------------------------------------
# X. Summary
# ----------------------------------------------------------------------------------------
Write-Host "`nDeployment completed successfully." -ForegroundColor Green
Write-Host "Resource Group:           $resourceGroupName"
Write-Host "App Service:              $appServiceName"
Write-Host "App Service Plan:         $appServicePlanName"
Write-Host "Azure Container Registry: $acrName"
Write-Host "App Registration:         $appRegistrationName"
Write-Host "Storage Account:          $storageAccountName"

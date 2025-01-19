# deploy-infra.ps1
# ---------------------------------------------------------------------------------------------
# Script to deploy Azure infrastructure, including app registration, and
# integration with Azure App Service using Managed Identity. It also creates ACR, 
# App Service Plan, and App Service for containerized applications.
#
# You are free to modify this script to suit your specific requirements and add additional 
# resources as needed.
#
# This script is designed to be idempotent, meaning it can be safely re-run without causing 
# errors or duplicating resources.
# ---------------------------------------------------------------------------------------------


# ---------------------------------------------------------------------------------------------
# Define deployment parameters
# ---------------------------------------------------------------------------------------------

# Location of the resource group
$resourceGroupLocation = "eastus"         # Azure region (e.g., eastus, westus, etc.)

# Path to the .env file
$envfile = "./.env"                       # Path to the .env file

# Get the unique app name from the .env file (UNIQUE_APP_NAME)
if (Test-Path $envFile) {
    $envContent = Get-Content $envFile -Raw
    $uniqueAppName = ($envContent -split "`n" | Where-Object { $_ -match "^UNIQUE_APP_NAME=" }) -replace "^UNIQUE_APP_NAME=", ""
    # Remove quotes, newlines, and leading/trailing spaces
    $uniqueAppName = $uniqueAppName.Trim() -replace '"', ''
    if (-not $uniqueAppName) {
        Write-Host "Error: UNIQUE_APP_NAME is not defined in the .env file." -ForegroundColor Red
        exit 1
    }
    # Convert to lowercase
    $uniqueAppName = $uniqueAppName.ToLower()
    # Remove any dashes from the unique app name
    $uniqueAppNameNoDashes = $uniqueAppName.Replace("-", "")
} else {
    Write-Host "Error: .env file not found." -ForegroundColor Red
    exit 1
}

# Define resource names using the unique app name
$resourceGroupName = "$uniqueAppName"                    # Azure Container Registry name
$appName = "$uniqueAppName"                              # Resource group name
$acrName = "$uniqueAppNameNoDashes"                      # App name as unique app name
$appServicePlanName = "$uniqueAppName-app-plan"          # App Service Plan name
$appServiceName = "$uniqueAppName"                       # App Service name (updated to match app name)
$appRegistrationName = "$uniqueAppName-app-reg"          # App Registration name with unique app name
$storageAccountName = "$uniqueAppNameNoDashes"           # Storage account name (must be globally unique and not contain dashes)

# Define the Web Redirect URIs
$redirectUris = @(
    "http://localhost:8000",                             # URI allows for local development and testing
    "http://localhost:8501",                             # URI allows for local development and testing
    "https://$uniqueAppName.azurewebsites.net"           # Updated URI for application deployment
)

# Use the unique app name as the container image name
$containerImage = "$acrName.azurecr.io/$uniqueAppName-container:latest"

# ---------------------------------------------------------------------------------------------
# Log in to Azure
# ---------------------------------------------------------------------------------------------
az login --output none
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Azure login failed." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------------------------
# Create the resource group
# ---------------------------------------------------------------------------------------------
$resourceGroupExists = az group exists --name $resourceGroupName | ConvertFrom-Json
if (-not $resourceGroupExists) {
    az group create --name $resourceGroupName --location $resourceGroupLocation --output none
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Resource group '$resourceGroupName' created successfully."
    } else {
        Write-Host "Error: Failed to create the resource group." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Resource group '$resourceGroupName' already exists."
}

# ---------------------------------------------------------------------------------------------
# Create the Azure Container Registry
# ---------------------------------------------------------------------------------------------
$acrExists = az acr show --name $acrName --resource-group $resourceGroupName --query "name" --output tsv 2>$null
if (-not $acrExists) {
    az acr create --name $acrName --resource-group $resourceGroupName --sku Basic --location $resourceGroupLocation --output none
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Azure Container Registry '$acrName' created."
    } else {
        Write-Host "Error: Failed to create the Azure Container Registry." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Azure Container Registry '$acrName' already exists."
}

# Enable admin user for ACR
az acr update --name $acrName --admin-enabled true --output none
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to enable admin user for ACR '$acrName'." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Admin user enabled for ACR '$acrName'."
}

# Retrieve ACR credentials
$acrCredentials = az acr credential show --name $acrName --resource-group $resourceGroupName --query "{username:username, password:passwords[0].value}" --output json | ConvertFrom-Json

if (-not $acrCredentials) {
    Write-Host "Error: Failed to retrieve ACR credentials for '$acrName'." -ForegroundColor Red
    exit 1
}


# ---------------------------------------------------------------------------------------------
# Create the App Service Plan
# ---------------------------------------------------------------------------------------------
$appServicePlanExists = az appservice plan show --name $appServicePlanName --resource-group $resourceGroupName --query "name" --output tsv 2>$null
if (-not $appServicePlanExists) {
    az appservice plan create --name $appServicePlanName --resource-group $resourceGroupName --sku B3 --is-linux --output none
    if ($LASTEXITCODE -eq 0) {
        Write-Host "App Service Plan '$appServicePlanName' created."
    } else {
        Write-Host "Error: Failed to create the App Service Plan." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "App Service Plan '$appServicePlanName' already exists."
}

# ---------------------------------------------------------------------------------------------
# Create the App Service
# ---------------------------------------------------------------------------------------------
$appServiceExists = az webapp show --name $appServiceName --resource-group $resourceGroupName --query "name" --output tsv 2>$null
if (-not $appServiceExists) {
    az webapp create --name $appServiceName `
                     --resource-group $resourceGroupName `
                     --plan $appServicePlanName `
                     --container-image-name $containerImage `
                     --container-registry-url "https://$acrName.azurecr.io" `
                     --container-registry-user $acrCredentials.username `
                     --container-registry-password $acrCredentials.password `
                     --output none
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Linux App Service '$appServiceName' created successfully."
    } else {
        Write-Host "Error: Failed to create the Linux App Service." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Linux App Service '$appServiceName' already exists."
}

# ---------------------------------------------------------------------------------------------
# Enable continuous deployment (optional)
# ---------------------------------------------------------------------------------------------
# If you want to enable continuous deployment from ACR, uncomment the following lines:
# az webapp deployment container config `
#     --name $appServiceName `
#     --resource-group $resourceGroupName `
#     --enable-cd true `
#     --output none

# if ($LASTEXITCODE -eq 0) {
#     Write-Host "Continuous deployment enabled for App Service '$appServiceName'."
# } else {
#     Write-Host "Error: Failed to enable continuous deployment for App Service." -ForegroundColor Red
#     exit 1
# }

# ---------------------------------------------------------------------------------------------
# Register the app in Azure AD
# ---------------------------------------------------------------------------------------------
$appRegistration = az ad app list --display-name $appRegistrationName --query "[0]" -o json | ConvertFrom-Json
if (-not $appRegistration) {
    $appRegistration = az ad app create --display-name $appRegistrationName --query "{appId: appId}" -o json | ConvertFrom-Json
    if ($LASTEXITCODE -eq 0) {
        Write-Host "App Registration '$appRegistrationName' created with App ID: $($appRegistration.appId)."
    } else {
        Write-Host "Error: Failed to create the App Registration." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "App Registration '$appRegistrationName' already exists with App ID: $($appRegistration.appId)."
}

# Explicitly display the full name of the App Registration
Write-Host "App Registration Name: $appRegistrationName"

# Retrieve the Tenant ID
$tenantId = az account show --query "tenantId" -o tsv
if (-not $tenantId) {
    Write-Host "Error: Failed to retrieve the Tenant ID." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Tenant ID retrieved: $tenantId"
}

# ---------------------------------------------------------------------------------------------
# Create a client secret for the app registration
# ---------------------------------------------------------------------------------------------
$clientSecret = az ad app credential reset --id $appRegistration.appId --query "password" -o tsv
if ($LASTEXITCODE -eq 0) {
    Write-Host "Client secret created for App Registration '$appRegistrationName'."
} else {
    Write-Host "Error: Failed to create a client secret for the App Registration." -ForegroundColor Red
    exit 1
}


# ---------------------------------------------------------------------------------------------
# Update the app registration with the redirect URIs
# ---------------------------------------------------------------------------------------------
az ad app update --id $appRegistration.appId --web-redirect-uris $redirectUris --output none

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to update Web Redirect URIs for App Registration." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Web Redirect URIs updated for App Registration '$appRegistrationName'."
}


# ---------------------------------------------------------------------------------------------
# Store app registration keys in .env file
# ---------------------------------------------------------------------------------------------
# Store app registration keys env
if (Test-Path $envfile) {
    $envfileContent = Get-Content $envfile
    $envfileContent = $envfileContent -replace "^APP_CLIENT_ID=.*", "APP_CLIENT_ID=`"$($appRegistration.appId)`""
    $envfileContent = $envfileContent -replace "^APP_CLIENT_SECRET=.*", "APP_CLIENT_SECRET=`"$clientSecret`""
    $envfileContent = $envfileContent -replace "^APP_TENANT_ID=.*", "APP_TENANT_ID=`"$tenantId`""
    $envfileContent | Set-Content $envfile
} else {
    Write-Host "Error: .env file not found." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------------------------
# Add additional resources here
# ---------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------
# For example, create the storage account
# ---------------------------------------------------------------------------------------------
# $storageAccountExists = az storage account show --name $storageAccountName --resource-group $resourceGroupName --query "name" --output tsv 2>$null
# if (-not $storageAccountExists) {
#     az storage account create --name $storageAccountName --resource-group $resourceGroupName --location $resourceGroupLocation --sku Standard_LRS --output none
#     if ($LASTEXITCODE -eq 0) {
#         Write-Host "Storage account '$storageAccountName' created."
#     } else {
#         Write-Host "Error: Failed to create the storage account." -ForegroundColor Red
#         exit 1
#     }
# } else {
#     Write-Host "Storage account '$storageAccountName' already exists."
# }


# ---------------------------------------------------------------------------------------------
# Output the deployment summary
# ---------------------------------------------------------------------------------------------
Write-Host "Deployment completed successfully." -ForegroundColor Green
Write-Host "Resource group: $resourceGroupName"
Write-Host "App Service: $appServiceName"
Write-Host "App Service Plan: $appServicePlanName"
Write-Host "Azure Container Registry: $acrName"
Write-Host "App Registration: $appRegistrationName"

# Add additional resource output here
# Write-Host "Storage Account: $storageAccountName"

# Path to your .env file
$envFile = ".\.env"

# Resource group location (must match the location in deploy-infra.ps1)
$resourceGroupLocation = "eastus"

# ---------------------------------------------------------------------------------------------
# Get the unique app name from the .env file (UNIQUE_APP_NAME)
# ---------------------------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------------------------
# Define resource names using the unique app name
# ---------------------------------------------------------------------------------------------
$resourceGroupName = "$uniqueAppName"                                        # Resource group name
$acrName = "$uniqueAppNameNoDashes"                                          # Azure Container Registry name
$containerImage = "$acrName.azurecr.io/$uniqueAppName-container:latest"      # Container image name

# ---------------------------------------------------------------------------------------------
# Build and push the container image to Azure Container Registry
# ---------------------------------------------------------------------------------------------
Write-Host "Building and pushing container image '$containerImage' to Azure Container Registry '$acrName'..."

az acr build --registry $acrName --resource-group $resourceGroupName --image $containerImage .

if ($LASTEXITCODE -eq 0) {
    Write-Host "Container image '$containerImage' successfully built and pushed to ACR '$acrName'." -ForegroundColor Green
} else {
    Write-Host "Error: Failed to build and push the container image to ACR '$acrName'." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------------------------
# Configure the App Service to use the container image
# ---------------------------------------------------------------------------------------------
Write-Host "Configuring App Service to use the container image '$containerImage'..."

az webapp config container set `
    --name $uniqueAppName `
    --resource-group $resourceGroupName `
    --container-image-name $containerImage `
    --container-registry-url "https://$acrName.azurecr.io" `
    --container-registry-user $acrName `
    --container-registry-password (az acr credential show --name $acrName --query "passwords[0].value" -o tsv)

if ($LASTEXITCODE -eq 0) {
    Write-Host "App Service '$uniqueAppName' successfully configured to use the container image." -ForegroundColor Green
} else {
    Write-Host "Error: Failed to configure the App Service to use the container image." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------------------------
# Restart the App Service to apply the changes
# ---------------------------------------------------------------------------------------------
Write-Host "Restarting App Service '$uniqueAppName' to apply the container configuration..."

az webapp restart --name $uniqueAppName --resource-group $resourceGroupName

if ($LASTEXITCODE -eq 0) {
    Write-Host "App Service '$uniqueAppName' successfully restarted." -ForegroundColor Green
} else {
    Write-Host "Error: Failed to restart the App Service." -ForegroundColor Red
    exit 1
}

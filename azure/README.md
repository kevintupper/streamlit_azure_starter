# Azure Deployment Instructions

This directory contains PowerShell scripts to automate deployment of the required Azure infrastructure and the Streamlit application container. 

---

## Contents

1. [Prerequisites](#prerequisites)
2. [Infrastructure Deployment](#infrastructure-deployment)
3. [Application Deployment](#application-deployment)
4. [Post-Deployment Verification](#post-deployment-verification)


## Prerequisites

1. **Azure CLI**  
   - Install from the official docs: [Install Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli).

2. **PowerShell**  
   - The scripts are written for PowerShell. Use PowerShell 5.x or later on Windows, or [PowerShell Core](https://github.com/PowerShell/PowerShell) on other platforms.

3. **Environment File (`.env`)**  
   - A `.env` file must exist in the project root **before** running these scripts.  
   - Copy `template.env` to `.env` and adjust `UNIQUE_APP_NAME` and other variables as needed. See [ENVIRONMENT_SETUP.md](../ENVIRONMENT_SETUP.md) for details.

> **Note**  
> If `APP_CLIENT_ID`, `APP_CLIENT_SECRET`, and `APP_TENANT_ID` in your `.env` are left empty or placeholder values, they will be automatically generated/overwritten during **infrastructure** deployment.


## Infrastructure Deployment

Use the `deploy-infra.ps1` script to create or update:

- **Resource Group**  
- **Azure Container Registry (ACR)**  
- **App Service Plan**  
- **App Service**  
- **Storage Account**  
- **Azure AD App Registration** (with secret)

### Run the Script

From the repository root:

```powershell
.\azure\deploy-infra.ps1
```

**Optional Parameters:**

- -EnvFile "./.env" — specify an alternate path to the .env file.

- -ResourceGroupLocation "eastus" — deploy resources to a different region.

- -AppTenantType "single" — restrict the AAD registration to single-tenant. Default is multi.

**Common Issues**

- Cannot find .env

    Ensure your .env is in the repository root and accessible.

- Azure login fails

    Make sure you have the Azure CLI installed and are logged in with az login.

## Application Deployment

    Once the infrastructure is set, you can build and push the Docker image to Azure Container Registry (ACR) and configure the Azure Web App with the deploy-app.ps1 script.

**Run the Script**

From the repository root:

```powershell
.\azure\deploy-app.ps1
```

**Optional Parameters:**

- -EnvFile "./.env" — specify a custom .env location.
- -ResourceGroupLocation "eastus" — must match the location used in infrastructure deployment.

**What It Does:**

1. Reads the UNIQUE_APP_NAME from .env.
2. Builds the Docker image via ACR and pushes it to your registry.
3. Sets the container image in the Azure App Service.
4. Restarts the App Service to apply changes.

## Post-Deployment Verification

1. Check Azure Portal

- Go to portal.azure.com to see the resource group and resources (App Service, Container Registry, Storage Account).

- Under **App Registrations** in Azure AD, confirm the newly created/updated Azure AD application.

2. Test the App

- After the *deploy-app.ps1* script completes, note the app’s URL, typically:
```
https://<UNIQUE_APP_NAME>.azurewebsites.net
```

- Open that URL in your browser. You should see your Streamlit application. If authentication is configured, you’ll be prompted to log in.

3. Logs

- Check Web App logs from the Azure Portal or via CLI to ensure the container started correctly.
<!-- omit in toc -->
# **Streamlit Starter App on Azure**

<!-- omit in toc -->
## Contents

- [Overview](#overview)
- [Template](#template)
- [Infrastructure Deployment](#infrastructure-deployment)
  - [What `deploy-infra.ps1` Does](#what-deploy-infraps1-does)
  - [Steps to Deploy Infrastructure](#steps-to-deploy-infrastructure)
- [Environment File (.env)](#environment-file-env)
- [Project Structure](#project-structure)
- [Running the App Locally](#running-the-app-locally)
- [Deployment to Azure](#deployment-to-azure)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Overview

**Streamlit Starter App on Azure** is a lightweight template for deploying secure, multi-page Streamlit applications on Azure. Designed for proofs-of-concept, prototypes, and internal tools, this template simplifies the deployment process while following best practices for scalability.

Key features include:

- **Secure authentication** with Entra ID.
- **Infrastructure deployment** using a single PowerShell script.
- **Async support** for integrating frameworks like **AutoGen** and **Semantic Kernel**, enabling advanced workflows and AI-driven applications.

The app is deployed as an Azure Container App, making it easy to scale and manage. This template is ideal for individual developers or small teams building internal tools, demo applications, or AI-powered solutions.

## Template

This project provides a starter template for deploying a Streamlit app on Azure. The template includes:

- **Multi-page Streamlit app**: A modular structure for building scalable apps.
- **Infrastructure Deployment**: Use a **PowerShell script** to deploy Azure resources.

The template is designed to simplify the process of deploying Streamlit apps to Azure while following best practices for scalability and maintainability.

## Infrastructure Deployment

The infrastructure for this project is deployed using a **PowerShell script** located in the `azure/` folder. This script automates the creation of all necessary Azure resources for the app, ensuring a smooth and repeatable deployment process.

### What `deploy-infra.ps1` Does

The `deploy-infra.ps1` script performs the following tasks in order:

1. **Resource Group Creation**: Creates a resource group in the specified Azure region.
2. **Azure Container Registry (ACR)**: Sets up a container registry for storing and managing container images.
3. **App Service Plan and App Service**: Deploys a Linux-based App Service Plan and an App Service for hosting the containerized Streamlit app.
4. **App Registration**: Registers the app in Azure Active Directory (AAD) for secure authentication and generates a client secret.
5. **Update Redirect URIs**: Updates the redirect URIs for the app registration.
6. **Environment File Updates**: Updates the `.env` file with the app's client ID, client secret, and tenant ID.

The script is idempotent, meaning it can be safely re-run without duplicating resources or causing errors. Developers can modify the script to add more resources or customize the deployment process as needed.

### Steps to Deploy Infrastructure

1. **Install Prerequisites**:
   - Install the [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli).
   - Ensure you have **PowerShell** installed on your system.

2. **Run the Deployment Script**:
   From the root of the project (where `deploy-infra.ps1` is located), run the PowerShell script:

   ```powershell
   .\azure\deploy-infra.ps1
   ```

   The script will:
   - Prompt you to log in to Azure.
   - Generate unique names for all resources based on the app acronym and Azure region.
   - Create and configure all required Azure resources.

3. **Verify Deployment**:
   You can verify the deployment by checking the Azure portal or using the Azure CLI:

   ```powershell
   az resource list --resource-group <resourceGroupName>
   ```

## Environment File (.env)

The `.env` file is used to store sensitive configuration values required by the application. These values are automatically updated by the `deploy-infra.ps1` script during the deployment process. See `template.env` for an example of the minimum required values.

**Important Notes:**

- The `deploy-infra.ps1` script will overwrite your `APP_CLIENT_ID`, `APP_CLIENT_SECRET`, and `APP_TENANT_ID` values during deployment. Ensure the `.env` file exists in the root directory before running the script.
- Do not share or commit the `.env` file to version control systems to avoid exposing sensitive information.

## Project Structure

The main files in the project are organized as follows:

```plaintext
root/
│   ├── app/                  # Streamlit app code  
│   │   ├── core/             # Core configuration and utilities
│   │   ├── pages/            # Additional Streamlit pages
│   │   ├── utils/            # Utility functions (e.g., API calls, data processing)
│   │   ├── main.py           # Main entry point for the Streamlit app
│   ├── azure/                # Azure-related code
│   │   ├── deploy-infra.ps1  # PowerShell script for deploying infrastructure
│   │   ├── deploy-app.ps1    # PowerShell script for deploying the app
│   ├── requirements.txt      # Python dependencies
│   ├── Dockerfile            # Dockerfile for building the Streamlit app container
│   ├── .env                  # Environment variables
│   ├── template.env          # Template for the .env file
│   ├── LICENSE               # License information
│   └── README.md             # Project documentation
```

## Running the App Locally

*To be completed.*

## Deployment to Azure

*To be completed.*

## Best Practices

*To be completed.*

## Troubleshooting

*To be completed.*

## License

This project is licensed under the [MIT License](LICENSE).

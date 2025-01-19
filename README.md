<!-- omit in toc -->
# **Streamlit Starter App on Azure**

<!-- omit in toc -->
## Contents

- [Overview](#overview)
- [Template](#template)
- [Environment File (.env)](#environment-file-env)
- [Project Structure](#project-structure)
- [Running the App Locally](#running-the-app-locally)
- [License](#license)

## Overview

**Streamlit Starter App on Azure** is a lightweight template for deploying secure, multi-page Streamlit applications on Azure. It is designed for **quick proofs-of-concept (POCs)**, **prototypes**, and **internal tools**, making it easy to deploy demo applications or AI-powered solutions. 

This template is **not enterprise-ready** but provides a solid foundation for small-scale projects or internal use cases.

Key features include:

- **Secure authentication** with Entra ID.
- **Infrastructure deployment** using a single PowerShell script.
- **Async support** for integrating frameworks like **AutoGen** and **Semantic Kernel**, enabling advanced workflows and AI-driven applications.

The app is deployed as a containerized Web App, making it easy to scale and manage.

## Template

This project provides a starter template for deploying a Streamlit app on Azure. The template includes:

- **Multi-page Streamlit app**: A modular structure for building scalable apps.
- **Infrastructure Deployment**: Use a **PowerShell script** to deploy Azure resources.

The template is designed to simplify the process of deploying Streamlit apps to Azure while following best practices for scalability and maintainability.

## Environment File (.env)

The `.env` file is used to store sensitive configuration values required by the application. It must exist in the root directory **before running the deployment scripts**, as the deployment process will modify specific values in the file.

**Important Notes:**

- The `deploy-infra.ps1` script will overwrite your `APP_CLIENT_ID`, `APP_CLIENT_SECRET`, and `APP_TENANT_ID` values during deployment. Ensure the `.env` file exists in the root directory before running the script.
- Do not share or commit the `.env` file to version control systems to avoid exposing sensitive information.
- See `template.env` for an example of the minimum required values.

## Deploy to Azure

This project uses two PowerShell scripts to deploy the infrastructure and the app to Azure. **Deploying to Azure is required to update the `.env` file with the necessary Entra ID settings, even for running the app locally.** The app validates security using Entra ID, so skipping this step is not recommended.

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
   - Update the `.env` file with the `APP_CLIENT_ID`, `APP_CLIENT_SECRET`, and `APP_TENANT_ID` values.

3. **Verify Deployment**:
   You can verify the deployment by checking the Azure portal or using the Azure CLI:

   ```powershell
   az resource list --resource-group <resourceGroupName>
   ```

### Steps to Deploy the App

1. Ensure the infrastructure is deployed and the `.env` file is updated with the required values.
2. Run the deployment script:

   ```powershell
   .\azure\deploy-app.ps1
   ```

3. Verify the deployment in the Azure portal. The app should now be accessible via the URL provided by the Azure App Service.

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

To run the app locally:

1. **Deploy to Azure First**: Ensure the infrastructure is deployed and the `.env` file is generated with the required Entra ID settings.
2. Install Python and dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Set up the `.env` file with the required values (generated during Azure deployment).

4. Run the app:
   ```bash
   streamlit run app/main.py
   ```

5. Open the app in your browser at `http://localhost:8501`.

## License

This project is licensed under the [MIT License](LICENSE).

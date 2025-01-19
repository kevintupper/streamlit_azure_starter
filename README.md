<!-- omit in toc -->
# **Streamlit Starter App on Azure**

<!-- omit in toc -->
## Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Environment Setup](#environment-setup)
- [Running the App Locally](#running-the-app-locally)
- [Deploying to Azure](#deploying-to-azure)
- [License](#license)

## Overview

**Streamlit Starter App on Azure** is a lightweight template for deploying **quick proofs-of-concept** and **demonstrations**. This template is not enterprise-ready and should not be used as a starting point for production applications. It is intended for demo applications running on Azure, secured with Entra ID, to restrict access to internal users or users from specific tenants. Deploy this in **non-production tenants only**.


Key features:
- **Secure authentication** with Entra ID (Azure AD).
- **Infrastructure-as-Code** for Azure resource deployment.
- **Container-based** deployment for easy management and scaling.
- **Async support** for advanced workflows or AI-driven apps.

## Project Structure

Below is a high-level outline of the repository:

```plaintext
streamlit_azure_starter/
│
├── app/
│   ├── core/               # Core auth, config, session mgmt
│   ├── pages/              # Additional Streamlit pages
│   ├── main.py             # Main entry for the Streamlit app
│   └── __init__.py
│
├── azure/
│   ├── deploy-infra.ps1    # PowerShell script to deploy Azure infrastructure
│   ├── deploy-app.ps1      # PowerShell script to build/push Docker image & deploy app
│   └── README.md           # Detailed instructions on deploying to Azure
│
├── .streamlit/
│   └── config.toml         # Streamlit config
│
├── environment.yml         # Conda environment config
├── requirements.txt        # Python dependencies
├── Dockerfile              # Dockerfile for building the container
├── template.env            # Template for environment variables
├── ENVIRONMENT_SETUP.md    # Instructions for configuring .env
├── LICENSE
└── README.md               # You are here
```

## Environment Setup

This project reads its settings from a file named .env in the project root. It should never be committed to version control.

1. Make a copy of template.env and rename it to .env.
2. Populate the .env file with your specific configuration values.
3. For more detailed explanations of each variable, refer to ENVIRONMENT_SETUP.md.

## Running the App Locally

> Important: If you plan to use Azure Entra ID for authentication, you’ll need to create or update your Azure resources to retrieve valid client/tenant IDs. The script in azure/deploy-infra.ps1 can automate this step and will modify your .env file with the necessary values.

**Steps:**

1. Install Python (3.12 or higher).

2. Clone the repository and create your .env file.

3. (Optional) Deploy the infrastructure first if you need valid Azure AD credentials in .env.

4. Install dependencies:
```bash
pip install -r requirements.txt
```

or using Conda:

```bash
conda env create -f environment.yml
conda activate streamlit-starter-kt
```

5. Run the app:
```bash
streamlit run app/main.py
```

6. Open your browser at http://localhost:8501.

## Deploying to Azure

For detailed deployment steps (both infrastructure and containerized app), see azure/README.md. You will learn how to:

1. Provision required Azure resources (Resource Group, Container Registry, App Service, etc.).

2. Configure Azure Active Directory (Entra ID) for authentication.

3. Build and push the Docker image, then deploy it to Azure.

## License

This project is licensed under the MIT License.
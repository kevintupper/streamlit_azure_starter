# Environment Setup

The `.env` file holds sensitive or environment-specific configuration. It is **never** committed to version control. Below is an overview of key variables and how to configure them. 

> **Tip**  
> Make a copy of `template.env` and rename it to `.env`. Fill in relevant values before running deployment scripts or starting the app locally.

---

## Key Variables

| Variable                 | Description                                                                                               | Example                                  |
|--------------------------|-----------------------------------------------------------------------------------------------------------|------------------------------------------|
| `UNIQUE_APP_NAME`        | A unique name (lowercase) for all Azure resources (Resource Group, ACR, App Service, etc.).              | `streamlit-azure-app`                    |
| `APP_NAME`               | Display name for the Streamlit app UI.                                                                    | `My Streamlit Demo`                      |
| `APP_ICON`               | Streamlit page icon/emoji.                                                                                | `:fire:`                                 |
| `APP_OWNER_EMAIL`        | Contact email displayed in the app (e.g. for support).                                                    | `someone@example.com`                    |
| `APP_ABOUT`              | Short description of your app, displayed on the homepage or sign-in screen.                               | `A POC for AI demos...`                  |
| `LOG_LEVEL`              | Log verbosity.                                                                                            | `INFO`, `DEBUG`, `ERROR`, etc.           |
| `ALLOWED_TENANTS`        | Comma-separated list of Tenant IDs allowed for login.                                                     | `xxx,yyy`                                |
| `MSAL_AUTHORITY`         | Azure AD authority (multi-tenant, single-tenant, etc.).                                                   | `https://login.microsoftonline.com/organizations/` |
| `MSAL_SCOPES`            | MSAL scopes for the user to consent to.                                                                   | `User.Read`                              |
| `MSAL_REDIRECT_LOCAL_URI`| Redirect URI for local dev/test.                                                                          | `http://localhost:8501`                  |
| `MSAL_REDIRECT_AZURE_URI`| Redirect URI for the deployed app.                                                                        | `https://<UNIQUE_APP_NAME>.azurewebsites.net` |
| `APP_CLIENT_ID`          | Azure AD application (client) ID. Set automatically by `deploy-infra.ps1` if left blank.                  | `xxxxx-xxxx-xxxx-xxxxx`                  |
| `APP_CLIENT_SECRET`      | Azure AD app client secret. Overwritten by `deploy-infra.ps1`.                                            | `supersecretvalue`                       |
| `APP_TENANT_ID`          | Azure Tenant ID. Overwritten by `deploy-infra.ps1`.                                                       | `xxxxx-xxxx-xxxx-xxxxx`                  |
| `STORAGE_ACCOUNT_NAME`   | Azure Storage Account name. Generated in infra deployment.                                                | `streamlitazureappstorage`               |
| `STORAGE_ACCOUNT_KEY`    | Azure Storage Account key. Generated in infra deployment.                                                 | `Zp2HtX...`                               |
| `STORAGE_CONNECTION_STRING` | Storage Account connection string. Generated in infra deployment.                                      | `DefaultEndpointsProtocol=...`           |

---

## Steps to Configure

1. **Copy Template**  
   ```bash
   cp template.env .env
   ```

2. Fill in Basic Info

- Set UNIQUE_APP_NAME to a globally unique string. No uppercase or special characters.
- Update the APP_NAME, APP_ICON, and any UI messages if desired.

3. (Optional) Deployment

- If you run .\azure\deploy-infra.ps1, the script will generate or overwrite the Azure AD credentials and storage settings in .env.
- This saves you from having to set them manually.

4. Run Locally or Deploy
- Locally: streamlit run app/main.py
- Deploy: See azure/README.md.

## Security Notes

- Do not commit your .env file to Git or other version control.
- Rotate client secrets regularly if you are using them for production scenarios.
php


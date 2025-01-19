"""
Authentication Module

This module provides authentication and authorization functionality for the application.
It combines the UI and service logic for handling user authentication via Microsoft Azure AD,
token management, and tenant-based access control.

Key Features:
- User authentication with Microsoft Azure AD
- Token management and decoding
- Tenant-based access control
- User information retrieval from Microsoft Graph API
- Streamlit-based UI for sign-in and error handling

Functions:
    enforce_auth_or_display_sign_in: Main authentication flow handler
    get_auth_url: Generate the authorization URL for user sign-in
    handle_auth_code: Handle the authentication code received from the identity provider
    get_token_from_code: Retrieve an access token using the authorization code
    decode_token: Decode a JWT token without verifying the signature
    get_tenant_id_from_token: Extract the tenant ID from an access token
    is_allowed_tenant: Check if a given tenant ID is in the list of allowed tenants
    get_user_info: Retrieve user information from the Microsoft Graph API
    display_sign_in_screen: Render the sign-in UI
    display_invalid_tenant_screen: Render the invalid tenant error screen

Dependencies:
    - msal: Microsoft Authentication Library for Python
    - requests: HTTP library for making API calls
    - jwt: JSON Web Token implementation
    - streamlit: Used for creating the user interface
    - app.core.session_manager: Manages user session data
"""

# Standard imports
import logging
import streamlit as st
import requests
import jwt
from typing import Dict, Any, Optional


# Core imports
from app.core.config import config
from app.core.session_manager import SessionManager


# Logging setup
logging.basicConfig(
    level=config.LOG_LEVEL,
    format="%(asctime)s - %(levelname)s - %(message)s"
)


def enforce_auth_or_display_sign_in() -> bool:
    """
    Enforce authentication by checking for a valid access token in the session state.

    If the user is not authenticated, this function displays the sign-in screen or handles
    the authentication code if provided in the query parameters.

    Returns:
        bool: True if the user is authenticated, False otherwise.
    """
    if SessionManager.is_authenticated():
        return True

    query_params = st.query_params.to_dict()
    if "code" in query_params:
        return handle_auth_code(query_params["code"])
    else:
        display_sign_in_screen()

    return False


def handle_auth_code(auth_code: str) -> bool:
    """
    Handle the authentication code received from the identity provider.

    This function performs the following steps:
    1. Obtains an access token using the authorization code.
    2. Extracts the tenant ID from the token.
    3. Checks if the tenant is allowed.
    4. If allowed, retrieves the user information and initializes the session.

    Args:
        auth_code (str): The authentication code received from the identity provider.

    Returns:
        bool: True if authentication is successful, False otherwise.
    """
    access_token = get_token_from_code(auth_code)
    st.query_params.clear()  # Clear query parameters after processing

    if not access_token:
        st.error("Authentication failed.")
        return False

    tenant_id = get_tenant_id_from_token(access_token)
    print(f"Tenant ID: {tenant_id}")
    print(f"Allowed Tenants: {config.ALLOWED_TENANTS}")
    if not is_allowed_tenant(tenant_id):
        display_invalid_tenant_screen()
        return False

    user_info = get_user_info(access_token)
    if not user_info:
        st.error("Failed to retrieve user information.")
        return False

    SessionManager.initialize_session(access_token, user_info)
    return True


def display_sign_in_screen() -> None:
    """
    Display the sign-in screen to the user.

    This function renders the UI elements for the sign-in screen, including
    the title, welcome message, and sign-in button.
    """
    st.title("Microsoft")
    st.subheader("Azure Fed Demo Platform")
    st.write("Welcome to the Microsoft Azure Fed Demo Platform. Please sign in with an authorized account.")

    auth_url = get_auth_url()
    st.markdown(
        f"""
        <a href='{auth_url}' target='_self'>
            <button style='background-color: teal; color: white; border: none; border-radius: 4px; padding: 8px 16px; font-size: 18px; cursor: pointer;'>
                Sign In
            </button>
        </a>
        """,
        unsafe_allow_html=True,
    )


def display_invalid_tenant_screen() -> None:
    """
    Display a screen for users who have logged in with an invalid tenant.
    """
    st.title("Access Denied")
    st.error("Your account is not authorized to access this application.")
    st.write("This application is only available to specific Microsoft tenants.")
    st.write("If you believe this is an error, please contact your administrator.")

    auth_url = get_auth_url()
    st.markdown(
        f"""
        <a href='{auth_url}' target='_self'>
            <button style='background-color: teal; color: white; border: none; border-radius: 4px; padding: 8px 16px; font-size: 18px; cursor: pointer;'>
                Sign In with a Different Account
            </button>
        </a>
        """,
        unsafe_allow_html=True,
    )


def get_auth_url() -> str:
    """
    Generate the authorization URL for user sign-in.

    Returns:
        str: The authorization URL for the user to initiate the sign-in process.
    """
    from msal import ConfidentialClientApplication

    app = ConfidentialClientApplication(
        client_id=config.APP_CLIENT_ID,
        authority=config.MSAL_AUTHORITY,
        client_credential=config.APP_CLIENT_SECRET
    )
    auth_url = app.get_authorization_request_url(
        scopes=config.MSAL_SCOPES,
        redirect_uri=config.MSAL_REDIRECT_URI
    )
    logging.debug(f"Generated auth URL: {auth_url}")
    return auth_url


def get_token_from_code(auth_code: str) -> Optional[str]:
    """
    Retrieve an access token using the authorization code.

    Args:
        auth_code (str): The authorization code received after user sign-in.

    Returns:
        Optional[str]: The access token if successful, None otherwise.
    """
    from msal import ConfidentialClientApplication

    app = ConfidentialClientApplication(
        client_id=config.APP_CLIENT_ID,
        authority=config.MSAL_AUTHORITY,
        client_credential=config.APP_CLIENT_SECRET
    )
    try:
        result = app.acquire_token_by_authorization_code(
            auth_code,
            scopes=config.MSAL_SCOPES,
            redirect_uri=config.MSAL_REDIRECT_URI
        )
        return result.get("access_token")
    except Exception as e:
        logging.error(f"Error getting token from code: {e}")
        return None


def get_tenant_id_from_token(access_token: str) -> Optional[str]:
    """
    Extract the tenant ID from an access token.

    Args:
        access_token (str): The access token to extract the tenant ID from.

    Returns:
        str: The tenant ID if successful, None otherwise.
    """
    try:
        decoded_token = decode_token(access_token)
        return decoded_token['tid']
    except Exception as e:
        logging.error(f"Error extracting tenant ID from token: {e}")
        return None


def is_allowed_tenant(tenant_id: str) -> bool:
    """
    Check if a given tenant ID is in the list of allowed tenants.

    Args:
        tenant_id (str): The tenant ID to check.

    Returns:
        bool: True if the tenant is allowed, False otherwise.
    """
    return tenant_id in config.ALLOWED_TENANTS


def get_user_info(access_token: str) -> Optional[Dict[str, Any]]:
    """
    Retrieve user information from the Microsoft Graph API.

    Args:
        access_token (str): The access token to use for authentication.

    Returns:
        Optional[Dict[str, Any]]: User information if successful, None otherwise.
    """
    headers = {"Authorization": f"Bearer {access_token}"}
    response = requests.get("https://graph.microsoft.com/v1.0/me", headers=headers)
    if response.status_code == 200:
        return response.json()
    else:
        logging.error(f"Error fetching user info: {response.text}")
        return None


def decode_token(token: str) -> Optional[Dict[str, Any]]:
    """
    Decode a JWT token without verifying the signature.

    Args:
        token (str): The JWT token to decode.

    Returns:
        Optional[Dict[str, Any]]: The decoded token claims if successful, None otherwise.
    """
    try:
        algorithm = jwt.get_unverified_header(token)["alg"]
        decoded_token = jwt.decode(
            token, algorithms=[algorithm], options={"verify_signature": False}
        )
        return decoded_token
    except Exception as e:
        logging.error(f"Error decoding token: {e}")
        return None

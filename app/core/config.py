"""
Configuration Service

This module provides a centralized service for managing application configuration.
It loads all settings from a `.env` file and supports type conversions for booleans,
lists, and other common types.

Instructions:
    1. Create a `.env` file in the root of the project.
    2. Add the environment variables to the `.env` file.
    3. Adjust the init to include your boolean, list, and dictionary keys.
    4. Use the ConfigService to access the configuration values.

Usage:
    from app.core.config import config

    # Access configuration values
    db_url = config.DATABASE_URL
    debug_mode = config.DEBUG
    allowed_origins = config.ALLOWED_ORIGINS
"""

# -----------------------------------------------------------------------------------------------------------
# Imports   
# -----------------------------------------------------------------------------------------------------------
import os
from dotenv import load_dotenv
from typing import Any, List
import json


# -----------------------------------------------------------------------------------------------------------
# Configuration Service Definition
# -----------------------------------------------------------------------------------------------------------
class ConfigService:
    """
    A service for managing application configuration.

    This service loads all environment variables from a `.env` file and makes
    them accessible as attributes. It also supports type conversions for
    booleans, lists, and dictionaries.
    """
    def __init__(self):
        """
        Initialize the ConfigService by loading environment variables.
        """
        load_dotenv()  # Load environment variables from the .env file
        self._config = {key: value for key, value in os.environ.items()}

        # Define keys that require special type conversions
        self._boolean_keys = ['DEBUG']
        self._list_keys = ['ALLOWED_ORIGINS', 'ALLOWED_TENANTS', 'MSAL_SCOPES']
        self._dict_keys = ['API_SETTINGS']

        # Perform type conversions
        self._convert_booleans()
        self._convert_lists()
        self._convert_dicts()

        # Dynamically set MSAL_REDIRECT_URI based on the detected environment
        self._set_msal_redirect_uri()

    def _convert_booleans(self):
        """
        Convert specific keys to boolean values.
        """
        for key in self._boolean_keys:
            if key in self._config:
                self._config[key] = self._config[key].lower() in ('true', '1', 't')

    def _convert_lists(self):
        """
        Convert specific keys to list values.
        """
        for key in self._list_keys:
            if key in self._config:
                self._config[key] = [item.strip() for item in self._config[key].split(',') if item.strip()]

    def _convert_dicts(self):
        """
        Convert specific keys to dictionary values.
        """
        for key in self._dict_keys:
            if key in self._config:
                try:
                    self._config[key] = json.loads(self._config[key])
                except json.JSONDecodeError as e:
                    raise ValueError(f"Invalid JSON format for '{key}': {e}")

    def _set_msal_redirect_uri(self):
        """
        Dynamically set MSAL_REDIRECT_URI based on the detected environment.
        """
        if self._is_running_in_azure():
            self._config['MSAL_REDIRECT_URI'] = self._config.get('MSAL_REDIRECT_AZURE_URI')
        else:
            self._config['MSAL_REDIRECT_URI'] = self._config.get('MSAL_REDIRECT_LOCAL_URI')

    def _is_running_in_azure(self):
        """
        Detect if the application is running in Azure App Service.

        Returns:
            bool: True if running in Azure, False otherwise.
        """
        # Azure App Service sets the WEBSITE_INSTANCE_ID environment variable
        return 'WEBSITE_INSTANCE_ID' in self._config

    def __getattr__(self, name: str) -> Any:
        """
        Access configuration values as attributes.

        Args:
            name (str): The name of the configuration setting to access.

        Returns:
            Any: The value of the configuration setting.

        Raises:
            AttributeError: If the configuration setting does not exist.
        """
        try:
            return self._config[name]
        except KeyError:
            raise AttributeError(f"Configuration setting '{name}' not found.")

    def get(self, key: str, default: Any = None) -> Any:
        """
        Retrieve a configuration value by key.

        Args:
            key (str): The name of the configuration setting to retrieve.
            default (Any): The default value to return if the key is not found.

        Returns:
            Any: The value of the configuration setting, or the default value if not found.
        """
        return self._config.get(key, default)


# -----------------------------------------------------------------------------------------------------------
# Create a singleton instance of ConfigService and expose it as `config`
# -----------------------------------------------------------------------------------------------------------
config = ConfigService()
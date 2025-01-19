# File: app/services/config_service.py
# Location: app/services
"""
ConfigService Module

This module defines the ConfigModel and ConfigService for managing application configuration.
It uses Pydantic for data validation and loads configuration settings from a .env file and environment variables.

Key Features:
- Pydantic-based validation for environment variables.
- Centralized configuration management using ConfigService.
- Support for boolean, list, and dictionary type conversions.
- Lazy initialization to avoid unnecessary overhead.
"""

# Standard library imports
import os
import json
from typing import Any, Dict
from dotenv import load_dotenv
from pydantic import BaseModel, Field

# Debug logger import
from app.utils.debug_logger import debug_logger


#***********************************************************************************************
# Configuration Model Definition
#***********************************************************************************************
class ConfigModel(BaseModel):
    """
    Configuration class for loading and accessing environment variables.
    This class uses Pydantic for data validation and type checking.
    It dynamically creates attributes based on environment variables.
    """

    config_values: Dict[str, Any] = Field(default_factory=dict)

    def __getattr__(self, name: str) -> Any:
        """
        Allows accessing config values as attributes.
        
        Args:
            name (str): The name of the config value to access.
        
        Returns:
            The value of the config setting.
        
        Raises:
            AttributeError: If the config setting doesn't exist.
        """
        try:
            return self.config_values[name]
        except KeyError:
            raise AttributeError(f"'{self.__class__.__name__}' object has no attribute '{name}'")

    @classmethod
    def load_from_env(cls) -> 'ConfigModel':
        """
        Loads configuration from the .env file and environment variables.
        
        Returns:
            ConfigModel: An instance populated with the loaded configuration values.
        """
        load_dotenv()
        
        config_dict = {key: value for key, value in os.environ.items()}
        
        # Convert boolean flags
        boolean_keys = ['DEV', 'DEBUG', 'LOCAL_STORAGE']
        for key in boolean_keys:
            if key in config_dict:
                config_dict[key] = config_dict[key].lower() in ('true', '1', 't')

        # Convert list types
        list_keys = ['ALLOWED_TENANTS', 'ALLOWED_ORIGINS', 'MSAL_SCOPES', 'AOAI_DEPLOYMENT']
        for key in list_keys:
            if key in config_dict:
                config_dict[key] = [item.strip() for item in config_dict[key].split(',') if item.strip()]

        # Convert dictionary types (including nested)
        dict_keys = ['API_SETTINGS']
        for key in dict_keys:
            if key in config_dict:
                try:
                    config_dict[key] = json.loads(config_dict[key])
                except json.JSONDecodeError as e:
                    raise ValueError(f"Invalid JSON format for '{key}': {e}")

        return cls(config_values=config_dict)

#***********************************************************************************************
# Configuration Service Definition
#***********************************************************************************************
class ConfigService:
    """
    Service for managing application configuration.
    This service is responsible for loading and providing access to the application configuration.

    Attributes:
        _config (ConfigModel): The loaded configuration model.
    """

    def __init__(self):
        """
        Initialize the ConfigService by loading the configuration.
        This method should be called to explicitly load the configuration.
        """
        self._logger = debug_logger
        self._config = None
        self._logger.debug("ConfigService initialized")

    def initialize(self):
        """
        Load the configuration.

        This method should be called to load the configuration from the environment.
        """
        try:
            self._config = ConfigModel.load_from_env()
            self._logger.info("Configuration loaded successfully.")
        except Exception as e:
            self._logger.error(f"Failed to load configuration: {str(e)}")
            raise

    @property
    def config(self) -> ConfigModel:
        """
        Provides access to the loaded configuration.

        Returns:
            ConfigModel: The loaded ConfigModel instance.

        Raises:
            RuntimeError: If accessed before the ConfigService is initialized.
        """
        if self._config is None:
            self._logger.warning("ConfigService accessed before initialization. Initializing now.")
            self.initialize()
        return self._config

#***********************************************************************************************
# Example usage and testing
#***********************************************************************************************
if __name__ == "__main__":
    config_service = ConfigService()
    
    # Access a configuration setting
    try:
        app_name = config_service.config.APP_NAME
        print(f"App Name: {app_name}")

        # Access a dictionary-type setting (with nested values)
        api_settings = config_service.config.API_SETTINGS
        print(f"API Settings: {api_settings}")
        print(f"Service A URL: {api_settings['serviceA']['url']}")
        print(f"Service B Timeout: {api_settings['serviceB']['timeout']}")

    except AttributeError as e:
        print(f"Configuration error: {e}")
    except ValueError as e:
        print(f"Value error: {e}")

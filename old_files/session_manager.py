# File: app/core/session_manager.py

"""
SessionManager Module

This module provides a SessionManager class for managing user sessions and application state
in the AzureFed.com presentation system. It offers methods to set, get, and clear user information,
as well as manage presentation and module-related data.

The SessionManager uses Streamlit's session_state to persist data across reruns of the Streamlit app.

Classes:
    SessionManager: Manages user session data, authentication status, and application state.

Dependencies:
    - streamlit: Used for accessing and manipulating session state.
    - uuid: Used for generating unique session IDs.
    - datetime: Used for timestamping session start.
"""

# Standard library imports
import uuid
from datetime import datetime
from typing import Dict, Any, Optional

# Streamlit imports
import streamlit as st

# Debug logger import
from app.utils.debug_logger import debug_logger

# Import ServiceContainer
from app.services.service_container import ServiceContainer

#***********************************************************************************************
# SessionManager class
#***********************************************************************************************
class SessionManager:
    """
    SessionManager utility for handling user session data in the AzureFed.com presentation system.

    This class provides static methods to manage user authentication state, user information,
    and presentation/module data using Streamlit's session_state. It acts as a centralized
    interface for session management across the application.

    Methods are static to allow easy access without needing to instantiate the class.
    """

    @staticmethod
    def initialize_session(services: ServiceContainer, access_token: str, user_info: Dict[str, Any]) -> None:
        """
        Initialize the session state with user information and other necessary data.

        This method uses the service_container to set up the initial session state
        when a user successfully authenticates. It stores the access token, user info,
        and performs any necessary initialization using the services.

        Args:
            service_container (ServiceContainer): Container with all application services.
            access_token (str): The user's access token from authentication.
            user_info (dict): Dictionary containing user information.
        """

        # Store the access token and user info in the session state
        st.session_state.access_token = access_token
        st.session_state.user_info = user_info
        st.session_state.is_authenticated = True
        st.session_state.session_log_info = SessionManager._get_session_log_info(user_info)

        # Log the event that now that we know a user has successfully initialized a session
        services.app_log_service.log_event("User_Login", st.session_state['session_log_info'])
        debug_logger.debug(f"User authenticated: {user_info.get('userPrincipalName')}")
        
        # Initialize the show_configuration_manager flag
        st.session_state.show_configuration_manager = False

        # Load user's prefered presentation
        SessionManager.load_startup_presentation(services, user_info)


    @staticmethod
    def load_startup_presentation(services: ServiceContainer, user_info: Dict[str, Any]) -> None:
        """
        Set the startup presentation for the user.
        """

        # Get the user data
        user_id = user_info.get("id")
        user_principal_name = user_info.get("userPrincipalName")

        # Get the user's default presentation
        presentation_folder = services.storage_service.get_user_default_presentation(user_principal_name, user_id)

        # Store the presentation folder in session state
        st.session_state["presentation_folder"] = presentation_folder

        # Get the presentation name and menu items and store them in session state and initialize the presentation meta (starting page) to empty
        presentation_name, menu_items = services.storage_service.get_presentation_menu(st.session_state["presentation_folder"])
        st.session_state["presentation_name"] = presentation_name
        st.session_state["menu_items"] = menu_items
        st.session_state["presentation_meta"] = ""



    @staticmethod
    def clear_session() -> None:
        """
        Clear all session state variables related to the user session.

        This method is typically called during logout to remove all user-specific data
        from the session state.
        """
        # List of keys to be cleared from the session state
        keys_to_clear = [
            'access_token', 'user_info', 'session_log_info', 
            'current_presentation', 'current_module', 'presentations', 'modules'
        ]
        
        # Remove each key from the session state if it exists
        for key in keys_to_clear:
            if key in st.session_state:
                del st.session_state[key]

    @staticmethod
    def is_authenticated() -> bool:
        """
        Check if a user is currently authenticated.

        Returns:
            bool: True if a user is authenticated (access token and user info exist), False otherwise.
        """
        return st.session_state.get('is_authenticated', False)

    @staticmethod
    def get_user_info() -> Dict[str, Any]:
        """
        Retrieve the current user's information.

        Returns:
            dict: The current user's information if available, None otherwise.
        """
        return st.session_state.get('user_info', {})

    @staticmethod
    def get_presentation_folder() -> Optional[str]:
        """
        Get the current presentation folder.

        Returns:
            str: The folder for the active presentation.
        """
        return st.session_state.get('presentation_folder')

    @staticmethod
    def _get_session_log_info(user_info: Dict[str, Any]) -> Dict[str, str]:
        """
        Create session log info for event logging.

        This internal method generates a unique session ID and timestamp for the current session.

        Args:
            user_info (dict): Dictionary containing user information.

        Returns:
            dict: Session log information including user ID, session ID, and start time.
        """
        return {
            "user_id": user_info.get("userPrincipalName"),
            "session_id": f'{user_info.get("userPrincipalName")}_{uuid.uuid4()}',
            "session_start": datetime.now().isoformat()
        }
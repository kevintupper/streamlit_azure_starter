"""
SessionManager Module

This module provides a SessionManager class for managing user sessions and application state
in a starter app. It offers methods to set, get, and clear user information, as well as manage
application-related data.

The SessionManager uses Streamlit's session_state to persist data across reruns of the Streamlit app.

Classes:
    SessionManager: Manages user session data and application state.

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

#***********************************************************************************************
# SessionManager class
#***********************************************************************************************
class SessionManager:
    """
    SessionManager utility for handling user session data in a starter app.

    This class provides static methods to manage user authentication state, user information,
    and application data using Streamlit's session_state. It acts as a centralized
    interface for session management across the application.

    Methods are static to allow easy access without needing to instantiate the class.
    """

    @staticmethod
    def initialize_session(access_token: str, user_info: Dict[str, Any]) -> None:
        """
        Initialize the session state with user information and other necessary data.

        Args:
            access_token (str): The access token for the user.
            user_info (dict): Dictionary containing user information.
        """

        # Store the access token in the session state
        st.session_state.access_token = access_token

        # Store the user info in the session state
        st.session_state.user_info = user_info
        st.session_state.is_authenticated = True

        # Example debug log
        print(f"User authenticated: {user_info.get('username')}")

    @staticmethod
    def clear_session() -> None:
        """
        Clear all session state variables related to the user session.

        This method is typically called during logout to remove all user-specific data
        from the session state.
        """
        # List of keys to be cleared from the session state
        keys_to_clear = ['user_info', 'is_authenticated', 'session_log_info']
        
        # Remove each key from the session state if it exists
        for key in keys_to_clear:
            if key in st.session_state:
                del st.session_state[key]

    @staticmethod
    def is_authenticated() -> bool:
        """
        Check if a user is currently authenticated.

        Returns:
            bool: True if a user is authenticated, False otherwise.
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
            "user_id": user_info.get("username"),
            "session_id": f'{user_info.get("username")}_{uuid.uuid4()}',
            "session_start": datetime.now().isoformat()
        }

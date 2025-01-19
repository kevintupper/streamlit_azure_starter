"""
Main Application Module

This module serves as the entry point for the Streamlit-based Azure Application.
It handles the main application flow, including authentication, navigation setup, and loading pages.

The module performs the following key functions:
1. Configures the Streamlit page settings.
2. Manages the authentication flow.
3. Builds the sidebar navigation.
4. Loads the selected page based on the selected menu item.

Usage:
    Run this file directly with Streamlit to start the application.

Dependencies:
    - streamlit: For creating the web application interface.
"""

# -----------------------------------------------------------------------------------------------------------
# Add the project root to the Python path to deal with Streamlit issues in relative imports.
# Use absolute imports from the project root throughout the app.
# -----------------------------------------------------------------------------------------------------------
import sys
from pathlib import Path

# Add the project root to the Python path
project_root = Path(__file__).parent.parent.absolute()
sys.path.insert(0, str(project_root))
# -----------------------------------------------------------------------------------------------------------

# Utility imports
import asyncio

# Streamlit imports
import streamlit as st

# Core imports
from app.core.config import config
from app.core.session_manager import SessionManager
from app.core.auth import enforce_auth_or_display_sign_in



# Placeholder imports for future functionality
# These will be implemented as we build the app
# from app.core.session_manager import SessionManager
# from app.core.auth import Auth
# from app.core.menu import Menu
# from app.core.content import Content

# -----------------------------------------------------------------------------------------------------------
# Streamlit configuration
# -----------------------------------------------------------------------------------------------------------
def configure_streamlit():
    """
    Configure Streamlit page settings.
    """
    st.set_page_config(
        page_title=config.APP_NAME,
        page_icon=config.APP_ICON, 
        layout="wide",
        initial_sidebar_state="expanded",
        menu_items={
            'Get Help': f'mailto:{config.APP_OWNER_EMAIL}',
            'Report a bug': f'mailto:{config.APP_OWNER_EMAIL}',
            'About': f'{config.APP_ABOUT}'
        }
    )


# -----------------------------------------------------------------------------------------------------------
# Main application flow
# -----------------------------------------------------------------------------------------------------------
async def main():
    """
    Main function that runs the Streamlit app.

    This function manages the overall flow of the application, including
    authentication, navigation setup, and page selection.
    """
    # Configure Streamlit (this must be the first Streamlit command)
    configure_streamlit()


    # Enforce user authentication or keep on the sign-in screen until they are authenticated.
    if enforce_auth_or_display_sign_in():

        # Build the navigation menu
        st.sidebar.markdown("## Navigation")

        # We are authenticated, so we can show the configuration manager
        st.markdown("## Configuration Manager")

        # Write the session state to the screen
        st.json(st.session_state)


        # Check if we should show the configuration manager
#        if st.session_state.get('show_configuration_manager', False):
#            from app.core import configuration_manager
#            configuration_manager.configuration_manager_page()
#        else:
            # Execute the selected menu item based on its meta file definition
#            run_presentation()


    # Show the App Name
#    st.markdown(f"# {config.APP_NAME}")
#    st.markdown(f"## {config.MSAL_REDIRECT_URI}")




# -----------------------------------------------------------------------------------------------------------
# Run the main function
# -----------------------------------------------------------------------------------------------------------
if __name__ == "__main__":
    asyncio.run(main())
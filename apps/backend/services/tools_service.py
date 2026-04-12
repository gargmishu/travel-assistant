import os
from google.adk.tools.mcp_tool.mcp_toolset import MCPToolset
from google.adk.tools.mcp_tool.mcp_session_manager import StreamableHTTPConnectionParams

def get_maps_toolset():
    return MCPToolset(
        connection_params=StreamableHTTPConnectionParams(
            url="https://mapstools.googleapis.com/mcp",
            headers={"X-Goog-Api-Key": os.getenv('MAPS_API_KEY')}
        )
    )

# Add your BigQuery toolset logic here as well...
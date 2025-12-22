import asyncio
from fastmcp import Client

client = Client("http://localhost:8000/mcp")


async def call_booking():
    async with client:
        result = await client.call_tool("booking", {})
        print(result)

asyncio.run(call_booking())

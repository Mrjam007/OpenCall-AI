import asyncio
import json
import logging
import websockets
import requests
from requests.auth import HTTPBasicAuth

logger = logging.getLogger(__name__)

class ARIClient:
    def __init__(self, base_url, user, password):
        self.base_url = base_url
        self.user = user
        self.password = password
        self.auth = HTTPBasicAuth(user, password)
        self.events = {}
        
    def on_channel_event(self, event_type, callback):
        self.events[event_type] = callback

    def _req(self, method, endpoint, **kwargs):
        url = f"{self.base_url}/{endpoint}"
        res = requests.request(method, url, auth=self.auth, json=kwargs.get('json'), params=kwargs.get('params'))
        res.raise_for_status()
        if res.text:
            return res.json()
        return {}

    def get(self, endpoint, **kwargs): return self._req("GET", endpoint, **kwargs)
    def post(self, endpoint, **kwargs): return self._req("POST", endpoint, **kwargs)
    def delete(self, endpoint, **kwargs): return self._req("DELETE", endpoint, **kwargs)

    async def connect_websocket(self, app_name):
        ws_url = self.base_url.replace("http://", "ws://").replace("https://", "wss://")
        ws_url = f"{ws_url}/events?app={app_name}&api_key={self.user}:{self.password}"
        
        while True:
            try:
                async with websockets.connect(ws_url) as ws:
                    logger.info(f"Connected to ARI WebSocket for app {app_name}")
                    async for msg in ws:
                        data = json.loads(msg)
                        etype = data.get("type")
                        if etype in self.events:
                            try:
                                if asyncio.iscoroutinefunction(self.events[etype]):
                                    await self.events[etype](data)
                                else:
                                    self.events[etype](data)
                            except Exception as e:
                                logger.error(f"Error in {etype} handler: {e}", exc_info=True)
            except Exception as e:
                logger.error(f"WebSocket connection lost: {e}. Retrying in 2 seconds...")
                await asyncio.sleep(2)

    def run(self, apps):
        asyncio.get_event_loop().run_until_complete(self.connect_websocket(apps))

import asyncio
import logging
from custom_ari import ARIClient
from session import CallSession

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

ARI_URL = 'http://localhost:8088/ari'
ARI_USER = 'asterisk'
ARI_PASS = 'asterisk'

client = ARIClient(ARI_URL, ARI_USER, ARI_PASS)
active_sessions = {}

def on_stasis_start(ev):
    """Handler for when a call enters the Stasis application"""
    channel = ev.get("channel")
    channel_id = channel.get("id")
    logger.info(f"Incoming call: {channel_id}")

    # Answer if not answered
    client.post(f"channels/{channel_id}/answer")

    # Create session
    session = CallSession(client, channel)
    active_sessions[channel_id] = session
    asyncio.ensure_future(session.start())

def on_stasis_end(ev):
    """Handler for when a call leaves Stasis"""
    channel_id = ev.get("channel").get("id")
        active_sessions[channel_id].cleanup()
        del active_sessions[channel_id]

# Register event callbacks
client.on_channel_event('StasisStart', on_stasis_start)
client.on_channel_event('StasisEnd', on_stasis_end)

if __name__ == '__main__':
    logger.info("Starting OpenCall AI ARI Service...")
    client.run(apps="opencall_ai")

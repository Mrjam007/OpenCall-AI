import asyncio
import socket

class UdpAudioStream:
    def __init__(self, ip='127.0.0.1', port=0):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind((ip, port))
        self.sock.setblocking(False)
        self.target_address = None

    def get_port(self):
        return self.sock.getsockname()[1]

    async def listen(self, callback):
        loop = asyncio.get_event_loop()
        while True:
            # Simple UDP reader (Asterisk RTP stripped via ExternalMedia, raw raw format)
            try:
                data, addr = await loop.sock_recvfrom(self.sock, 4096)
                if not self.target_address:
                    self.target_address = addr
                await callback(data)
            except asyncio.CancelledError:
                break
            except Exception as e:
                pass

    async def send(self, data):
        if self.target_address:
            loop = asyncio.get_event_loop()
            await loop.sock_sendto(self.sock, data, self.target_address)

    def close(self):
        self.sock.close()

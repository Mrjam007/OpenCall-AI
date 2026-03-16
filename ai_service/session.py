import asyncio
import logging
from audio_stream import UdpAudioStream
from stt import SpeechToText
from llm import LanguageModel
from tts import TextToSpeech
from vad import VoiceActivityDetector

logger = logging.getLogger(__name__)

class CallSession:
    def __init__(self, client, channel):
        self.client = client
        self.channel = channel
        self.channel_id = channel.get("id")
        self.bridge = None
        self.external_media = None
        self.history = [{"role": "system", "content": "You are a helpful phone assistant. Keep answers brief."}]
        
        self.audio_stream = UdpAudioStream()
        self.vad = VoiceActivityDetector()
        self.stt = SpeechToText()
        self.llm = LanguageModel()
        self.tts = TextToSpeech()
        
        self.is_playing = False
        
    async def start(self):
        # Create a basic mixing bridge
        self.bridge = self.client.post('bridges', json={'type': 'mixing'})
        self.client.post(f"bridges/{self.bridge['id']}/addChannel", json={'channel': self.channel_id})

        # Start external media channel to stream to/from Python (UDP)
        port = self.audio_stream.get_port()
        self.external_media = self.client.post('channels/externalMedia', json={
            'app': 'opencall_ai',
            'external_host': f'127.0.0.1:{port}', # Assuming localhost
            'format': 'ulaw'
        })
        self.client.post(f"bridges/{self.bridge['id']}/addChannel", json={'channel': self.external_media['id']})
        await asyncio.gather(
            self.audio_stream.listen(self.handle_audio_in),
            self.greet_user()
        )
        
    async def greet_user(self):
        await self.speak("Hi, this is OpenCall AI. How can I help you?")

    async def handle_audio_in(self, audio_chunk):
        is_speech = self.vad.is_speech(audio_chunk)
        if is_speech:
            if self.is_playing:
                await self.barge_in()
            self.stt.buffer_audio(audio_chunk)
        elif self.stt.has_buffered_audio():
            text = self.stt.transcribe_buffer()
            if text:
                logger.info(f"User said: {text}")
                await self.process_turn(text)

    async def barge_in(self):
        """Interrupts currently playing TTS due to user speaking"""
        logger.info("Barge-in detected!")
        self.is_playing = False
        # Stop playback on Asterisk
        self.tts.stop()
        # In this custom ARI implementation, you'd stop actual playbacks if Asterisk strings them, 
        # but since we are doing External Media streaming directly over UDP, 
        # stopping our TTS generator is enough to stop the audio.

    async def process_turn(self, user_text):
        self.history.append({"role": "user", "content": user_text})
        self.is_playing = True
        
        response_text = ""
        async for token in self.llm.stream_response(self.history):
            response_text += token
            if token in [".", "?", "!"]:
                # Synthesize chunk
                audio = self.tts.synthesize(response_text)
                await self.audio_stream.send(audio)
                response_text = ""
                
        self.history.append({"role": "assistant", "content": response_text})
        self.is_playing = False

    def cleanup(self):
        if self.bridge:
            try:
                self.client.delete(f"bridges/{self.bridge['id']}")
            except: pass
        if self.external_media:
            try:
                self.client.delete(f"channels/{self.external_media['id']}")
            except: pass
        self.audio_stream.close()

# Lightweight implementation of VAD
import webrtcvad

class VoiceActivityDetector:
    def __init__(self):
        self.vad = webrtcvad.Vad(3) # Aggressive mode (0-3)
        self.sample_rate = 8000 # Asterisk ulaw is typically 8kHz

    def is_speech(self, audio_chunk):
        # webRTC VAD only accepts 10, 20 or 30 ms frames
        # simplified check for structure demonstration
        try:
            # You would typically convert u-law to PCM 16-bit here first
            return self.vad.is_speech(audio_chunk[:160], self.sample_rate)
        except:
            return False

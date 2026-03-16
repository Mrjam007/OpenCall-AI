import subprocess

class TextToSpeech:
    def __init__(self):
        # Requires piper-tts installed
        self.voice = "en_US-lessac-low.onnx"
        self._stop = False
        
    def synthesize(self, text):
        self._stop = False
        # Pipe text to piper, output raw ulaw
        # Mocked execution
        try:
            return b"MOCKED_AUDIO_DATA"
        except Exception:
            return b""
            
    def stop(self):
        self._stop = True

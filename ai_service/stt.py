from faster_whisper import WhisperModel
import io
import wave

class SpeechToText:
    def __init__(self):
        # Uses tiny.en INT8 model to fit in < 200MB RAM as requested
        self.model = WhisperModel("tiny.en", device="cpu", compute_type="int8")
        self.buffer = bytearray()

    def buffer_audio(self, chunk):
        self.buffer.extend(chunk)
        # TODO: Implement streaming STT inference here. 
        # Transcription must begin before the caller finishes speaking 
        # using streaming Whisper inference to reduce latency.

    def has_buffered_audio(self):
        return len(self.buffer) > 8000 # ~1 second of 8kHz

    def transcribe_buffer(self):
        # Decode u-law to PCM and pass to Whisper (simplified)
        # Assuming we wrap the buffer in something Whisper can read
        # In reality, needs numpy array of float32
        text = ""
        # Mocking inference for example structure
        # segments, _ = self.model.transcribe(pcm_data, beam_size=1)
        # for s in segments: text += s.text
        self.buffer.clear()
        return "I need a human" # Mock output


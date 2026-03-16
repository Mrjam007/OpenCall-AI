# OpenCall AI

A fully local, offline AI phone assistant running on Asterisk and Python.

## Architecture & Data Flow

1. **Inbound Call:** SIP trunk from 3CX. Asterisk answers the call and executes the `Stasis` app.
2. **Audio Streaming:** Python instructs Asterisk via REST (ARI) to create an ExternalMedia channel, routing UDP RTP audio to Python.
3. **VAD & STT:** Python detects speech ending using `webrtcvad`. Speech transcription begins before the caller finishes speaking using streaming Whisper inference (tiny.en INT8) to reduce latency by 2-4 seconds.
4. **LLM Reasoning:** Transcribed text is parsed via a local conversational LLM (`TinyLlama` or `Qwen2.5`). Utilizing Q4_K_M GGUF quantized models where possible to reduce RAM usage. Puncuation is chunked.
5. **TTS Playback:** Text chunks are streamed directly to `piper` TTS (low quality voice format `en_US-lessac-low`), yielding 8kHz u-law audio sent back to Asterisk via UDP socket.
6. **Barge-in:** Continuous UDP socket listening cancels playing TTS output and drops current LLM streams when new user speech is detected.

## Security Controls

*   **ARI Binding:** Asterisk ARI must bind only to `127.0.0.1` and not expose port `8088` publicly (configured via `asterisk/http.conf`).
*   **SIP Exposure:** `pjsip.conf` endpoints should heavily restrict IPs to designated trunks only (e.g. 3CX instances).

## Step-by-Step Build Order

*   **Step 1:** Run `scripts/install.sh` inside an Ubuntu LXC container (min 4GB RAM / 3 Cores).
*   **Step 2:** Configure the `3cx-trunk` in `asterisk/pjsip.conf` with your actual 3CX IP address.
*   **Step 3:** Test call routing by connecting to Asterisk CLI (`asterisk -rvvv`) and observing the `from-3cx` dialplan firing.
*   **Step 4:** Deploy Python ARI service by starting `python main.py`.
*   **Step 5:** Monitor Python logs for `StasisStart`, verifying Asterisk and Python have bridged.
*   **Step 6:** Test STT integration locally by watching for `User said: [...]` in Python CLI output when you speak.
*   **Step 7:** Ensure Ollama responds by watching for token streams appending to History.
*   **Step 8:** Finally, listen to the generated TTS response.

## Debugging Guide

*   **No audio from caller:**
    Check `asterisk -rvvv` for SIP/RTP negotiation issues. Ensure Asterisk `pjsip.conf` matches 3CX IP correctly.
*   **STT not detecting speech:**
    Adjust `webrtcvad` threshold inside `vad.py`. Ensure UDP audio port binding allows traffic from Asterisk.
*   **TTS not playing:**
    Verify `piper` executable exists at the path expected within `tts.py`. Check if the external media bridged correctly in `main.py`. Ensure audio is being sent back in `u-law` 8000Hz format.
*   **ARI connection failure:**
    Ensure `http.conf` allows connections on port 8088. Verify the password set in `ari.conf` matches `main.py`.

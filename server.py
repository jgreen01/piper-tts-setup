"""Minimal Piper TTS HTTP server. Keeps model loaded in memory."""
import re
import sys
from flask import Flask, request, Response
from piper import PiperVoice
from piper.config import SynthesisConfig


def split_sentences(text):
    """Split text into sentences for incremental synthesis.
    Piper hangs on long text, so we synthesize sentence by sentence."""
    parts = re.split(r'(?<=[.!?;:])\s+|(?<=\n)\s*', text)
    # Also split very long segments (>200 chars) on commas or dashes
    result = []
    for part in parts:
        part = part.strip()
        if not part:
            continue
        if len(part) > 200:
            subparts = re.split(r'(?<=,)\s+|(?<=—)\s*|\s+[-–]\s+', part)
            result.extend(s.strip() for s in subparts if s.strip())
        else:
            result.append(part)
    return result

MODEL_PATH = sys.argv[1] if len(sys.argv) > 1 else None
if not MODEL_PATH:
    print("Usage: server.py <model.onnx>", file=sys.stderr)
    sys.exit(1)

print(f"Loading model: {MODEL_PATH}", flush=True)
voice = PiperVoice.load(MODEL_PATH)
print("Model loaded. Server starting...", flush=True)

app = Flask(__name__)

@app.route("/", methods=["GET", "POST"])
def synthesize():
    if request.method == "POST":
        text = request.get_data(as_text=True)
    else:
        text = request.args.get("text", "")
    if not text.strip():
        return "No text provided", 400

    length_scale = float(request.args.get("length_scale", 1.0))
    syn_config = SynthesisConfig(length_scale=length_scale)

    def generate():
        for sentence in split_sentences(text):
            for chunk in voice.synthesize(sentence, syn_config=syn_config):
                yield chunk.audio_int16_bytes

    return Response(generate(), mimetype="audio/raw")

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5030)

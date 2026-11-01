from __future__ import annotations

import hmac
import json
import os
import re
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

VOICES = {
    "Arabic": "ar_JO-kareem-medium",
    "German": "de_DE-thorsten-medium",
    "English": "en_US-lessac-medium",
    "French": "fr_FR-siwis-medium",
    "Hindi": "hi_IN-rohan-medium",
    "Malayalam": "ml_IN-meera-medium",
    "Mandarin Chinese": "zh_CN-huayan-medium",
    "Spanish": "es_ES-sharvard-medium",
    "Telugu": "te_IN-maya-medium",
}
MAX_TEXT_LENGTH = 1_200
MAX_REQUEST_BYTES = 16_384
MAX_AUDIO_BYTES = 6_000_000
UPSTREAM_URL = "http://piper:5000/synthesize"


class GatewayError(Exception):
    def __init__(self, status: int, message: str) -> None:
        super().__init__(message)
        self.status = status


def authorized(authorization: str | None, token: str) -> bool:
    if not authorization or not token:
        return False
    scheme, separator, supplied = authorization.partition(" ")
    return (
        separator == " "
        and scheme.lower() == "bearer"
        and hmac.compare_digest(supplied, token)
    )


def prepare_request(body: bytes) -> dict[str, str]:
    if not body or len(body) > MAX_REQUEST_BYTES:
        raise GatewayError(413, "Request body is too large or empty.")
    try:
        request: Any = json.loads(body)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise GatewayError(400, "Request body must be valid JSON.") from error
    if not isinstance(request, dict):
        raise GatewayError(400, "Request body must be an object.")

    text = request.get("text")
    language = request.get("language")
    if not isinstance(text, str) or not text.strip() or len(text) > MAX_TEXT_LENGTH:
        raise GatewayError(400, "Text must contain 1 to 1200 characters.")
    if not isinstance(language, str) or language not in VOICES:
        raise GatewayError(422, "No Piper voice is configured for this language.")
    return {"text": text.strip(), "voice": VOICES[language]}


def synthesize(payload: dict[str, str]) -> bytes:
    request_body = json.dumps(
        {
            "text": payload["text"],
            "voice": payload["voice"],
            "length_scale": 1.1,
        }
    ).encode("utf-8")
    upstream_request = urllib.request.Request(
        UPSTREAM_URL,
        data=request_body,
        headers={"Content-Type": "application/json", "Accept": "audio/wav"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(upstream_request, timeout=45) as response:
            if response.headers.get_content_type() != "audio/wav":
                raise GatewayError(502, "Piper returned an unsupported audio format.")
            audio = response.read(MAX_AUDIO_BYTES + 1)
    except urllib.error.HTTPError as error:
        if error.code == 422:
            raise GatewayError(422, "No Piper voice is configured for this language.") from error
        raise GatewayError(502, "Piper speech service is unavailable.") from error
    except (urllib.error.URLError, TimeoutError) as error:
        raise GatewayError(502, "Piper speech service is unavailable.") from error

    if (
        len(audio) < 44
        or len(audio) > MAX_AUDIO_BYTES
        or audio[:4] != b"RIFF"
        or audio[8:12] != b"WAVE"
    ):
        raise GatewayError(502, "Piper returned invalid WAV audio.")
    return audio


class PiperGatewayHandler(BaseHTTPRequestHandler):
    server_version = "MozhiPiperGateway"
    sys_version = ""

    def do_GET(self) -> None:
        if self.path != "/healthz":
            self._send_json(404, {"error": "Not found."})
            return
        self._send_json(200, {"status": "ok"})

    def do_POST(self) -> None:
        if self.path != "/synthesize":
            self._send_json(404, {"error": "Not found."})
            return
        token = os.environ.get("PIPER_API_TOKEN", "")
        if not authorized(self.headers.get("Authorization"), token):
            self._send_json(401, {"error": "Unauthorized."})
            return

        try:
            content_length = int(self.headers.get("Content-Length", "0"))
            if content_length <= 0 or content_length > MAX_REQUEST_BYTES:
                raise GatewayError(413, "Request body is too large or empty.")
            payload = prepare_request(self.rfile.read(content_length))
            audio = synthesize(payload)
        except (ValueError, GatewayError) as error:
            status = error.status if isinstance(error, GatewayError) else 400
            self._send_json(status, {"error": str(error)})
            return

        self.send_response(200)
        self.send_header("Content-Type", "audio/wav")
        self.send_header("Content-Length", str(len(audio)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(audio)

    def _send_json(self, status: int, body: dict[str, str]) -> None:
        encoded = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, format: str, *args: object) -> None:
        print(f"{self.address_string()} {format % args}")


def main() -> None:
    token = os.environ.get("PIPER_API_TOKEN", "")
    if len(token) < 32 or not re.fullmatch(r"[A-Za-z0-9_-]+", token):
        raise RuntimeError(
            "PIPER_API_TOKEN must be at least 32 URL-safe random characters."
        )
    server = ThreadingHTTPServer(("0.0.0.0", 8080), PiperGatewayHandler)
    server.serve_forever()


if __name__ == "__main__":
    main()

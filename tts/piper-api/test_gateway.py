import json
import unittest
from email.message import Message
from unittest.mock import Mock, patch

import gateway


class _FakeResponse:
    def __init__(self, audio: bytes, content_type: str = "audio/wav") -> None:
        self.headers = Message()
        self.headers["Content-Type"] = content_type
        self.audio = audio

    def __enter__(self) -> "_FakeResponse":
        return self

    def __exit__(self, *_: object) -> None:
        return None

    def read(self, limit: int) -> bytes:
        return self.audio[:limit]


def _wav() -> bytes:
    return b"RIFF" + (b"\x00" * 4) + b"WAVE" + (b"\x00" * 36)


class PiperGatewayTests(unittest.TestCase):
    def test_requires_constant_time_bearer_authentication(self) -> None:
        self.assertTrue(gateway.authorized("Bearer " + "x" * 40, "x" * 40))
        self.assertFalse(gateway.authorized("Bearer wrong", "x" * 40))
        self.assertFalse(gateway.authorized("Basic " + "x" * 40, "x" * 40))
        self.assertFalse(gateway.authorized(None, "x" * 40))

    def test_maps_only_configured_languages_to_piper_voices(self) -> None:
        request = gateway.prepare_request(
            json.dumps({"text": "  നമസ്കാരം ", "language": "Malayalam"}).encode()
        )
        self.assertEqual(request, {"text": "നമസ്കാരം", "voice": "ml_IN-meera-medium"})

        with self.assertRaises(gateway.GatewayError) as error:
            gateway.prepare_request(
                json.dumps({"text": "Bonjour", "language": "Klingon"}).encode()
            )
        self.assertEqual(error.exception.status, 422)

    def test_rejects_empty_oversized_and_invalid_requests(self) -> None:
        for body in (b"", b"{" * (gateway.MAX_REQUEST_BYTES + 1), b"[]"):
            with self.subTest(body_length=len(body)):
                with self.assertRaises(gateway.GatewayError):
                    gateway.prepare_request(body)

        with self.assertRaises(gateway.GatewayError) as error:
            gateway.prepare_request(
                json.dumps(
                    {"text": "x" * 1_201, "language": "English"}
                ).encode()
            )
        self.assertEqual(error.exception.status, 400)

    @patch("gateway.urllib.request.urlopen")
    def test_forwards_mapped_voice_and_returns_valid_wav(self, urlopen: Mock) -> None:
        urlopen.return_value = _FakeResponse(_wav())
        result = gateway.synthesize({"text": "Hello", "voice": "en_US-lessac-medium"})

        request = urlopen.call_args.args[0]
        self.assertEqual(request.full_url, gateway.UPSTREAM_URL)
        self.assertEqual(request.get_method(), "POST")
        self.assertEqual(
            json.loads(request.data),
            {
                "text": "Hello",
                "voice": "en_US-lessac-medium",
                "length_scale": 1.1,
            },
        )
        self.assertEqual(result, _wav())

    @patch("gateway.urllib.request.urlopen")
    def test_rejects_wrong_format_and_malformed_wav(self, urlopen: Mock) -> None:
        urlopen.return_value = _FakeResponse(_wav(), "application/json")
        with self.assertRaises(gateway.GatewayError):
            gateway.synthesize({"text": "Hello", "voice": "en_US-lessac-medium"})

        urlopen.return_value = _FakeResponse(b"not-a-wave-file")
        with self.assertRaises(gateway.GatewayError):
            gateway.synthesize({"text": "Hello", "voice": "en_US-lessac-medium"})

    @patch("gateway.urllib.request.urlopen")
    def test_caps_upstream_audio_size(self, urlopen: Mock) -> None:
        oversized = b"RIFF" + (b"\x00" * 4) + b"WAVE" + (
            b"\x00" * gateway.MAX_AUDIO_BYTES
        )
        urlopen.return_value = _FakeResponse(oversized)
        with self.assertRaises(gateway.GatewayError):
            gateway.synthesize({"text": "Hello", "voice": "en_US-lessac-medium"})


if __name__ == "__main__":
    unittest.main()

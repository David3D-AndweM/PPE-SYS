import base64
import hashlib
import hmac
import io
import json

import qrcode
from django.conf import settings


def _sign(payload_str: str) -> str:
    """Return a truncated HMAC-SHA256 hex digest for the payload string."""
    return hmac.new(
        settings.QR_SECRET_KEY.encode(),
        payload_str.encode(),
        hashlib.sha256,
    ).hexdigest()[:24]


def generate_slip_qr_payload(slip_id: str) -> str:
    """
    Returns a base64url-encoded, HMAC-signed QR payload string.
    Format (before encoding): JSON|SIG
    """
    data = {"slip_id": str(slip_id), "v": 1}
    raw = json.dumps(data, separators=(",", ":"), sort_keys=True)
    sig = _sign(raw)
    combined = f"{raw}|{sig}"
    return base64.urlsafe_b64encode(combined.encode()).decode()


def verify_slip_qr_payload(raw_qr: str) -> dict:
    """
    Decodes and verifies a QR payload. Returns the parsed dict on success.
    Raises ValueError if the signature is invalid or the format is wrong.
    """
    try:
        decoded = base64.urlsafe_b64decode(raw_qr.encode()).decode()
        parts = decoded.rsplit("|", 1)
        if len(parts) != 2:
            raise ValueError("Invalid QR format: missing separator")
        raw, received_sig = parts
        expected_sig = _sign(raw)
        if not hmac.compare_digest(expected_sig, received_sig):
            raise ValueError("QR signature verification failed")
        return json.loads(raw)
    except (ValueError, KeyError) as exc:
        raise ValueError(f"QR verification error: {exc}") from exc


def generate_qr_image_base64(payload: str) -> str:
    """
    Renders the payload string as a QR code PNG and returns it as a
    base64-encoded data URI string suitable for embedding in JSON responses.
    """
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=8,
        border=4,
    )
    qr.add_data(payload)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    buffer = io.BytesIO()
    img.save(buffer, format="PNG")
    encoded = base64.b64encode(buffer.getvalue()).decode()
    return f"data:image/png;base64,{encoded}"

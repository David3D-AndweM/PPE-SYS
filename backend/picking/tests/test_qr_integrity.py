"""
QR code integrity tests.
Covers: valid token verification, tampered payload rejection, missing token rejection.
"""

import base64
import uuid

import pytest

from core.utils.qr import generate_slip_qr_payload, verify_slip_qr_payload


def test_valid_qr_token_verifies():
    slip_id = str(uuid.uuid4())
    token = generate_slip_qr_payload(slip_id)
    result = verify_slip_qr_payload(token)
    assert result["slip_id"] == slip_id
    assert result["v"] == 1


def test_tampered_payload_fails():
    slip_id = str(uuid.uuid4())
    token = generate_slip_qr_payload(slip_id)

    # Decode, flip a byte in the raw payload, re-encode
    decoded = base64.urlsafe_b64decode(token.encode()).decode()
    # Tamper with the first character of the JSON portion
    tampered = decoded[0:2] + ("X" if decoded[2] != "X" else "Y") + decoded[3:]
    tampered_token = base64.urlsafe_b64encode(tampered.encode()).decode()

    with pytest.raises(ValueError):
        verify_slip_qr_payload(tampered_token)


@pytest.mark.django_db
def test_missing_token_returns_401_or_400(store_client):
    response = store_client.post(
        "/api/v1/picking/slips/validate-scan/",
        {},
        format="json",
    )
    assert response.status_code in (400, 401)

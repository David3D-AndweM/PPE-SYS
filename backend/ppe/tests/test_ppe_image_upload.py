from io import BytesIO

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image


def _png_file(name: str) -> SimpleUploadedFile:
    buffer = BytesIO()
    Image.new("RGB", (1, 1), color=(255, 0, 0)).save(buffer, format="PNG")
    return SimpleUploadedFile(name, buffer.getvalue(), content_type="image/png")


@pytest.mark.django_db
def test_safety_can_create_ppe_item_with_image(safety_client):
    file = _png_file("helmet.png")
    resp = safety_client.post(
        "/api/v1/ppe/items/",
        {
            "name": "Helmet Image Upload Test",
            "category": "head",
            "default_validity_days": 365,
            "image": file,
        },
        format="multipart",
    )

    assert resp.status_code == 201
    assert resp.data.get("image")

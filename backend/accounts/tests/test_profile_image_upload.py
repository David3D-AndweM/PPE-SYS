import base64
from io import BytesIO

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image


def _png_file(name: str) -> SimpleUploadedFile:
    buffer = BytesIO()
    Image.new("RGB", (1, 1), color=(255, 0, 0)).save(buffer, format="PNG")
    return SimpleUploadedFile(name, buffer.getvalue(), content_type="image/png")


@pytest.mark.django_db
def test_authenticated_user_can_upload_profile_image(manager_client):
    file = _png_file("avatar.png")

    resp = manager_client.patch(
        "/api/v1/auth/me/",
        {"profile_image": file},
        format="multipart",
    )

    assert resp.status_code == 200
    assert resp.data.get("profile_image")

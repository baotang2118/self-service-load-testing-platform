import json
import os
import uuid
from urllib.error import HTTPError
from urllib.request import Request, urlopen

import pytest


def call(base, method, path, body=None):
    payload = None if body is None else json.dumps(body).encode()
    request = Request(
        base + path,
        data=payload,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    try:
        response = urlopen(request, timeout=5)
    except HTTPError as error:
        response = error
    with response:
        content = response.read()
        return response.status, json.loads(content) if content else None


@pytest.mark.parametrize("service", ["django", "go"])
def test_running_services(service):
    urls = {
        "django": os.getenv("DEMO_DJANGO_URL"),
        "go": os.getenv("DEMO_GO_URL"),
    }
    if not all(urls.values()):
        pytest.skip("set DEMO_DJANGO_URL and DEMO_GO_URL to run integration tests")
    base = urls[service].rstrip("/")
    other = urls["go" if service == "django" else "django"].rstrip("/")
    name = f"integration-{uuid.uuid4()}"
    assert call(base, "GET", "/health/ready")[0] == 200
    status, item = call(base, "POST", "/api/items", {"name": name})
    assert status == 201
    path = f"/api/items/{item['id']}"
    try:
        assert item in call(base, "GET", "/api/items")[1]
        assert call(base, "GET", path) == (200, item)
        status, updated = call(
            base, "PUT", path, {"name": name + "-updated", "description": "demo"}
        )
        assert status == 200
        assert call(base, "GET", path) == (200, updated)
        assert all(
            value["name"] != name for value in call(other, "GET", "/api/items")[1]
        )
    finally:
        call(base, "DELETE", path)
    assert call(base, "GET", path)[0] == 404

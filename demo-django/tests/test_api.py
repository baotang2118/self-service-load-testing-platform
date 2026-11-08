import json
from unittest.mock import patch

import pytest
from django.core.cache import cache


@pytest.mark.django_db
def test_crud_and_invalidation(client):
    cache.clear()
    response = client.post(
        "/api/items",
        data=json.dumps({"name": "first"}),
        content_type="application/json",
    )
    assert response.status_code == 201
    item = response.json()
    path = f"/api/items/{item['id']}"
    assert client.get("/api/items").json() == [item]
    assert client.get(path).json() == item
    response = client.put(
        path,
        data=json.dumps({"name": "updated", "description": "demo"}),
        content_type="application/json",
    )
    assert response.status_code == 200
    assert client.get(path).json()["name"] == "updated"
    assert client.delete(path).status_code == 204
    assert client.get(path).status_code == 404


@pytest.mark.django_db
def test_invalid_requests_and_methods(client):
    for data in (
        "invalid",
        "[]",
        '{"name":" "}',
        '{"name":1}',
        '{"name":"x","description":null}',
    ):
        assert (
            client.post(
                "/api/items", data=data, content_type="application/json"
            ).status_code
            == 400
        )
    assert client.post("/api/items/1").status_code == 405
    assert client.get("/api/items/1").status_code == 404
    assert (
        client.put(
            "/api/items/1", data="{}", content_type="application/json"
        ).status_code
        == 400
    )
    assert (
        client.put(
            "/api/items/1", data='{"name":"x"}', content_type="application/json"
        ).status_code
        == 404
    )


@pytest.mark.django_db
def test_cache_failure_falls_back_to_database(client):
    item = client.post(
        "/api/items", data='{"name":"example"}', content_type="application/json"
    ).json()
    with patch("items.views.cache.get", side_effect=ConnectionError):
        assert client.get(f"/api/items/{item['id']}").json() == item


@pytest.mark.django_db
def test_health(client):
    assert client.get("/health/live").status_code == 200
    with patch("items.views.redis.Redis.from_url") as factory:
        assert client.get("/health/ready").status_code == 200
        factory.return_value.ping.side_effect = ConnectionError
        assert client.get("/health/ready").status_code == 503

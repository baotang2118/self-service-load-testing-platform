import json
import logging

import redis
from django.conf import settings
from django.core.cache import cache
from django.db import connection
from django.http import HttpResponse, JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_http_methods

from .models import Item

logger = logging.getLogger(__name__)


def item_data(item):
    return {"id": item.pk, "name": item.name, "description": item.description}


def parse_item(request):
    try:
        data = json.loads(request.body)
    except (ValueError, UnicodeDecodeError):
        return None
    if not isinstance(data, dict):
        return None
    name = data.get("name")
    description = data.get("description", "")
    if not isinstance(name, str) or not name.strip() or len(name) > 255:
        return None
    if not isinstance(description, str):
        return None
    return {"name": name, "description": description}


def cache_call(method, *args):
    try:
        return getattr(cache, method)(*args)
    except Exception:
        logger.exception("Redis cache %s failed", method)
        return None


@csrf_exempt
@require_http_methods(["GET", "POST"])
def collection(request):
    if request.method == "GET":
        return JsonResponse(
            [item_data(item) for item in Item.objects.order_by("id")], safe=False
        )
    data = parse_item(request)
    if data is None:
        return JsonResponse({"error": "invalid item"}, status=400)
    return JsonResponse(item_data(Item.objects.create(**data)), status=201)


@csrf_exempt
@require_http_methods(["GET", "PUT", "DELETE"])
def detail(request, item_id):
    key = f"item:{item_id}"
    data = None
    if request.method == "PUT":
        data = parse_item(request)
        if data is None:
            return JsonResponse({"error": "invalid item"}, status=400)
    if request.method == "GET":
        cached = cache_call("get", key)
        if cached is not None:
            return JsonResponse(cached)
    try:
        item = Item.objects.get(pk=item_id)
    except Item.DoesNotExist:
        return JsonResponse({"error": "not found"}, status=404)
    if request.method == "GET":
        data = item_data(item)
        cache_call("set", key, data, 60)
        return JsonResponse(data)
    if request.method == "DELETE":
        item.delete()
        cache_call("delete", key)
        return HttpResponse(status=204)
    item.name = data["name"]
    item.description = data["description"]
    item.save()
    cache_call("delete", key)
    return JsonResponse(item_data(item))


@require_GET
def live(request):
    return JsonResponse({"status": "ok"})


@require_GET
def ready(request):
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
        redis.Redis.from_url(
            settings.REDIS_URL, socket_connect_timeout=1, socket_timeout=1
        ).ping()
    except Exception:
        logger.exception("Readiness check failed")
        return JsonResponse({"status": "unavailable"}, status=503)
    return JsonResponse({"status": "ok"})

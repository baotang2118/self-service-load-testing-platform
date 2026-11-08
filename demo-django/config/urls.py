from django.urls import path

from items import views

urlpatterns = [
    path("api/items", views.collection),
    path("api/items/<int:item_id>", views.detail),
    path("health/live", views.live),
    path("health/ready", views.ready),
]

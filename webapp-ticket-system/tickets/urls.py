from django.urls import path

from tickets import views

urlpatterns = [
    path("", views.dashboard, name="dashboard"),
    path("tickets/new/", views.create_ticket, name="ticket_create"),
    path("tickets/<int:ticket_id>/", views.ticket_detail, name="ticket_detail"),
    path("tickets/<int:ticket_id>/review/", views.review, name="ticket_review"),
]

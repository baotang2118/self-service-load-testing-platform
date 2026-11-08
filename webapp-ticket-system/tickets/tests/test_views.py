import pytest
from django.contrib.auth.models import Group, User
from django.test import Client
from django.urls import reverse

from tickets.models import Ticket


@pytest.mark.django_db
def test_creation_and_shared_dashboard(client):
    creator = User.objects.create_user(username="creator", password="password")
    other = User.objects.create_user(username="other", password="password")
    assert client.get(reverse("dashboard")).status_code == 302
    client.force_login(creator)
    response = client.post(
        reverse("ticket_create"), {"title": "Provision", "description": "A test"}
    )
    ticket = Ticket.objects.get()
    assert response.status_code == 302
    assert ticket.creator == creator
    assert ticket.status == Ticket.Status.WAITING
    client.force_login(other)
    assert b"Provision" in client.get(reverse("dashboard")).content
    assert client.get(reverse("ticket_detail", args=[ticket.pk])).status_code == 200


@pytest.mark.django_db
def test_review_requires_permission_and_csrf(client):
    developer = User.objects.create_user(username="dev")
    reviewer = User.objects.create_user(username="ops")
    reviewer.groups.add(Group.objects.get(name="DevOps"))
    ticket = Ticket.objects.create(
        title="Provision", description="Task", creator=developer
    )
    url = reverse("ticket_review", args=[ticket.pk])
    client.force_login(developer)
    assert client.post(url, {"decision": "approve"}).status_code == 403
    ticket.refresh_from_db()
    assert ticket.status == Ticket.Status.WAITING
    csrf_client = Client(enforce_csrf_checks=True)
    csrf_client.force_login(reviewer)
    assert csrf_client.post(url, {"decision": "approve"}).status_code == 403
    client.force_login(reviewer)
    assert client.get(url).status_code == 405
    assert client.post(url, {"decision": "approve"}).status_code == 302
    ticket.refresh_from_db()
    assert ticket.status == Ticket.Status.QUEUED
    assert (
        client.post(url, {"decision": "reject", "reason": "Too late"}).status_code
        == 302
    )
    ticket.refresh_from_db()
    assert ticket.status == Ticket.Status.QUEUED

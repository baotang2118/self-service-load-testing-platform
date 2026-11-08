import pytest
from django.contrib.auth.models import Group, User

from tickets.models import Ticket, review_ticket


@pytest.mark.django_db
def test_review_requires_devops_and_only_transitions_once():
    developer = User.objects.create_user(username="dev")
    reviewer = User.objects.create_user(username="ops")
    reviewer.groups.add(Group.objects.get(name="DevOps"))
    ticket = Ticket.objects.create(
        title="Deploy", description="Run task", creator=developer
    )
    assert ticket.status == Ticket.Status.WAITING
    with pytest.raises(PermissionError):
        review_ticket(ticket.pk, developer, True)
    ticket.refresh_from_db()
    assert ticket.status == Ticket.Status.WAITING
    assert review_ticket(ticket.pk, reviewer, True)
    assert not review_ticket(ticket.pk, reviewer, True)
    ticket.refresh_from_db()
    assert ticket.status == Ticket.Status.QUEUED
    assert ticket.reviewer == reviewer


@pytest.mark.django_db
def test_rejection_requires_reason():
    reviewer = User.objects.create_superuser(username="admin", password="password")
    ticket = Ticket.objects.create(
        title="Deploy", description="Run task", creator=reviewer
    )
    with pytest.raises(ValueError):
        review_ticket(ticket.pk, reviewer, False, " ")
    assert review_ticket(ticket.pk, reviewer, False, "Not ready")
    ticket.refresh_from_db()
    assert ticket.status == Ticket.Status.REJECTED
    assert ticket.rejection_reason == "Not ready"

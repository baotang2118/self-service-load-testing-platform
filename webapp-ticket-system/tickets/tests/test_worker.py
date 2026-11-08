import subprocess
from unittest.mock import patch

import pytest
from django.contrib.auth.models import User

from tickets.models import Ticket, review_ticket
from tickets.worker import fail_interrupted, run_next


@pytest.mark.django_db
def test_worker_only_runs_queued_ticket():
    user = User.objects.create_user(username="dev")
    waiting = Ticket.objects.create(title="Waiting", description="Task", creator=user)
    rejected = Ticket.objects.create(
        title="Rejected",
        description="Task",
        creator=user,
        status=Ticket.Status.REJECTED,
    )
    queued = Ticket.objects.create(
        title="Queued", description="Task", creator=user, status=Ticket.Status.QUEUED
    )
    with patch("tickets.worker.subprocess.run") as run:
        run.return_value = subprocess.CompletedProcess([], 0, stdout="Done", stderr="")
        assert run_next()
        assert not run_next()
        run.assert_called_once()
    queued.refresh_from_db()
    waiting.refresh_from_db()
    rejected.refresh_from_db()
    assert queued.status == Ticket.Status.COMPLETE
    assert queued.job_output == "Done"
    assert waiting.status == Ticket.Status.WAITING
    assert rejected.status == Ticket.Status.REJECTED


@pytest.mark.django_db
@pytest.mark.parametrize("timeout", [False, True])
def test_worker_records_failure(timeout):
    user = User.objects.create_user(username="dev")
    ticket = Ticket.objects.create(
        title="Failure",
        description="Task",
        creator=user,
        status=Ticket.Status.QUEUED,
        simulate_failure=True,
    )
    with patch("tickets.worker.subprocess.run") as run:
        if timeout:
            run.side_effect = subprocess.TimeoutExpired("task", 30)
        else:
            run.return_value = subprocess.CompletedProcess(
                [], 1, stdout="", stderr="Failed"
            )
        assert run_next()
        assert "--fail" in run.call_args.args[0]
    ticket.refresh_from_db()
    assert ticket.status == Ticket.Status.FAIL
    assert ticket.finished_at is not None
    assert ticket.job_output == ("Task timed out." if timeout else "Failed")


@pytest.mark.django_db
def test_interrupted_tasks_fail_without_retry():
    user = User.objects.create_user(username="dev")
    ticket = Ticket.objects.create(
        title="Interrupted",
        description="Task",
        creator=user,
        status=Ticket.Status.RUNNING,
    )
    assert fail_interrupted() == 1
    ticket.refresh_from_db()
    assert ticket.status == Ticket.Status.FAIL
    assert not run_next()


@pytest.mark.django_db
@pytest.mark.parametrize(
    "simulate_failure, expected",
    [(False, Ticket.Status.COMPLETE), (True, Ticket.Status.FAIL)],
)
def test_approved_ticket_runs_real_script(simulate_failure, expected):
    user = User.objects.create_superuser(username="admin", password="password")
    ticket = Ticket.objects.create(
        title="Real task",
        description="Task",
        creator=user,
        simulate_failure=simulate_failure,
    )
    assert not run_next()
    assert review_ticket(ticket.pk, user, True)
    assert run_next()
    ticket.refresh_from_db()
    assert ticket.status == expected
    assert ticket.job_output

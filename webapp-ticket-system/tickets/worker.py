import subprocess
import sys
from pathlib import Path

from django.utils import timezone

from tickets.models import Ticket

SCRIPT = Path(__file__).resolve().parent / "placeholder_task.py"
OUTPUT_LIMIT = 4000
TASK_TIMEOUT = 30


def fail_interrupted():
    now = timezone.now()
    return Ticket.objects.filter(status=Ticket.Status.RUNNING).update(
        status=Ticket.Status.FAIL,
        job_output="Worker stopped before the task finished.",
        finished_at=now,
        updated_at=now,
    )


def run_next():
    ticket = (
        Ticket.objects.filter(status=Ticket.Status.QUEUED)
        .order_by("created_at", "id")
        .first()
    )
    if ticket is None:
        return False
    now = timezone.now()
    claimed = Ticket.objects.filter(pk=ticket.pk, status=Ticket.Status.QUEUED).update(
        status=Ticket.Status.RUNNING, started_at=now, updated_at=now
    )
    if not claimed:
        return False
    try:
        command = [sys.executable, str(SCRIPT)]
        if ticket.simulate_failure:
            command.append("--fail")
        result = subprocess.run(
            command, capture_output=True, text=True, timeout=TASK_TIMEOUT, check=False
        )
        status = (
            Ticket.Status.COMPLETE if result.returncode == 0 else Ticket.Status.FAIL
        )
        output = "\n".join(
            part for part in (result.stdout.strip(), result.stderr.strip()) if part
        )
    except subprocess.TimeoutExpired:
        status = Ticket.Status.FAIL
        output = "Task timed out."
    except OSError as error:
        status = Ticket.Status.FAIL
        output = f"Unable to start task: {error}"
    now = timezone.now()
    Ticket.objects.filter(pk=ticket.pk, status=Ticket.Status.RUNNING).update(
        status=status, job_output=output[:OUTPUT_LIMIT], finished_at=now, updated_at=now
    )
    return True

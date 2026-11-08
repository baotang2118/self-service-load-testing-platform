from django.conf import settings
from django.db import models
from django.utils import timezone


class Ticket(models.Model):
    class Status(models.TextChoices):
        WAITING = "waiting", "Waiting for approval"
        QUEUED = "queued", "Queued"
        RUNNING = "running", "Running"
        COMPLETE = "complete", "Complete"
        FAIL = "fail", "Fail"
        REJECTED = "rejected", "Rejected"

    title = models.CharField(max_length=200)
    description = models.TextField()
    creator = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="created_tickets",
    )
    status = models.CharField(
        max_length=16, choices=Status.choices, default=Status.WAITING, db_index=True
    )
    simulate_failure = models.BooleanField(default=False)
    reviewer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="reviewed_tickets",
        null=True,
        blank=True,
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    rejection_reason = models.TextField(blank=True)
    job_output = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    started_at = models.DateTimeField(null=True, blank=True)
    finished_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at", "-id"]

    def __str__(self):
        return f"#{self.pk} {self.title}"


def review_ticket(ticket_id, reviewer, approved, reason=""):
    if not (reviewer.is_superuser or reviewer.groups.filter(name="DevOps").exists()):
        raise PermissionError("Only DevOps users can review tickets.")
    reason = reason.strip()
    if not approved and not reason:
        raise ValueError("A rejection reason is required.")
    now = timezone.now()
    return bool(
        Ticket.objects.filter(pk=ticket_id, status=Ticket.Status.WAITING).update(
            status=Ticket.Status.QUEUED if approved else Ticket.Status.REJECTED,
            reviewer=reviewer,
            reviewed_at=now,
            rejection_reason="" if approved else reason,
            updated_at=now,
        )
    )

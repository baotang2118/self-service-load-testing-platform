from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.core.exceptions import PermissionDenied
from django.db.models import Count
from django.shortcuts import get_object_or_404, redirect, render
from django.views.decorators.http import require_POST

from tickets.forms import TicketForm
from tickets.models import Ticket, review_ticket


def can_review(user):
    return user.is_superuser or user.groups.filter(name="DevOps").exists()


@login_required
def dashboard(request):
    tickets = Ticket.objects.select_related("creator", "reviewer")
    counts = dict(Ticket.objects.values_list("status").annotate(total=Count("id")))
    selected_status = request.GET.get("status", "")
    if selected_status in Ticket.Status.values:
        tickets = tickets.filter(status=selected_status)
    else:
        selected_status = ""
    return render(
        request,
        "tickets/dashboard.html",
        {
            "tickets": tickets,
            "statuses": Ticket.Status.choices,
            "selected_status": selected_status,
            "total_count": sum(counts.values()),
            "waiting_count": counts.get(Ticket.Status.WAITING, 0),
            "active_count": counts.get(Ticket.Status.QUEUED, 0)
            + counts.get(Ticket.Status.RUNNING, 0),
            "complete_count": counts.get(Ticket.Status.COMPLETE, 0),
        },
    )


@login_required
def create_ticket(request):
    form = TicketForm(request.POST or None)
    if request.method == "POST" and form.is_valid():
        ticket = form.save(commit=False)
        ticket.creator = request.user
        ticket.save()
        messages.success(request, "Ticket submitted for approval.")
        return redirect("ticket_detail", ticket_id=ticket.pk)
    return render(request, "tickets/create.html", {"form": form})


@login_required
def ticket_detail(request, ticket_id):
    ticket = get_object_or_404(
        Ticket.objects.select_related("creator", "reviewer"), pk=ticket_id
    )
    return render(
        request,
        "tickets/detail.html",
        {"ticket": ticket, "can_review": can_review(request.user)},
    )


@login_required
@require_POST
def review(request, ticket_id):
    get_object_or_404(Ticket, pk=ticket_id)
    if not can_review(request.user):
        raise PermissionDenied
    decision = request.POST.get("decision")
    if decision not in ("approve", "reject"):
        messages.error(request, "Choose a valid review decision.")
        return redirect("ticket_detail", ticket_id=ticket_id)
    try:
        changed = review_ticket(
            ticket_id,
            request.user,
            decision == "approve",
            request.POST.get("reason", ""),
        )
    except ValueError as error:
        messages.error(request, str(error))
    else:
        if changed:
            messages.success(
                request,
                "Ticket approved and queued."
                if decision == "approve"
                else "Ticket rejected.",
            )
        else:
            messages.error(request, "This ticket has already been reviewed.")
    return redirect("ticket_detail", ticket_id=ticket_id)

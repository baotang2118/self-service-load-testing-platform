from django import forms

from tickets.models import Ticket


class TicketForm(forms.ModelForm):
    class Meta:
        model = Ticket
        fields = ["title", "description", "simulate_failure"]
        labels = {"simulate_failure": "Simulate task failure (demo only)"}
        widgets = {
            "title": forms.TextInput(
                attrs={
                    "class": "form-control",
                    "placeholder": "e.g. Provision a test environment",
                }
            ),
            "description": forms.Textarea(attrs={"class": "form-control", "rows": 6}),
            "simulate_failure": forms.CheckboxInput(
                attrs={"class": "form-check-input"}
            ),
        }

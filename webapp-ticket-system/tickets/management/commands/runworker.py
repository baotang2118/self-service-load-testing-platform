import time

from django.core.management.base import BaseCommand

from tickets.worker import fail_interrupted, run_next


class Command(BaseCommand):
    help = "Run the single ticket worker."

    def handle(self, *args, **options):
        interrupted = fail_interrupted()
        self.stdout.write(
            f"Worker started. Marked {interrupted} interrupted ticket(s) as failed."
        )
        try:
            while True:
                if not run_next():
                    time.sleep(1)
        except KeyboardInterrupt:
            self.stdout.write("Worker stopped.")

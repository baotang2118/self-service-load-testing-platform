# Opsdesk ticket demo

A local Django and SQLite demo for submitting DevOps requests, approving or rejecting them, and running a fixed placeholder task after approval.

## Docker setup

Requires Docker with Compose. From this directory:

```sh
docker compose up --build -d
docker compose exec web python manage.py createsuperuser
```

Open http://127.0.0.1:8000/ and sign in. The SQLite database is stored in the `ticket-data` Docker volume. To stop the containers without deleting the data, run `docker compose down`.

## Local uv setup

Requires Python 3.12 to 3.14 and [uv](https://docs.astral.sh/uv/). From this directory:

```sh
uv venv
uv sync --locked
uv run python manage.py migrate
uv run python manage.py createsuperuser
uv run python manage.py runserver
```

In a second terminal in the same directory, start exactly one worker:

```sh
uv run python manage.py runworker
```

The local database defaults to `db.sqlite3` in this directory. Set `SQLITE_PATH` to an absolute database file path to use a different location. The containing directory must already exist and be writable. Both processes must use the same path.

## Demo workflow

1. Sign in as the superuser and open `/admin/`. Create developer and DevOps users under **Users**; assign the automatically created **DevOps** group to the reviewers. Neither role needs staff access. Superusers may also review tickets.
2. Sign in as a developer and submit a ticket. It remains **Waiting for approval**, and no task runs.
3. Sign in as a DevOps user, open the ticket and approve it. The status moves through **Queued** and **Running** to **Complete**. To exercise failure, select **Simulate task failure** when creating a ticket; after approval it ends in **Fail**.
4. Alternatively, reject a waiting ticket with a reason. Rejected tickets do not run. Everyone signed in can view all tickets and their results.

The single worker runs only a fixed placeholder script, not commands supplied by users. It polls once a second and uses a 30-second timeout. There are no retries. If the worker stops during a job, its next startup marks that ticket **Fail**; queued work waits until the worker restarts. Do not start multiple workers: startup recovery assumes the worker is the only one. For worker logs, use `docker compose logs -f worker`.

## Verification

```sh
uv run pytest
uv run ruff check .
uv run ruff format --check .
```

This is a demo, not a production deployment: it uses Django's development server, a demo secret and debug mode by default, SQLite, and a single worker. Do not expose it publicly or run real infrastructure tasks without additional security and operational controls. Bootstrap and fonts load from external CDNs.
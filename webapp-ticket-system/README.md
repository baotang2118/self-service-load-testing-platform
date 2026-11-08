# Opsdesk ticket demo

A local Django and PostgreSQL demo for submitting DevOps requests, approving or rejecting them, and running a fixed placeholder task after approval.

## Docker setup

Requires Docker with Compose. From this directory:

```sh
docker compose up --build -d
docker compose exec web python manage.py createsuperuser
```

Open http://127.0.0.1:8000/ and sign in. Compose starts a local PostgreSQL server and stores its data in the `postgres-data` Docker volume. To stop the containers without deleting the data, run `docker compose down`.

The local database defaults to database `tickets`, user `tickets`, and password `tickets-local-only`. It is exposed on `127.0.0.1:5432`; set `POSTGRES_PUBLISHED_PORT` if that port is in use. These credentials are for local development only.

To use another PostgreSQL server, set `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_HOST`, and `POSTGRES_PORT` in your environment or a local `.env` file before starting Compose. The host must be reachable from inside the containers. Set `PGSSLMODE` when required by the server, for example `require` or `verify-full` (the default is `prefer`). Compose still starts its local database service, but the application connects to the configured host. The Compose database credentials initialize a new volume only; changing them later does not change an existing database's credentials.

## Local uv setup

Requires Python 3.12 to 3.14, [uv](https://docs.astral.sh/uv/), and a running PostgreSQL server. Set `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_HOST`, and `POSTGRES_PORT` as needed before running the commands below. The defaults are `tickets`, `tickets`, an empty password, `localhost`, and `5432`, respectively. Set `PGSSLMODE` if your server requires it. Both the web process and worker need the same settings. From this directory:

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

For example, to use the Compose PostgreSQL service locally, run `docker compose up -d db` and set `POSTGRES_PASSWORD` to `tickets-local-only` in both terminals. A Compose `.env` file is not automatically loaded by local `uv run` commands.

Running migrations creates tables in PostgreSQL; it does not transfer existing data from SQLite. The existing SQLite database remains untouched.

## Demo workflow

1. Sign in as the superuser and open `/admin/`. Create developer and DevOps users under **Users**; assign the automatically created **DevOps** group to the reviewers. Neither role needs staff access. Superusers may also review tickets.
2. Sign in as a developer and submit a ticket. It remains **Waiting for approval**, and no task runs.
3. Sign in as a DevOps user, open the ticket and approve it. The status moves through **Queued** and **Running** to **Complete**. To exercise failure, select **Simulate task failure** when creating a ticket; after approval it ends in **Fail**.
4. Alternatively, reject a waiting ticket with a reason. Rejected tickets do not run. Everyone signed in can view all tickets and their results.

The single worker runs only a fixed placeholder script, not commands supplied by users. It polls once a second and uses a 30-second timeout. There are no retries. If the worker stops during a job, its next startup marks that ticket **Fail**; queued work waits until the worker restarts. Do not start multiple workers: startup recovery assumes the worker is the only one. For worker logs, use `docker compose logs -f worker`.

## Helm deployment

The repository includes a Helm chart for the web process and single worker at [`charts/webapp-ticket-system`](../charts/webapp-ticket-system/README.md). It connects to an external PostgreSQL service and runs migrations before deploying the app.

## Verification

The PostgreSQL user must have permission to create a test database for pytest. Configure the connection as described above before running:

```sh
uv run pytest
uv run ruff check .
uv run ruff format --check .
```

This is a demo, not a production deployment: it uses Django's development server, a demo secret and debug mode by default, local development database credentials, and a single worker. Do not expose it publicly or run real infrastructure tasks without additional security and operational controls. Bootstrap and fonts load from external CDNs.
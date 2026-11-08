import json
import os
import subprocess
import sys
from pathlib import Path

import pytest


@pytest.mark.parametrize("configured", [False, True])
def test_postgresql_settings(configured):
    environment = os.environ.copy()
    values = {
        "POSTGRES_DB": "custom_db",
        "POSTGRES_USER": "custom_user",
        "POSTGRES_PASSWORD": "custom_password",
        "POSTGRES_HOST": "custom_host",
        "POSTGRES_PORT": "6543",
    }
    for name in values:
        environment.pop(name, None)
    if configured:
        environment.update(values)
    result = subprocess.run(
        [
            sys.executable,
            "-c",
            (
                "import json; from config.settings import DATABASES; "
                "print(json.dumps(DATABASES['default']))"
            ),
        ],
        cwd=Path(__file__).resolve().parents[2],
        env=environment,
        capture_output=True,
        text=True,
        check=True,
    )
    database = json.loads(result.stdout)
    assert database == {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": values["POSTGRES_DB"] if configured else "tickets",
        "USER": values["POSTGRES_USER"] if configured else "tickets",
        "PASSWORD": values["POSTGRES_PASSWORD"] if configured else "",
        "HOST": values["POSTGRES_HOST"] if configured else "localhost",
        "PORT": values["POSTGRES_PORT"] if configured else "5432",
    }

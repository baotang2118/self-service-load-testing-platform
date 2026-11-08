# Django CRUD demo

This chart deploys the standalone Django demo and runs its migrations in an init
container. See the repository [README](../../README.md#demo-crud-services) for
the dependency releases, image build, installation, configuration, and tests.
Use a single replica; concurrent migration coordination is out of scope.
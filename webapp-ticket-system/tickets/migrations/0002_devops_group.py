from django.db import migrations


def create_devops_group(apps, schema_editor):
    group = apps.get_model("auth", "Group")
    group.objects.using(schema_editor.connection.alias).get_or_create(name="DevOps")


class Migration(migrations.Migration):
    dependencies = [
        ("tickets", "0001_initial"),
        ("auth", "0012_alter_user_first_name_max_length"),
    ]
    operations = [migrations.RunPython(create_devops_group, migrations.RunPython.noop)]

from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("ppe", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="ppeitem",
            name="image",
            field=models.ImageField(blank=True, null=True, upload_to="ppe-items/"),
        ),
    ]

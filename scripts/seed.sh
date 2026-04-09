#!/usr/bin/env bash
set -e

cd /app

echo "==> Running migrations..."
python manage.py migrate

echo "==> Loading fixtures..."
python manage.py loaddata ../fixtures/01_roles.json
python manage.py loaddata ../fixtures/02_organizations.json
python manage.py loaddata ../fixtures/03_sites.json
python manage.py loaddata ../fixtures/04_departments.json
python manage.py loaddata ../fixtures/05_ppe_items.json
python manage.py loaddata ../fixtures/06_ppe_configurations.json
python manage.py loaddata ../fixtures/07_warehouses.json
python manage.py loaddata ../fixtures/08_users.json
python manage.py loaddata ../fixtures/08b_user_roles.json
python manage.py loaddata ../fixtures/09_employees.json
python manage.py loaddata ../fixtures/10_department_ppe_requirements.json
python manage.py loaddata ../fixtures/11_stock_items.json
python manage.py loaddata ../fixtures/12_employee_ppe.json
python manage.py loaddata ../fixtures/13_picking_slips_demo.json

echo "==> Creating superuser (admin@aucricmines.com / Admin1234!)..."
DJANGO_SUPERUSER_EMAIL=admin@auricmines.com \
DJANGO_SUPERUSER_PASSWORD=Admin1234! \
DJANGO_SUPERUSER_FIRST_NAME=System \
DJANGO_SUPERUSER_LAST_NAME=Admin \
python manage.py createsuperuser --noinput 2>/dev/null || echo "Superuser already exists, skipping."

echo "==> Seed complete. Login: admin@auricmines.com / Admin1234!"

.PHONY: dev down migrate seed setup test shell logs reset

# Start all services (foreground — blocks terminal)
dev:
	docker compose up --build

# Start in background
dev-d:
	docker compose up --build -d

# First-time setup: start services, wait for backend, seed data, then show logs
setup:
	docker compose up --build -d
	@echo "==> Waiting for backend to be ready..."
	@until docker compose exec backend python manage.py check --deploy 2>/dev/null || \
	       docker compose exec backend python manage.py check 2>/dev/null; do \
	    echo "    backend not ready yet, retrying in 3s..."; \
	    sleep 3; \
	done
	$(MAKE) seed
	@echo "==> Setup complete. Starting logs (Ctrl+C to exit)..."
	docker compose logs -f backend celery_worker

# Stop all services
down:
	docker compose down

# Stop and remove volumes (full reset)
reset:
	docker compose down -v

# Run migrations (services must be running — use 'make dev-d' first)
migrate:
	docker compose exec backend python manage.py migrate

# Seed demo data (starts services if not running, waits for backend health)
seed:
	@if ! docker compose ps --status running backend 2>/dev/null | grep -q "backend"; then \
	    echo "==> Starting services in background first..."; \
	    docker compose up --build -d; \
	    echo "==> Waiting for backend..."; \
	    sleep 5; \
	    until docker compose exec -T backend python manage.py check >/dev/null 2>&1; do \
	        echo "    still waiting..."; sleep 3; \
	    done; \
	fi
	docker compose exec -T backend bash /scripts/seed.sh

# Run backend tests
test:
	docker compose exec backend pytest --cov=. --cov-report=term-missing -x

# Open Django shell
shell:
	docker compose exec backend python manage.py shell

# Tail backend logs
logs:
	docker compose logs -f backend celery_worker

# Create superuser interactively
superuser:
	docker compose exec backend python manage.py createsuperuser

# Collect static files
static:
	docker compose exec backend python manage.py collectstatic --noinput

# Generate new migrations for a specific app (usage: make makemigrations app=ppe)
makemigrations:
	docker compose exec backend python manage.py makemigrations $(app)

# Format code with black
fmt:
	docker compose exec backend black .

# Run celery task manually (usage: make task name=celery_tasks.expiry_engine.run_expiry_check)
task:
	docker compose exec celery_worker celery -A celery_tasks.app call $(name)

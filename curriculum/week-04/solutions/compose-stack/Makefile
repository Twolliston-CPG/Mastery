.PHONY: help tls up down verify logs clean sizes

help:
	@grep -E '^[a-z-]+:.*?##' $(MAKEFILE_LIST) | awk -F':.*?## ' '{printf "  %-10s %s\n", $$1, $$2}'

tls:  ## generate a self-signed cert for local TLS
	@mkdir -p tls
	@openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
		-keyout tls/server.key -out tls/server.crt \
		-subj "/CN=localhost" -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" 2>/dev/null
	@echo "wrote tls/server.{crt,key}"

up: tls  ## build and start the stack
	@test -f .env || (echo "create .env from .env.example first" && exit 1)
	docker compose up -d --build
	@echo "waiting for health..."
	@for i in $$(seq 1 30); do \
		docker compose ps --format json | grep -q '"Health":"starting"' || break; sleep 2; done
	docker compose ps

down:  ## stop the stack (KEEPS the volume)
	docker compose down

clean:  ## stop and DELETE the volume -- destroys data
	docker compose down -v
	rm -rf tls

verify:  ## prove every acceptance criterion
	@echo "--- all services healthy ---"
	@docker compose ps
	@echo "\n--- https through nginx ---"
	@curl -sk https://localhost/ | head -1
	@echo "\n--- app runs non-root ---"
	@docker compose exec -T app id
	@echo "\n--- app root filesystem is read-only ---"
	@docker compose exec -T app sh -c 'touch /nope 2>&1 || true'
	@echo "\n--- db not reachable from the host (internal network) ---"
	@! nc -z -w2 localhost 5432 2>/dev/null && echo "5432 not published: OK"
	@echo "\n--- data survives a restart ---"
	@docker compose exec -T db psql -U $$(grep POSTGRES_USER .env|cut -d= -f2) \
		-d $$(grep POSTGRES_DB .env|cut -d= -f2) \
		-c "CREATE TABLE IF NOT EXISTS t(i int); INSERT INTO t VALUES (1);" >/dev/null
	@docker compose down >/dev/null && docker compose up -d >/dev/null && sleep 8
	@docker compose exec -T db psql -U $$(grep POSTGRES_USER .env|cut -d= -f2) \
		-d $$(grep POSTGRES_DB .env|cut -d= -f2) -c "SELECT count(*) FROM t;"

logs:  ## follow all logs
	docker compose logs -f

sizes:  ## image size comparison for the README
	@docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}' | grep -E 'week04|demo|REPO'

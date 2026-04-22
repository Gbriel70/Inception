COMPOSE_FILE = srcs/docker-compose.yml
DATA_PATH = /home/$(USER)/data
DOMAIN = Inception
HOSTS_ENTRY = 127.0.0.1 $(DOMAIN)

all: build up

build:
	@echo "Building containers..."
	docker compose -f $(COMPOSE_FILE) build

up:
	@echo "Starting containers..."
	@mkdir -p $(DATA_PATH)/mariadb $(DATA_PATH)/wordpress
	@if ! grep -q "$(DOMAIN)" /etc/hosts; then \
		echo "Adding $(DOMAIN) to /etc/hosts..."; \
		echo "$(HOSTS_ENTRY)" | sudo tee -a /etc/hosts > /dev/null; \
	fi
	docker compose -f $(COMPOSE_FILE) up -d
	
down:
	@echo "Stopping containers..."
	docker compose -f $(COMPOSE_FILE) down

clean: down
	@echo "Cleaning containers and images..."
	docker compose -f $(COMPOSE_FILE) down -v --rmi all
	docker system prune -af --volumes

fclean: clean
	@echo "Full clean: removing data volumes..."
	sudo rm -rf $(DATA_PATH)
	docker volume prune -f

re: fclean all

logs:
	docker compose -f $(COMPOSE_FILE) logs -f

status:
	docker compose -f $(COMPOSE_FILE) ps


.PHONY: all build up down clean fclean re logs status
.PHONY: all build up down clean fclean re logs status

PATH = /home/bola/pass.txt
COMPOSE_FILE = docker-compose.yml
DATA_PATH = /home/$(USER)/data

all: cpy build up

cpy:
	@if [ -f $(PATH) ]; then /bin/cp $(PATH) .env; else echo "Arquivo $(PATH) não encontrado!"; exit 1; fi

build:
	@echo "Building containers..."
	docker-compose -f $(COMPOSE_FILE) build

up:
	@echo "Starting containers..."
	@mkdir -p $(DATA_PATH)/mariadb $(DATA_PATH)/wordpress
	docker-compose -f $(COMPOSE_FILE) up -d

down:
	@echo "Stopping containers..."
	docker-compose -f $(COMPOSE_FILE) down

clean: down
	@echo "Cleaning containers and images..."
	docker-compose -f $(COMPOSE_FILE) down -v --rmi all
	docker system prune -af

fclean: clean
	@echo "Full clean: removing data volumes..."
	sudo rm -rf $(DATA_PATH)
	docker volume prune -f

re: fclean all

logs:
	docker-compose -f $(COMPOSE_FILE) logs -f

status:
	docker-compose -f $(COMPOSE_FILE) ps
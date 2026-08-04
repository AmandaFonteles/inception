NAME		= inception
SRCS_DIR	= srcs
DATA_DIR	= /home/afontele/data
DATAS		= ${DATA_DIR}/mariadb ${DATA_DIR}/wordpress

COMPOSE_FILE	= ${SRCS_DIR}/docker-compose.yml
COMPOSE		= docker compose -f ${COMPOSE_FILE}

RM = rm -rf

all: up

build:
	${COMPOSE} build

up:
	mkdir -p ${DATAS}
	${COMPOSE} up -d --build

down:
	${COMPOSE} down

start:
	${COMPOSE} start

stop:
	${COMPOSE} stop

restart: down up

logs:
	${COMPOSE} logs

ps:
	${COMPOSE} ps -a

clean:
	${COMPOSE} down -v --rmi all

fclean: clean
	sudo ${RM} ${DATAS}
	mkdir -p ${DATAS}

re: fclean all

.PHONY: all build up down start stop restart logs ps clean fclean re
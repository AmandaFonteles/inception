NAME = inception
SRCS_DIR = srcs
SECRET_DIR = secrets
DATA_DIR = /home/afontele/data
REQUIREMENTS_DIR = ${addprefix ${SRCS_DIR}/, requirements/}
MARIA_DB = ${addprefix ${REQUIREMENTS_DIR}, /mariadb/Dockerfile }
WORDPRESS = ${addprefix ${REQUIREMENTS_DIR}, /wordpress/Dockerfile}
DATAS = ${addprefix ${DATA_DIR}/, mariadb wordpress}
NGINX = ${addprefix ${REQUIREMENTS_DIR}, /nginx/Dockerfile}


COMPOSE_FILE = ${addprefix ${SRCS_DIR}/, docker-compose.yml}
COMPOSE = docker compose -f ${COMPOSE_FILE}

RM = rm -rf

all: up

build:
	${COMPOSE} build

up:
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

ls:
	${COMPOSE} ls -a

ps:
	${COMPOSE} ps -a

clean:
	${COMPOSE} down -v --rmi all

fclean: clean
	sudo ${RM} ${DATAS}
	mkdir -p ${DATAS}

re: fclean all

.PHONY: all clean fclean re up down build stop start ls logs restart ps
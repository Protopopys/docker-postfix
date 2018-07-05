# **Readme в процессе написания, вся фунциональность не отражена.**

# docker-postfix

## Необходимый софт
* [Docker](https://docs.docker.com/install/#supported-platforms)
* [Docker Compose](https://docs.docker.com/compose/install/)
#
## **Как собрать**
* `docker-compose -f build.yml build`

## **Как Запустить**
## Шаг 1. Копирование и подготовка файла переменных.

* Если используем локально c самоподписанными сертификатами.

    `$ cp .env.dist .env`

## Шаг 2. Подготовка .env 
* Внести изменения в файл .env.

    `DOMAIN` - равно параметрам [smtpd_sasl_local_domain](http://www.postfix.org/postconf.5.html#smtpd_sasl_local_domain) и [myhostname](http://www.postfix.org/postconf.5.html#myhostname)

    `SMTP_PASS` - пароль для авторизации в SMTP сервере

    `SMTP_USER` - имя пользователя для авторизации в SMTP сервере

    `MAXMAILSIZE` - [message_size_limit](http://www.postfix.org/postconf.5.html#message_size_limit) максимальный размер сообщения.


## Шаг 3. Подготовка docker-compose.yml 

При необходимости внесите свои изменения в файл `docker-compose.yml`, добавьте сервисы, сети и алиасы.

**Внимание доступ с smtp серверу сможет получить лишь контейнер или сервис находящийся в одной сети с контейнером Postfix, это задано параметром - [mynetworks_style=subnet](http://www.postfix.org/postconf.5.html#mynetworks_style)**

## Шаг 4. Запуск.

`docker-compose up -d`


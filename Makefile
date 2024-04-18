## dcape-app-template Makefile
## This file extends Makefile.app from dcape
#:

SHELL               = /bin/bash
CFG                ?= .env
CFG_BAK            ?= $(CFG).bak

#- App name
APP_NAME           ?= ut

#- Site GRPC host
GRPC_SITE          ?= $(APP_NAME)g.$(DCAPE_DOMAIN)
#- OT collector host
OTC_SITE           ?= $(APP_NAME)otc.$(DCAPE_DOMAIN)
#- OT collector GRPC host
OTC_GRPC_SITE      ?= $(APP_NAME)otcg.$(DCAPE_DOMAIN)
#- MailPit host
MAIL_SITE          ?= $(APP_NAME)mail.$(DCAPE_DOMAIN)
#- Grafana host
GRAF_SITE          ?= $(APP_NAME)graf.$(DCAPE_DOMAIN)

#- Docker image name
IMAGE              ?= uptrace/uptrace

#- Docker image tag
IMAGE_VER          ?= 1.7.1

#- Uptrace project 1 key
UPTRACE_PROJECT_KEY1 ?= $(shell openssl rand -hex 16; echo)
#- Uptrace project 2 key
UPTRACE_PROJECT_KEY2 ?= $(shell openssl rand -hex 16; echo)
#- Uptrace cookie key
UPTRACE_SECRET_KEY   ?= $(shell openssl rand -hex 16; echo)

#- Grafana docker image name
GF_IMAGE           ?= grafana/grafana

#- Grafana docker image tag
GF_IMAGE_VER       ?= 10.3.1

#- Grafana plugins
GF_INSTALL_PLUGINS ?=

# If you need database, uncomment this var
USE_DB              = yes

# If you need user name and password, uncomment this var
ADD_USER            = yes

# create extension for word_similarity func
DB_INIT_SQL         = pg_init.sql

CERT_DAYS          ?= 3650
CERT_HOST          ?= mailpit
CERT_DIR           ?= var/ssl
CERT_CA             = $(CERT_DIR)/ca.crt.pem
CERT_CA_KEY         = $(CERT_DIR)/ca.pk.pem

CERT               ?= $(CERT_CA)

# ------------------------------------------------------------------------------

# if exists - load old values
-include $(CFG_BAK)
export

-include $(CFG)
export

# ------------------------------------------------------------------------------
# Find and include DCAPE_ROOT/Makefile
DCAPE_COMPOSE   ?= dcape-compose
DCAPE_ROOT      ?= $(shell docker inspect -f "{{.Config.Labels.dcape_root}}" $(DCAPE_COMPOSE))

ifeq ($(shell test -e $(DCAPE_ROOT)/Makefile.app && echo -n yes),yes)
  include $(DCAPE_ROOT)/Makefile.app
else
  include /opt/dcape/Makefile.app
endif

# ------------------------------------------------------------------------------

## Template support code, used once
use-template:

.default-deploy: prep

## Setup app configs
prep: var certs var/grafana

cert-show:
	openssl x509 -noout -text -in $(CERT)

## Create cert bundle
certs: $(CERT_DIR)
	$(MAKE) -s $(CERT_DIR)/mail.crt.pem

var:
	@mkdir $@

var/grafana:
	@mkdir -m 777 $@

# ------------------------------------------------------------------------------
# Cert utils

CERT_DIR    ?= var/ssl
CERT_CA      = $(CERT_DIR)/ca.crt.pem
CERT_CA_KEY  = $(CERT_DIR)/ca.pk.pem
CERT_DAYS   ?= 3650
CERT_HOST   ?= app

# Create cert dir
$(CERT_DIR):
	mkdir -p $@

# Create CA
$(CERT_CA):
	@echo "*** $@ ***" ; \
	openssl req -newkey rsa:4096 -keyout "$(CERT_CA_KEY)" -x509 -new -nodes -out $@ \
	  -subj "/OU=Unknown/O=Unknown/L=Unknown/ST=unknown/C=RU" -days "$(CERT_DAYS)"

# Create Cert Signing Request
$(CERT_DIR)/%.csr.pem: $(CERT_CA)
	@echo "*** $@ ***" ; \
	x=$@ ; tag=$${x%.csr.pem} ; \
	openssl req -new -newkey rsa:4096 -nodes -keyout "$$tag.pk.pem" -out $@ \
	  -subj "/CN=$(CERT_HOST)/OU=Unknown/O=Unknown/L=Unknown/ST=unknown/C=RU" \
	  -addext "subjectAltName=DNS:$(CERT_HOST)"

# Sign Cert
$(CERT_DIR)/%.crt.pem: $(CERT_DIR)/%.csr.pem
	@tmp_file=$(shell mktemp) ; echo "subjectAltName=DNS:$(CERT_HOST)" > $$tmp_file ; \
	openssl x509 -req -in $< -CA "$(CERT_CA)" -CAkey "$(CERT_CA_KEY)" -CAcreateserial -out "$@" \
	  -days "$(CERT_DAYS)" -extfile $$tmp_file ; \
	rm $$tmp_file
	openssl x509 -in $@ -text -noout


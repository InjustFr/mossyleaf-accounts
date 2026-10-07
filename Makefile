DC = docker compose
DEPLOY_HOST ?= user@server
DEPLOY_DIR ?= /path/to/mossyleaf-accounts
REMOTE_DOCKER ?= docker

EMAIL ?=
NAME ?=
GROUPS ?= mossydew mossytrunk
TIMEZONE ?= Europe/Paris
LOCALE ?= fr
DURATION ?= days=7
INVITE_ENV = -e INVITE_EMAIL='$(EMAIL)' -e INVITE_NAME='$(NAME)' -e INVITE_GROUPS='$(GROUPS)' -e INVITE_TIMEZONE='$(TIMEZONE)' -e INVITE_LOCALE='$(LOCALE)' -e INVITE_DURATION='$(DURATION)'

SHOT = $(DC) run --rm --no-deps playwright npx -y playwright@1.63.0 screenshot --wait-for-timeout=4000

.PHONY: up down logs ps apply invite shots deploy-files deploy

up: ## Start Authentik on http://localhost:9000 and Mailpit on http://localhost:8027
	$(DC) up -d --wait

down:
	$(DC) down

logs:
	$(DC) logs -f server worker

ps:
	$(DC) ps

apply: ## Re-apply the custom blueprints now (e.g. after editing branding/branding.css)
	$(DC) exec -T worker ak apply_blueprint custom/mossyleaf-accounts.yaml custom/mossyleaf-apps.yaml

invite: ## make invite EMAIL=a@b.c NAME="Ada" [GROUPS="mossydew mossytrunk"] [REMOTE=1]
	@test -n "$(EMAIL)" || (echo "EMAIL is required" && exit 1)
ifeq ($(REMOTE),1)
	ssh $(DEPLOY_HOST) "cd $(DEPLOY_DIR) && $(REMOTE_DOCKER) compose exec -T $(INVITE_ENV) -e INVITE_HOST=accounts.mossyleaf.studio -e INVITE_SECURE=1 worker ak shell" < scripts/invite.py
else
	$(DC) exec -T $(INVITE_ENV) -e INVITE_HOST=localhost:9000 worker ak shell < scripts/invite.py
endif

shots: ## Screenshot the sign-in page at phone and desktop widths into shots/
	mkdir -p shots
	$(SHOT) --viewport-size=390,844 http://server:9000/if/flow/mossyleaf-authentication/ shots/login-phone.png
	$(SHOT) --viewport-size=1440,900 http://server:9000/if/flow/mossyleaf-authentication/ shots/login-desktop.png

deploy-files: ## Copy compose, env template, blueprints, templates, branding and scripts to the server
	ssh $(DEPLOY_HOST) 'mkdir -p $(DEPLOY_DIR)'
	rsync -a deploy/compose.yaml deploy/.env.dist deploy/README.md $(DEPLOY_HOST):$(DEPLOY_DIR)/
	rsync -a --delete blueprints templates branding scripts $(DEPLOY_HOST):$(DEPLOY_DIR)/

deploy: deploy-files ## Copy the files then pull and (re)start Authentik on the server
	ssh $(DEPLOY_HOST) 'cd $(DEPLOY_DIR) && $(REMOTE_DOCKER) compose pull && $(REMOTE_DOCKER) compose up -d'

# Authentik with the mossyleaf configuration baked in: blueprints, email
# templates, branding and the invitation script. Bump AUTHENTIK_TAG to update
# Authentik (one minor version at a time, see deploy/README.md).
ARG AUTHENTIK_TAG=2026.8.3
FROM ghcr.io/goauthentik/server:${AUTHENTIK_TAG}

LABEL org.opencontainers.image.source="https://github.com/InjustFr/mossyleaf-accounts" \
      org.opencontainers.image.description="Authentik single sign-on for the mossyleaf apps"

COPY blueprints/ /blueprints/custom/
COPY templates/ /templates/
COPY branding/ /web/dist/custom/
COPY scripts/invite.py /mossyleaf/invite.py

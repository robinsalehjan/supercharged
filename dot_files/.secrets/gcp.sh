#!/bin/zsh
# GCP service-account credentials template.
#
# This file describes the wiring pattern only — fill in your own project IDs,
# key filenames, and env-var names before use. Every export below is commented
# out so an unconfigured copy is inert.
#
# Layout convention:
#   ~/.secrets/<your-project>-<env>_<keyhash>.json   ← downloaded service-account key
#   ~/.secrets/gcp.sh                                ← this file (sourced; *.sh only)
#
# The loader (zshrc + restore-claude.sh) sources *.sh from ~/.secrets/ and
# leaves *.json files alone — the JSONs are referenced *by path* from here.

# 1) Define one named env var per service-account key. Use whatever naming
#    convention you like (PROJECT_ENV_CREDS is a common pattern).
# export GCP_DEV_CREDS="$HOME/.secrets/your-project-dev_KEYHASH.json"
# export GCP_PROD_CREDS="$HOME/.secrets/your-project-prod_KEYHASH.json"

# 2) Optionally point GOOGLE_APPLICATION_CREDENTIALS at a default. Many gcloud
#    workflows expect this to be unset (so `gcloud auth application-default
#    login` controls it) — leave the line commented if that's your setup.
#
#    To switch environments per shell, override after sourcing:
#        export GOOGLE_APPLICATION_CREDENTIALS="$GCP_PROD_CREDS"
# export GOOGLE_APPLICATION_CREDENTIALS="$GCP_DEV_CREDS"

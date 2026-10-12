#!/usr/bin/env bash
# Deploys the Kokoro voice server to Google Cloud Run. Run it in Cloud Shell:
#   git clone https://github.com/pgrooves/read-aloud.git; bash read-aloud/space/deploy-cloud-run.sh
set -euo pipefail

SERVICE=read-aloud-tts
REGION=us-central1
cd "$(dirname "$0")"

PROJECT=$(gcloud config get-value project 2>/dev/null || true)
if [ -z "$PROJECT" ]; then
  # No project selected: use your only project, or make one if you have none
  PROJECTS=$(gcloud projects list --format='value(projectId)')
  COUNT=$(printf '%s' "$PROJECTS" | grep -c . || true)
  if [ "$COUNT" -eq 1 ]; then
    PROJECT=$PROJECTS
  elif [ "$COUNT" -eq 0 ]; then
    PROJECT="read-aloud-$(date +%s | tail -c 7)"
    echo "Creating project $PROJECT..."
    gcloud projects create "$PROJECT" --name="Read Aloud"
  else
    echo "You have several projects:"
    echo "$PROJECTS"
    echo "Pick one by running:  gcloud config set project PROJECT_ID   then run this script again."
    exit 1
  fi
  gcloud config set project "$PROJECT"
fi
echo "Deploying to project: $PROJECT"

# Cloud Run needs billing turned on (the free allowance still applies)
if [ "$(gcloud billing projects describe "$PROJECT" --format='value(billingEnabled)' 2>/dev/null || true)" != "True" ]; then
  ACCOUNT=$(gcloud billing accounts list --filter=open=true --format='value(name.basename())' | head -1)
  if [ -z "$ACCOUNT" ]; then
    echo "There's no billing account yet. Start the free trial at https://console.cloud.google.com/billing, then run this again."
    exit 1
  fi
  echo "Connecting billing account $ACCOUNT..."
  gcloud billing projects link "$PROJECT" --billing-account="$ACCOUNT"
fi

echo "Turning on Cloud Run and Cloud Build (first time only)..."
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com

# New projects build with the Compute Engine default service account, which needs this role
NUMBER=$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')
gcloud projects add-iam-policy-binding "$PROJECT" \
  --member="serviceAccount:${NUMBER}-compute@developer.gserviceaccount.com" \
  --role=roles/run.builder --condition=None --quiet >/dev/null || true

echo "Building and deploying (about 5-10 minutes the first time)..."
# max-instances 1 caps how much it can ever run at once (and so what it can cost)
gcloud run deploy "$SERVICE" --source . --region "$REGION" \
  --allow-unauthenticated --cpu 2 --memory 2Gi --cpu-boost \
  --max-instances 1 --concurrency 4 --timeout 300 --quiet

URL=$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')
echo
echo "Testing $URL ..."
curl -sf "$URL/health" && echo
echo
echo "Done. Send this URL to Claude: $URL"

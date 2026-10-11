#!/usr/bin/env bash
# Deploys the Kokoro voice server to Google Cloud Run. Run it in Cloud Shell:
#   git clone https://github.com/pgrooves/read-aloud.git && bash read-aloud/space/deploy-cloud-run.sh
set -euo pipefail

SERVICE=read-aloud-tts
REGION=us-central1
cd "$(dirname "$0")"

PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT" ]; then
  echo "No Google Cloud project is selected. Pick one at the top of the Cloud console, then run this again."
  exit 1
fi
echo "Deploying to project: $PROJECT"

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

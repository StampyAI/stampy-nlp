#!/bin/bash
set -e

LOCATION=us-west1
GCLOUD_PROJECT=stampy-nlp
MODEL_NAME=$2
MODEL_TYPE=$3
CLOUD_RUN_SERVICE=$1 # Allow the service name to be provided as a parameter
IMAGE=$LOCATION-docker.pkg.dev/$GCLOUD_PROJECT/cloud-run-source-deploy/$CLOUD_RUN_SERVICE

if [[ -z "$CLOUD_RUN_SERVICE" ]]; then
    echo "Please provide the service name"
    exit 1
elif [[ -z "$MODEL_NAME" ]]; then
    echo "Please provide the model name"
    exit 1
elif [[ -z "$MODEL_TYPE" ]]; then
    echo "Please provide the model type (pipeline | encoder)"
    exit 1
fi

echo
echo "Will execute the following actions:"
echo "--> Build a docker image for $MODEL_NAME as a $MODEL_TYPE"
echo "--> Push the image as $IMAGE"
echo "--> Deploy the image as the $CLOUD_RUN_SERVICE service"
read -r -p "Is that correct? [y/N] " response
if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    exit 1
fi

GCLOUD_PROJECT=stampy-nlp
echo
echo "Enabling Google API"
gcloud config set project $GCLOUD_PROJECT
gcloud config set run/region $LOCATION
gcloud services enable iam.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable logging.googleapis.com

echo "Building image"

docker pull --platform linux/amd64 python:3.8
docker pull --platform linux/amd64 $IMAGE || true
docker buildx build --platform linux/amd6 -t $IMAGE model_server \
       --build-arg MODEL_NAME=$MODEL_NAME \
       --build-arg MODEL_TYPE=$MODEL_TYPE
docker push $IMAGE:latest

echo "Deploying to Google Cloud Run"

gcloud beta run deploy $CLOUD_RUN_SERVICE --image $IMAGE:latest \
--min-instances=0 --memory 4G --cpu=2 --platform managed --no-traffic --tag=test \
--service-account=service@stampy-nlp.iam.gserviceaccount.com

echo
echo "Project ID: $GCLOUD_PROJECT"

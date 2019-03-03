# Creating Imagebuilder service account

You can use [Google Cloud Shell](https://cloud.google.com/shell/) or a local workstation in the
future instructions.

[![Open in Cloud Shell](http://gstatic.com/cloudssh/images/open-btn.svg)](https://console.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/GoogleCloudPlatform/marketplace-vm-imagebuilder&cloudshell_tutorial=docs/creating-service-account.md)

## Set the environment variables

Set the environment variable for the service account name:

```bash
export SERVICE_ACCOUNT=imagebuilder
```

Set the environment variables for the GCP project name:

```bash
export PROJECT=<YOUR GCP PROJECT>
```

## Create the service account

To create the service account, execute the following command:

```bash
gcloud iam service-accounts create $SERVICE_ACCOUNT \
  --display-name "VM Imagebuilder service account" \
  --project $PROJECT
```

## Create the service account key

To create and download the service account key, execute the following command:

```bash
gcloud iam service-accounts keys create $SERVICE_ACCOUNT-service-account.json \
  --project $PROJECT \
  --iam-account $SERVICE_ACCOUNT@$PROJECT.iam.gserviceaccount.com
```

The service account JSON key is created and downloaded to the `$SERVICE_ACCOUNT-service-account.json` file.

## Grant permissions for the service account

To grant permissions for the service account, execute the following commands:

```bash
gcloud projects add-iam-policy-binding $PROJECT \
  --member serviceAccount:$SERVICE_ACCOUNT@$PROJECT.iam.gserviceaccount.com \
  --role roles/compute.instanceAdmin.v1
```

```bash
gcloud projects add-iam-policy-binding $PROJECT \
  --member serviceAccount:$SERVICE_ACCOUNT@$PROJECT.iam.gserviceaccount.com \
  --role roles/storage.objectAdmin
```

```bash
gcloud projects add-iam-policy-binding $PROJECT \
  --member serviceAccount:$SERVICE_ACCOUNT@$PROJECT.iam.gserviceaccount.com \
  --role roles/iam.serviceAccountUser
```

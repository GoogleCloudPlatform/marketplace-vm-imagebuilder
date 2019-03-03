# Creating Imagebuilder service account

## Set the environment variables

Set the environment variable for the service account name:

```shell
export SERVICE_ACCOUNT=imagebuilder
```

Set the environment variables for the GCP project name:

```shell
export PROJECT=<YOUR GCP PROJECT>
```

## Create the service account

```shell
gcloud iam service-accounts create $SERVICE_ACCOUNT \
  --display-name "VM Imagebuilder service account" \
  --project $PROJECT
```

## Create the service account key

```shell
gcloud iam service-accounts keys create $SERVICE_ACCOUNT-service-account.json \
  --project $PROJECT \
  --iam-account $SERVICE_ACCOUNT@$PROJECT.iam.gserviceaccount.com
```

The JSON key is created and downloaded to the `$SERVICE_ACCOUNT-service-account.json` file.

## Grant permission for the service account

```shell
gcloud projects add-iam-policy-binding $PROJECT \
  --member serviceAccount:$SERVICE_ACCOUNT@$PROJECT.iam.gserviceaccount.com \
  --role roles/compute.instanceAdmin.v1
```

```shell
gcloud projects add-iam-policy-binding $PROJECT \
  --member serviceAccount:$SERVICE_ACCOUNT@$PROJECT.iam.gserviceaccount.com \
  --role roles/storage.objectAdmin
```

```shell
gcloud projects add-iam-policy-binding $PROJECT \
  --member serviceAccount:$SERVICE_ACCOUNT@$PROJECT.iam.gserviceaccount.com \
  --role roles/iam.serviceAccountUser
```

## Delete the service account

```shell
gcloud iam service-accounts delete $SERVICE_ACCOUNT@$PROJECT.iam.gserviceaccount.com \
  --project $PROJECT
```

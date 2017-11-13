#!/bin/bash
set -eu
IFS=$'\n\t'

LOCATION=us-west1
ZONE=us-west1-b
USERNAME=pgtest
STORAGE=95

INSTANCE_NONCE=$(base64 /dev/urandom | tr -dc a-z0-9 | fold -w 10 | head -n 1)
PASSWORD=$(base64 /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)

# We don't expect any pipelines to have error components from here on out
set -o pipefail

echo Instance: $INSTANCE_NONCE
echo Password: $PASSWORD

PGNAME=pg-$INSTANCE_NONCE
echo Creating PostgreSQL server VM: $PGNAME
gcloud compute instances create $PGNAME \
    --zone $ZONE \
    --machine-type n1-standard-4 \
    --image-family debian-9 --image-project debian-cloud \
    --metadata "ssh-keys=$USERNAME:$(cat ~/.ssh/id_rsa.pub)" \
    --boot-disk-size $STORAGE \
    --boot-disk-type pd-ssd \
    > /dev/null
PGFQDN=$(gcloud compute instances describe $PGNAME --zone $ZONE \
    --format json | jq '.networkInterfaces[0].networkIP'  \
    | tr -d \")
PGHOST=$(gcloud compute instances describe $PGNAME --zone $ZONE \
    --format json | jq '.networkInterfaces[0].accessConfigs[0].natIP'  \
    | tr -d \")
echo Postgres Server VM is at: $PGFQDN / $PGHOST

sleep 15

echo Installing, configuring, and starting Postgres
TEMP_PG_SCRIPT=$(mktemp)
sed -e "s/\\^PGPASS\\^/$PASSWORD/" pgserver.sh > $TEMP_PG_SCRIPT
scp -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null $TEMP_PG_SCRIPT ${USERNAME}@$PGHOST:pgserver.sh
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ${USERNAME}@$PGHOST -- chmod +x pgserver.sh
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ${USERNAME}@$PGHOST -- ./pgserver.sh
rm $TEMP_PG_SCRIPT

CLIENTVM=client-$INSTANCE_NONCE
echo Creating Client VM: $CLIENTVM
gcloud compute instances create $CLIENTVM \
    --zone $ZONE \
    --machine-type n1-standard-4 \
    --image-family debian-9 --image-project debian-cloud \
    --metadata "ssh-keys=$USERNAME:$(cat ~/.ssh/id_rsa.pub)" \
    > /dev/null

CLIENTIP=$(gcloud compute instances describe $CLIENTVM --zone $ZONE \
    --format json | jq '.networkInterfaces[0].accessConfigs[0].natIP'  \
    | tr -d \")
echo Client VM is at: $CLIENTIP

sleep 15

echo Uploading pgbench script.
TEMP_PG_SCRIPT=$(mktemp)
sed -e "s/\\^PGHOST\\^/$PGFQDN/" pgbench.sh > $TEMP_PG_SCRIPT
sed -e "s/\\^PGUSER\\^/postgres/" $TEMP_PG_SCRIPT > $TEMP_PG_SCRIPT.1
sed -e "s/\\^PGPASS\\^/$PASSWORD/" $TEMP_PG_SCRIPT.1 > $TEMP_PG_SCRIPT

scp -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null $TEMP_PG_SCRIPT ${USERNAME}@$CLIENTIP:pgbench.sh

rm $TEMP_PG_SCRIPT
rm $TEMP_PG_SCRIPT.1

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ${USERNAME}@$CLIENTIP -- chmod +x pgbench.sh

echo Running pgbench script.

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ${USERNAME}@$CLIENTIP -- ./pgbench.sh
scp -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ${USERNAME}@$CLIENTIP:report.txt report-google-self-$INSTANCE_NONCE.txt

#echo Cleaning up -- deleting server and client
gcloud compute instances delete $PGNAME --zone $ZONE -q > /dev/null
gcloud compute instances delete $CLIENTVM --zone $ZONE -q > /dev/null 



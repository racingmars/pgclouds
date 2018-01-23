#!/bin/bash
set -eu
IFS=$'\n\t'

LOCATION=westus
USERNAME=pgtest
STORAGE=125

INSTANCE_NONCE=$(base64 /dev/urandom | tr -dc a-z0-9 | fold -w 10 | head -n 1)
PASSWORD=$(base64 /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)

# We don't expect any pipelines to have error components from here on out
set -o pipefail

if ! [ -e ~/.ssh/id_rsa.pub ]
then
    echo "ERROR: ~/.ssh/id_rsa.pub must exist"
    exit 1
fi

echo Instance: $INSTANCE_NONCE
echo Password: $PASSWORD

RGROUP=rg-pgbench-$INSTANCE_NONCE
echo Creating Resource Group: $RGROUP
az group create --location $LOCATION --name $RGROUP > /dev/null

PGNAME=pg-$INSTANCE_NONCE
echo Creating PostgreSQL server VM: $PGNAME
az vm create \
    -n $PGNAME \
    -g $RGROUP \
    -l $LOCATION \
    --admin-username $USERNAME \
    --authentication-type ssh \
    --size Standard_D4s_v3 \
    --ssh-key-value ~/.ssh/id_rsa.pub \
    --image UbuntuLTS \
    --os-disk-size-gb $STORAGE \
    --storage-sku Premium_LRS \
    --vnet-name vnet-$INSTANCE_NONCE \
    --subnet subnet-$INSTANCE_NONCE \
    > /dev/null

PGFQDN=$(az vm show -g $RGROUP -n $PGNAME -d -o json \
    | jq .privateIps | tr -d \")
PGHOST=$(az vm show -g $RGROUP -n $PGNAME -d -o json \
    | jq .publicIps | tr -d \")
echo Postgres Server VM is at: $PGFQDN / $PGHOST

echo Installing, configuring, and starting Postgres
TEMP_PG_SCRIPT=$(mktemp)
sed -e "s/\\^PGPASS\\^/$PASSWORD/" pgserver.sh > $TEMP_PG_SCRIPT
scp -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null $TEMP_PG_SCRIPT ${USERNAME}@$PGHOST:pgserver.sh
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ${USERNAME}@$PGHOST -- chmod +x pgserver.sh
ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ${USERNAME}@$PGHOST -- ./pgserver.sh
rm $TEMP_PG_SCRIPT

CLIENTVM=client-$INSTANCE_NONCE
echo Creating Client VM: $CLIENTVM
az vm create \
    -n $CLIENTVM \
    -g $RGROUP \
    -l $LOCATION \
    --admin-username $USERNAME \
    --authentication-type ssh \
    --size Standard_A3 \
    --ssh-key-value ~/.ssh/id_rsa.pub \
    --image UbuntuLTS \
    --vnet-name vnet-$INSTANCE_NONCE \
    --subnet subnet-$INSTANCE_NONCE \
    > /dev/null

CLIENTIP=$(az vm show -g $RGROUP -n $CLIENTVM -d -o json \
    | jq .publicIps | tr -d \")
echo Client VM is at: $CLIENTIP

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
scp -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ${USERNAME}@$CLIENTIP:report.txt report-azure-self-$INSTANCE_NONCE.txt

#echo Cleaning up -- deleting resource group
az group delete -n $RGROUP -y --no-wait

#!/bin/bash
set -eu
IFS=$'\n\t'

LOCATION=westus
USERNAME=pgtest
COMPUTE_UNITS=800

INSTANCE_NONCE=$(base64 /dev/urandom | tr -dc a-z0-9 | fold -w 10 | head -n 1)
PASSWORD=$(base64 /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)

# We don't expect any pipelines to have error components from here on out
set -o pipefail

echo Instance: $INSTANCE_NONCE
echo Password: $PASSWORD

RGROUP=rg-pgbench-$INSTANCE_NONCE
echo Creating Resource Group: $RGROUP
az group create --location $LOCATION --name $RGROUP > /dev/null

PGNAME=pg-$INSTANCE_NONCE
echo Creating PostgreSQL instance: $PGNAME
az postgres server create \
    -u $USERNAME \
    -n $PGNAME \
    -g $RGROUP \
    -p $PASSWORD \
    -l $LOCATION \
    --performance-tier Standard \
    --compute-units $COMPUTE_UNITS  \
    > /dev/null

PGFQDN=$(az postgres server show -n $PGNAME -g $RGROUP -o json \
    | jq .fullyQualifiedDomainName | tr -d \")
echo New PostgreSQL Server is at: $PGFQDN

echo Adding firewall rule for 0.0.0.0/0
az postgres server firewall-rule create \
    -g $RGROUP \
    -n AllIPs \
    -s $PGNAME \
    --start-ip-address 0.0.0.0 \
    --end-ip-address 255.255.255.255 \
    > /dev/null

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
    > /dev/null

CLIENTIP=$(az vm show -g $RGROUP -n $CLIENTVM -d -o json \
    | jq .publicIps | tr -d \")
echo Client VM is at: $CLIENTIP

echo Uploading pgbench script.
TEMP_PG_SCRIPT=$(mktemp)
sed -e "s/\\^PGHOST\\^/$PGFQDN/" pgbench.sh > $TEMP_PG_SCRIPT
sed -e "s/\\^PGUSER\\^/$USERNAME@$PGNAME/" $TEMP_PG_SCRIPT > $TEMP_PG_SCRIPT.1
sed -e "s/\\^PGPASS\\^/$PASSWORD/" $TEMP_PG_SCRIPT.1 > $TEMP_PG_SCRIPT

scp -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null $TEMP_PG_SCRIPT ${USERNAME}@$CLIENTIP:pgbench.sh

rm $TEMP_PG_SCRIPT
rm $TEMP_PG_SCRIPT.1

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ${USERNAME}@$CLIENTIP -- chmod +x pgbench.sh

echo Running pgbench script.

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ${USERNAME}@$CLIENTIP -- ./pgbench.sh
scp -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ${USERNAME}@$CLIENTIP:report.txt report-azure-$INSTANCE_NONCE.txt

#echo Cleaning up -- deleting resource group
az group delete -n $RGROUP -y --no-wait


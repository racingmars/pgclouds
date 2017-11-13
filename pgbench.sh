#!/bin/bash
set -euo pipefail

PGHOST=^PGHOST^
PGUSER=^PGUSER^
PGPASS=^PGPASS^
PGDB=bench

if [ ! -e "/usr/bin/time" ]; then
    sudo apt-get -y install time
fi

wget -q https://get.enterprisedb.com/postgresql/postgresql-9.6.6-1-linux-x64-binaries.tar.gz
tar xzf postgresql-9.6.6-1-linux-x64-binaries.tar.gz
export PATH=$(pwd)/pgsql/bin:$PATH

export PGPASSWORD=$PGPASS
psql -h $PGHOST -U $PGUSER -d postgres \
   -c "CREATE DATABASE $PGDB;"

date >> report.txt

echo "---> Initializing pgbench database"|tee -a report.txt
/usr/bin/time -f %E pgbench -h $PGHOST -U $PGUSER -i -s 100 $PGDB 2>&1| tee -a report.txt

echo "---> Running pgbench with 10 clients, 10000 xactions"|tee -a report.txt
/usr/bin/time -f %E pgbench -h $PGHOST -U $PGUSER $PGDB -c 10 -j 4 -t 10000 2>&1| tee -a report.txt

echo "---> Running pgbench with 40 clients, 10000 xactions"|tee -a report.txt
/usr/bin/time -f %E pgbench -h $PGHOST -U $PGUSER $PGDB -c 40 -j 4 -t 10000 2>&1| tee -a report.txt

echo "---> Running pgbench with 80 clients, 10000 xactions"|tee -a report.txt
/usr/bin/time -f %E pgbench -h $PGHOST -U $PGUSER $PGDB -c 80 -j 4 -t 10000 2>&1| tee -a report.txt

echo "---> Running pgbench with 120 clients, 10000 xactions"|tee -a report.txt
/usr/bin/time -f %E pgbench -h $PGHOST -U $PGUSER $PGDB -c 120 -j 4 -t 10000 2>&1| tee -a report.txt


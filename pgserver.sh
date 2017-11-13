#!/bin/bash
set -euo pipefail

PGPASS=^PGPASS^

wget -q https://get.enterprisedb.com/postgresql/postgresql-9.6.6-1-linux-x64-binaries.tar.gz
tar xzf postgresql-9.6.6-1-linux-x64-binaries.tar.gz
export PATH=$(pwd)/pgsql/bin:$PATH

# Create database
initdb -D $HOME/pgdata -U postgres
echo host all all 0.0.0.0/0 md5 >> pgdata/pg_hba.conf
sed -i -e "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" pgdata/postgresql.conf
sed -i -e "s/max_connections = 100/max_connections = 150/" pgdata/postgresql.conf
sed -i -e "s/shared_buffers = 128MB/shared_buffers = 6GB/" pgdata/postgresql.conf
sed -i -e "s/#work_mem = 4MB/work_mem = 128MB/" pgdata/postgresql.conf
sed -i -e "s/#maintenance_work_mem = 64MB/maintenance_work_mem = 4GB/" pgdata/postgresql.conf
sed -i -e "s/#autovacuum_work_mem = -1/autovacuum_work_mem = 1GB/" pgdata/postgresql.conf
sed -i -e "s/#max_wal_size = 1GB/max_wal_size = 5GB/" pgdata/postgresql.conf

# Start the server
pg_ctl start -D $HOME/pgdata -l postgresql.log
sleep 5
psql -U postgres -d postgres -c "ALTER USER postgres PASSWORD '$PGPASS';"

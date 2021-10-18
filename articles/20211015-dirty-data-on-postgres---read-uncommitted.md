Dirty Data on Postgres - Read Uncommitted
dirty-data-on-postgres---read-uncommitted
database, postgres

The problem: long running update transactions prevent users from retrieving data from your Postgres database while the lock is active.

Solution: create a "highly available" proof of concept with Postgres that emulates MySQL's Read Uncommitted option.

## Setup

We're going to use docker containers for this so if you're running on hardware you can skip some of the container image steps.  While we go through this we'll verify that we can see the problem so that we know our solution actually works.

### Setup a Postgres Containers

For this proof of concept we need a postgres primary and secondary.  The primary will provide us with a writeable system of record.  It will still respond to read queries but it is the only writeable connection for this exercise.

We're going to use `docker-compose`, here's the file:

```yaml
version: "3.9"
services:
  db-primary:
    build:
      dockerfile: 'psql.dockerfile'
      context: '.'
    container_name: psql-primary
    restart: always
    volumes:
      - "data-primary:/var/lib/postgresql/data"
    networks:
      test_net:
        ipv4_address: '172.16.1.200'
        aliases:
          - postgres.primary

  db-secondary:
    build:
      dockerfile: 'psql.dockerfile'
      context: '.'
      args:
        - SECONDARY=true
    container_name: psql-secondary
    restart: always
    volumes:
      - "data-secondary:/var/lib/postgresql/data"
    networks:
      test_net:
        ipv4_address: '172.16.1.201'
        aliases:
          - postgres.secondary
    environment:
      PRIMARY_CONNINFO: "psql://172.16.1.200:5432/"

networks:
  test_net:
    ipam:
      driver: default
      config:
      - subnet: "172.16.1.0/24"

volumes:
  data-secondary:
  data-primary:

```

For more information about docker-compose, check that out [here](https://docs.docker.com/compose/).

The important thing to note here is the `environment` and `build.args` keys in the file.  Both of these are controlling the image and container in such a way that it runs as either the primary (write/read) or as a secondary (read-only).

The `psql.dockerfile` boils down to this:

```yaml
FROM postgres:14
COPY postgres.defaults.conf /tmp/
ARG SECONDARY
ENV SECONDARY $SECONDARY
RUN su postgres -c initdb \
 && su postgres -c 'pg_ctl -D /var/lib/postgresql/data start' \
 && su postgres -c 'psql -c "CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD '"'test'"';"' \
 && su postgres -c 'pg_ctl -D /var/lib/postgresql/data stop' \
 && cp /tmp/postgres.defaults.conf /var/lib/postgresql/data/postgres.conf \
 && if test "${SECONDARY}" = 'true'; then \
      echo 'hot_standby = on' >> '/var/lib/postgresql/data/postgresql.conf'; \
      echo 'primary_conninfo = '"'user=replicator password=test channel_binding=prefer host=172.16.1.200 port=5432 sslmode=prefer sslcompression=0 ssl_min_protocol_version=TLSv1.2 gssencmode=prefer krbsrvname=postgres target_session_attrs=any'" >> '/var/lib/postgresql/data/postgresql.conf'; \
      touch /var/lib/postgresql/data/standby.signal; \
    else \
      echo "host replication replicator 172.16.1.201/32 trust" >> '/var/lib/postgresql/data/pg_hba.conf'; \
      echo "host all postgres 172.16.1.100/24 trust" >> '/var/lib/postgresql/data/pg_hba.conf'; \
    fi

CMD ["bash", "-c", "if [[ $SECONDARY = 'true' ]]; then rm -Rf /var/lib/postgresql/data/*; su postgres -c 'pg_basebackup -h 172.16.1.200 -U replicator -p 5432 -D /var/lib/postgresql/data -Fp -Xs -P -R'; fi; su postgres -c 'postgres -D /var/lib/postgresql/data'"]
```

If you're using this tutorial for production then do a little more research and use individual config files rather than mangling them with bash as we're doing here. This isn't a secure way of allowing replication.

Now, if you run `docker-compose up` you should see the primary start and the secondary eventually start.  Don't be worried about the secondary failing a few times during startup, this may happen because the primary may take a few minutes to start accepting connections.

## Now Build the Dog in Our Corn Dog

This is how we're going to allow users to get a dirty read from the secondary while the primary is updating.  Let's add pgpool-II.  You can read about it more in depth [here](https://www.pgpool.net/mediawiki/index.php/Main_Page).  We're going to add the following service to our compose file:

```yaml
  pgpool:
    build:
      dockerfile: 'pgpool.dockerfile'
      context: '.'
    container_name: 'pgpool'
    restart: always
    networks:
      test_net:
        ipv4_address: '172.16.1.100'
        aliases:
          - pgpool
    ports:
      - "5432:5432"
```

With the `pgpool.dockerfile` containing:

```yaml
FROM alpine:3.13.6
COPY pgpool.conf /etc/pgpool/pgpool.conf
RUN apk update \
 && apk add pgpool \
 && mkdir /var/run/pgpool

CMD ["pgpool", "-n"]
```

In a `pgpool.conf` make sure you have these important bits along with other config info (a full sample can be found [here](/f/pgpool.sample.conf)).

```
 # - Backend Connection Settings -
 backend_hostname0 = '172.16.1.200' #primary
 backend_port0 = 5432
 backend_weight0 = 40
 backend_data_directory0 = '/data'
 backend_flag0 = 'ALLOW_TO_FAILOVER'

 backend_hostname1 = '172.16.1.201' #secondary
 backend_port1 = 5432
 backend_weight1 = 60
 backend_data_directory1 = '/data1'
 backend_flag1 = 'ALLOW_TO_FAILOVER'
```

Now we're all set.

You can now query from postgres while something locks the table, you can test this by running `docker-compose up`, connecting your sql client and doing the following:

Client 1:
```sql
CREATE TABLE test_lock (t text);
INSERT INTO test_lock (t) VALUES ('this is only a test');
BEGIN WORK;
LOCK test_lock IN EXCLUSIVE MODE;
-- leave this transaction open while you run in your second window
```

Client 2:
```sql
SELECT * FROM test_lock;
--    test
-- ----------
--  test str
(1 row)
```
Now you can issue the `END WORK;` in Client 1 to remove the lock

Now, let's verify that our pgpool is _really_ working and that it's actually allowing us to run queries.

```bash
docker-compose up pgpool pg-primary
```

Now when you run your test above, Client 2 will block until you `END WORK;`.

If you'd like to check this out as a repo all of the files for building can be found on [github](https://github.com/tony-o/tony-o.github.io/tree/master/scratch/pgpool)

## What Exactly Did We Do?

Well, we made dirty data available to consumers who don't require _exactly_ correct data at read time.  This can be something as simple as we're just showing a user some data that we know to be true at the time of request. Here's a couple of charts so we can see exactly what's going on.

![Standalone Postgres](/f/standalone-pg.svg)

From this chart you can see the time that the action happens on the left and how much time has elapsed through the process.  You'll notice that Client 2 becomes blocked for the entirety of the lock created by Client 1.  This creates a pretty poor user experience if they have to wait 45 seconds just to view their own profile data while you run a migration.

Conversely, this is how PGPool-II would handle this situation.

![PGPool-II](/f/pgpool-ii.svg)

From this you can see that PGPool is actually routing Client 2's read request to the replicated secondary and avoiding the lock on the primary postgres server.  In doing so you're potentially giving the client data that is going to be different a second from now but you're also avoiding making your user wait until a long running table lock completes.

From here you can move ahead to testing, proposing, and building out better configurations for all of these but this should get you started towards making your dreams come true or at least making them readable while you update them.

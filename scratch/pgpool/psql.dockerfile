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

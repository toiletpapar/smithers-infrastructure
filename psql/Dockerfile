FROM postgres:15

# Copy credentials
COPY credentials /run/secrets

# ENV POSTGRES_INITDB_ARGS_FILE
ENV POSTGRES_DB_FILE /run/secrets/postgres-db
ENV POSTGRES_USER_FILE /run/secrets/postgres-user
ENV POSTGRES_PASSWORD_FILE /run/secrets/postgres-passwd
ENV PGDATA /data/pgdata
ENV POSTGRES_INITDB_ARGS "-E UTF8"

# Initialization scripts
COPY --from=repo ./data/schema /docker-entrypoint-initdb.d
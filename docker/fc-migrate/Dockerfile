FROM migrate/migrate:v4.18.1

COPY services/fc-api/migrations /migrations

ENTRYPOINT ["migrate", "-path", "/migrations", "-database"]
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart pub get --offline

FROM dart:stable
RUN apt-get update \
 && apt-get install -y --no-install-recommends libsqlite3-0 \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /root/.pub-cache /root/.pub-cache
COPY --from=build /app /app
ENV PORT=8080
ENV ACGHUB_DB_PATH=/data/acgnhub.db
VOLUME /data
EXPOSE 8080
CMD ["dart", "run", "bin/server.dart"]

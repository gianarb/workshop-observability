FROM quay.io/influxdb/jaeger-all-in-one-influxdb:gianarb as influxdb

FROM jaegertracing/all-in-one:1.17

COPY --from=influxdb /usr/local/bin/jaeger-influxdb-linux /usr/local/bin/jaeger-influxdb-linux

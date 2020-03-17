# Solution Lesson 3 - Tracing

## Solution: Configure Telegraf to use the healthcheck from our apps

With the `inputs.http_response` plugin you can list a set of users that will be
called at every scheduled interval (in the [agent] configuration).

Checkout the documentation this plugin because it has a lot of possible features
that you can enable. For example it can match the content of the body sending 1
or 0 based on the actual result.

Copy paste this in `../lesson03-influxdb/telegraf/telegraf.conf` and restart
telegraf.

```toml
[[inputs.http_response]]
  urls = [
    "http://frontend:3000/health",
    "http://pay:8080/health",
    "http://discount:3000/health",
    "http://item/health"
  ]
  response_timeout = "5s"
  method = "GET"
```

```bash
$docker-compose restart telegraf
```

## Solution: Import a dashboard that shows service availability

This is the [official
documentation](https://v2.docs.influxdata.com/v2.0/visualize-data/dashboards/create-dashboard/#create-a-new-dashboard)

\newpage

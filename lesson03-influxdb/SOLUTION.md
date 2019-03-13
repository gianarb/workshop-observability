```toml
[[inputs.http_response]]
  address = "http://item/health"
  response_timeout = "5s"
  method = "GET"
  response_string_match = "\"status\": \"healthy\""

[[inputs.http_response]]
  address = "http://discount:3000/health"
  response_timeout = "5s"
  method = "GET"
  response_string_match = "\"status\": \"healthy\""

[[inputs.http_response]]
  address = "http://pay:8080/health"
  response_timeout = "5s"
  method = "GET"
  response_string_match = "\"status\": \"healthy\""

[[inputs.http_response]]
  address = "http://frontend:3000/health"
  response_timeout = "5s"
  method = "GET"
  response_string_match = "\"status\": \"healthy\""
```

```
SELECT count("http_response_code") AS "mean_http_response_code" FROM "telegraf"."autogen"."http_response" WHERE time > :dashboardTime: AND "server"='http://frontend:3000/health' AND "status_code"='200' GROUP BY time(5s) FILL(null)
```

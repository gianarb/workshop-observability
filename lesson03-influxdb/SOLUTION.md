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

```
from(bucket: "workshop")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "http_response")
  |> filter(fn: (r) => r._field == "http_response_code")
  |> filter(fn: (r) => r._value != 200)
```

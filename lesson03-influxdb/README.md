# Monitoring stack
## Lesson 3

During this lesson we will spin up our monitoring stack using the
[TICKStack](https://www.influxdata.com/time-series-platform/).

The Tick Stack is a set of open source tools provided by
[InfluxData](https://github.com/influxdata).
The most popular one is [InfluxDB](http://docs.influxdata.com/influxdb/v1.7/) a
time series database.

Other that the database itself we will use another set of tools:

1. [Telegraf](http://docs.influxdata.com/telegraf/v1.10/): A collector to get
   information from your server (laptop) and from our applications.
2. [Chronograf](http://docs.influxdata.com/chronograf/v1.7/): A UI to run
   queries and to make dashboards with the value stored in InfluxDB.
3. [Kapacitor](http://docs.influxdata.com/kapacitor/v1.5/): It is a post
   process. It can be used to manipulate time series data or to do alerting.

Another tool we will use is called [Jaeger](https://www.jaegertracing.io/). It
is a tracer. We will use it to store traces later on. (it is nto part of the
tick stack)

### Exercise: Spin up the monitoring stack

**Time: 15minutes**

Spin up the monitoring stack. Open chronograf on port `8888` and play with it
for a bit. You can look at the pre-canned dashboards and you can try to create
your own one exploring the data Telegraf is storing in InfluxDB.


### Exercise: Configure Telegraf to use the healthcheck from our apps

**Time: 20minutes**

We coded an healthcheck for our application. This is a first signal useful to
understand if the applications are running or not.
Telegraf has a plugin called `inputs.http_response` that can be used to ping and
validate an HTTP endpoint.

Create a dashboard that uses these new metrics to tell you the status code
returned by the health check.

**PRO:** You can do another set of graph related to `latency`. It is in
important signal because if it grows too much it means that for some reason your
application is slower.

## Tips and Tricks

Use docker-compose to spin up the stack.

```bash
cd ./lesson03-influxdb
docker-compose up
```

The `inputs.http_response` documentation is
[here](http://docs.influxdata.com/telegraf/v1.10/plugins/inputs/#http-response)

The telegraf configuration is under `./telegraf/telegraf.conf` and in order to
reload the configuration you can use `docker-compose up telegraf`.

## Link

* [You need an high cardinality database](https://gianarb.it/blog/high-cardinality-database)

\newpage

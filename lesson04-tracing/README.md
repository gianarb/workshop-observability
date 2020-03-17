# Distributed Tracing
## Lesson 4

This lesson is probably the most complicated one. We are going to instrument our
application using OpenTelemetry and OpenTracing, a "standard" set of libraries
to build a trace across all your application.

There are libraries in many languages and luckily for all the application we
have!

During `lesson3-influxdb` one of the application we started with
`docker-compose` was Jaeger. Our distributed tracer.

So we are ready to start instrumenting our favourite application.

### Exercise: Trace applications using OpenTracing and Jager

**Time: 30 minutes**

These are the libraries to use across the languages, open them, follow the
documentation and we should try to figure out how to get an propagate a
trace across all the languages

* Item (PHP):
    * [jonahgeorge/jcchavezs/zipkin-opentracing](https://github.com/jcchavezs/zipkin-opentracing)
    * [opentracing/opentracing](https://github.com/opentracing/opentracing-php)
* Discount:
    * [open-telemetry/opentelemetry-js](https://github.com/open-telemetry/opentelemetry-js)
* Pay (Java):
    * [open-telemetry/opentelemetry-java](https://github.com/open-telemetry/opentelemetry-java)
* Frontend (Go):
    * [open-telemetry/opentelemetry-go](https://github.com/open-telemetry/opentelemetry-go)

### Tips and tricks

* To take the most from this exercise we need to have our trace propagated (or
  coming from) the other application. So the first things you can do is to
  `cherry-pick`, `merge` or `apply patch` from the `shopmany` or from the
  `workshop` repository the commit related to the other application (we saw how
  to it previously). In this way you will have already a working example from
  other applications to look at.

### Links

* [FAQ: Distributed Tracing](https://gianarb.it/blog/faq-distributed-tracing)
* [Context propagation over HTTP in Go](https://medium.com/@rakyll/context-propagation-over-http-in-go-d4540996e9b0)
* [Jaeger Blog](https://medium.com/jaegertracing)
* [OpenTracing: An Open Standard for Distributed Tracing](https://thenewstack.io/opentracing-open-standard-distributed-tracing/)
* [Why You Can’t Afford to Ignore Distributed Tracing for Observability](https://thenewstack.io/why-you-cant-afford-to-ignore-distributed-tracing-for-observability/)
* [Opentracing Tutorial by Yury Shkuro](https://github.com/yurishkuro/opentracing-tutorial/)

\newpage

# Distributed Tracing
## Lesson 4

This lesson is probably the most complicated one. We are going to instrument our
application using OpenTracing, a "standard" set of libraries to build a trace
across all your application.

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
    * [jonahgeorge/jaeger-client-php](https://github.com/jonahgeorge/jaeger-client-php)
    * [opentracing/opentracing](https://github.com/opentracing/opentracing-php)
* Discount:
    * [jaeger-client](https://github.com/jaegertracing/jaeger-client-node)
    * [opentracing](https://github.com/opentracing/opentracing-javascript)
* Pay (Java):
    * [io.jaegertracing:jaeger-client](https://github.com/jaegertracing/jaeger-client-java)
* Frontend (Go):
    * [github.com/opentracing/opentracing-go](https://github.com/opentracing/opentracing-go)
    * [github.com/uber/jaeger-client-go](https://github.com/jaegertracing/jaeger-client-go)
    * [github.com/opentracing-contrib/go-stdlib/nethttp](https://github.com/opentracing-contrib/go-stdlib)

### Tips and tricks

* To take the most from this exercise we need to have our trace propagated (or
  coming from) the other application. So the first things you can do if to
  `cherry-pick` from the `shopmany` repository the commit related to the other
  application (we saw how to it previously). In this way you will have already a
  working example from other applications to look at.
* If you are working on `item` in `PHP` the problem here is that you will need
  to install new php extenstions via Docker. You need to modify the
  `./item/Dockerfile` and the combination of commands I use to download the
  dependencies is `docker-compose up --build item` and `docker-compose exec item
  composer up` (you need to modify the Dockerfile also to download Composer).

### Links

* [FAQ: Distributed Tracing](https://gianarb.it/blog/faq-distributed-tracing)
* [Context propagation over HTTP in Go](https://medium.com/@rakyll/context-propagation-over-http-in-go-d4540996e9b0)
* [Jaeger Blog](https://medium.com/jaegertracing)
* [OpenTracing: An Open Standard for Distributed Tracing](https://thenewstack.io/opentracing-open-standard-distributed-tracing/)
* [Why You Can’t Afford to Ignore Distributed Tracing for Observability](https://thenewstack.io/why-you-cant-afford-to-ignore-distributed-tracing-for-observability/)
* [Opentracing Tutorial by Yury Shkuro](https://github.com/yurishkuro/opentracing-tutorial/)

\newpage

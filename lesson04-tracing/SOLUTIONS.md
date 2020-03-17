# Solution lesson 4 - Tracing

## Item

```
commit 6c0d88375b92ee12d9036974f2f93fe487b2d438
Author: Gianluca Arbezzano <gianarb92@gmail.com>
Date:   Thu Mar 14 14:34:20 2019 +0100

    Added tracer middleware to item

    This PR adds tracing to item.
    In PHP we use Opentracing with Jaeger as backend:

    * https://github.com/opentracing/opentracing-php
    * https://github.com/jonahgeorge/jaeger-client-php

    Signed-off-by: Gianluca Arbezzano <gianarb92@gmail.com>

diff --git a/items/Dockerfile b/items/Dockerfile
index 2184cb1..859112f 100644
--- a/items/Dockerfile
+++ b/items/Dockerfile
@@ -2,8 +2,22 @@ FROM php:7.2-apache

 RUN a2enmod rewrite
 RUN docker-php-ext-install pdo_mysql
+RUN docker-php-ext-install bcmath

 RUN find /etc/apache2/sites-enabled/* -exec sed -i 's/#*[Cc]ustom[Ll]og/#CustomLog/g' {} \;
 RUN find /etc/apache2/sites-enabled/* -exec sed -i 's/#*[Ee]rror[Ll]og/#ErrorLog/g' {} \;
 RUN a2disconf other-vhosts-access-log

+RUN docker-php-ext-install sockets
+RUN pecl install opencensus-alpha
+RUN docker-php-ext-enable opencensus
+RUN apt-get update && \
+    apt-get install -y --no-install-recommends git zip unzip
+
+RUN apt-get install -y libgmp-dev re2c libmhash-dev libmcrypt-dev file
+RUN ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/local/include/
+RUN docker-php-ext-configure gmp
+RUN docker-php-ext-install gmp
+
+RUN curl --silent --show-error https://getcomposer.org/installer | php
+RUN mv composer.phar /usr/bin/composer
diff --git a/items/composer.json b/items/composer.json
index c0badf9..f0cb5db 100644
--- a/items/composer.json
+++ b/items/composer.json
@@ -47,7 +47,11 @@
         "zendframework/zend-expressive-helpers": "^5.0",
         "zendframework/zend-servicemanager": "^3.3",
         "zendframework/zend-stdlib": "^3.1",
-        "monolog/monolog": "1.24.0"
+        "monolog/monolog": "1.24.0",
+        "jonahgeorge/jaeger-client-php": "v0.4.3@dev",
+        "opentracing/opentracing":"1.0.0-beta5@dev"
     },
     "require-dev": {
         "phpunit/phpunit": "^7.0.1",
diff --git a/items/config/autoload/containers.global.php b/items/config/autoload/containers.global.php
index 12a5b18..9bd1afc 100644
--- a/items/config/autoload/containers.global.php
+++ b/items/config/autoload/containers.global.php
@@ -8,7 +8,6 @@ return [
         // Use 'aliases' to alias a service name to another service. The
         // key is the alias name, the value is the service to which it points.
         'aliases' => [
-            // Fully\Qualified\ClassOrInterfaceName::class => Fully\Qualified\ClassName::class,
         ],
         // Use 'invokables' for constructor-less services, or services that do
         // not require arguments to the constructor. Map a service name to the
@@ -22,6 +21,7 @@ return [
             App\Handler\Health::class => App\Handler\HealthFactory::class,
             "Logger" => App\Service\LoggerFactory::class,
             App\Middleware\LoggerMiddleware::class => App\Middleware\LoggerMiddlewareFactory::class,
+            App\Middleware\TracerMiddleware::class => App\Middleware\TracerMiddlewareFactory::class,
         ],
     ],
 ];
diff --git a/items/config/autoload/local.php b/items/config/autoload/local.php
index 824e725..c52b018 100644
--- a/items/config/autoload/local.php
+++ b/items/config/autoload/local.php
@@ -15,4 +15,17 @@ return [
         "user" => "root",
         "pass" => "root",
     ],
+    "opentracing-jaeger-exporter" => [
+        "options" => [
+            'sampler' => [
+                'type' => \Jaeger\SAMPLER_TYPE_CONST,
+                'param' => true,
+            ],
+            'logging' => true,
+            'local_agent' => [
+                'reporting_host' => 'jaeger-workshop',
+            ],
+        ],
+        "service_name" => 'item',
+    ],
 ];
diff --git a/items/config/pipeline.php b/items/config/pipeline.php
index e9287fd..6417cb8 100644
--- a/items/config/pipeline.php
+++ b/items/config/pipeline.php
@@ -15,11 +15,13 @@ use Zend\Expressive\Router\Middleware\MethodNotAllowedMiddleware;
 use Zend\Expressive\Router\Middleware\RouteMiddleware;
 use Zend\Stratigility\Middleware\ErrorHandler;
 use App\Middleware\LoggerMiddleware;
+use App\Middleware\TracerMiddleware;

 /**
  * Setup middleware pipeline:
  */
 return function (Application $app, MiddlewareFactory $factory, ContainerInterface $container) : void {
+    $app->pipe($container->get(TracerMiddleware::class));
     $app->pipe($container->get(LoggerMiddleware::class));
     // The error handler should be the first (most outer) middleware to catch
     // all Exceptions.
diff --git a/items/src/App/src/Factory/JaegerExporterFactory.php b/items/src/App/src/Factory/JaegerExporterFactory.php
new file mode 100644
index 0000000..8f1abf0
--- /dev/null
+++ b/items/src/App/src/Factory/JaegerExporterFactory.php
@@ -0,0 +1,13 @@
+<?php
+namespace App\Factory;
+
+use Psr\Container\ContainerInterface;
+use OpenCensus\Trace\Exporter\JaegerExporter;
+
+class JaegerExporterFactory
+{
+    public function __invoke(ContainerInterface $container) {
+        $options = $container->get('config')['opentracing-jaeger-exporter'];
+        return new JaegerExporter("items", $options);
+    }
+}
diff --git a/items/src/App/src/Factory/LoggerExporterFactory.php b/items/src/App/src/Factory/LoggerExporterFactory.php
new file mode 100644
index 0000000..2f7cdcc
--- /dev/null
+++ b/items/src/App/src/Factory/LoggerExporterFactory.php
@@ -0,0 +1,14 @@
+<?php
+namespace App\Factory;
+
+use Psr\Container\ContainerInterface;
+use OpenCensus\Trace\Exporter\LoggerExporter;
+use Monolog\Processor\TagProcessor;
+
+class LoggerExporterFactory
+{
+    public function __invoke(ContainerInterface $container) {
+        $logger = $container->get("Logger");
+        return new LoggerExporter($logger);
+    }
+}
diff --git a/items/src/App/src/Handler/Item.php b/items/src/App/src/Handler/Item.php
index f1d9a64..353e4df 100644
--- a/items/src/App/src/Handler/Item.php
+++ b/items/src/App/src/Handler/Item.php
@@ -1,6 +1,7 @@
 <?php

 namespace App\Handler;
+use OpenCensus\Trace\Tracer;
 use Psr\Http\Message\ResponseInterface;
 use Psr\Http\Message\ServerRequestInterface;
 use Psr\Http\Server\RequestHandlerInterface;
@@ -21,9 +22,12 @@ class Item implements RequestHandlerInterface

     public function handle(ServerRequestInterface $request) : ResponseInterface
     {
-        $this->logger->info("Get list of items");
+        $span = Tracer::startSpan(['name' => 'get-items']);
+        $scope = Tracer::withSpan($span);
+
         $items = $this->itemService->list();
         $this->logger->info("Retrived list of items", ["num_items" => count($items)]);
+        $scope->close();
         return new JsonResponse(['items' => $items]);
     }

diff --git a/items/src/App/src/Middleware/TracerMiddleware.php b/items/src/App/src/Middleware/TracerMiddleware.php
new file mode 100644
index 0000000..48efc86
--- /dev/null
+++ b/items/src/App/src/Middleware/TracerMiddleware.php
@@ -0,0 +1,51 @@
+<?php
+namespace App\Middleware;
+
+use ErrorException;
+use Psr\Http\Message\ResponseInterface;
+use Psr\Http\Message\ServerRequestInterface;
+use Psr\Http\Server\MiddlewareInterface;
+use Psr\Http\Server\RequestHandlerInterface;
+use OpenTracing\Formats;
+
+use Jaeger\Config;
+use Jaeger;
+use OpenTracing\GlobalTracer;
+
+
+class TracerMiddleware implements MiddlewareInterface
+{
+    private $tracer;
+
+    public function __construct($config)
+    {
+        $config = new Config($config["options"], $config["service_name"]);
+        $this->tracer = $config->initializeTracer();
+        GlobalTracer::get($tracer);
+    }
+
+    public function process(ServerRequestInterface $request, RequestHandlerInterface $handler) : ResponseInterface
+    {
+        $spanContext = GlobalTracer::get()->extract(
+            Formats\HTTP_HEADERS,
+            getallheaders()
+        );
+        $spanOpt = [];
+        $spanName = $request->getMethod()." ".$request->getUri()->getPath();
+        if ($spanContext != null) {
+            $spanOpt['child_of'] = $spanContext;
+        }
+        $span = GlobalTracer::get()->startSpan($spanName, $spanOpt);
+        $span->setTag("request_uri", $request->getUri()->__toString());
+        $span->setTag("request_headers", json_encode($request->getHeaders()));
+        $span->setTag("request_method", $request->getMethod());
+
+        $response = $handler->handle($request);
+
+        $span->setTag("response_status_code", $response->getStatusCode());
+
+        $span->finish();
+        $this->tracer->flush();
+        return $response;
+    }
+}
diff --git a/items/src/App/src/Middleware/TracerMiddlewareFactory.php b/items/src/App/src/Middleware/TracerMiddlewareFactory.php
new file mode 100644
index 0000000..e203ec5
--- /dev/null
+++ b/items/src/App/src/Middleware/TracerMiddlewareFactory.php
@@ -0,0 +1,17 @@
+<?php
+namespace App\Middleware;
+
+use Psr\Container\ContainerInterface;
+use ErrorException;
+use Psr\Http\Message\ResponseInterface;
+use Psr\Http\Message\ServerRequestInterface;
+use Psr\Http\Server\MiddlewareInterface;
+use Psr\Http\Server\RequestHandlerInterface;
+
+class TracerMiddlewareFactory
+{
+    public function __invoke(ContainerInterface $container) {
+        $config = $container->get("config")["opentracing-jaeger-exporter"];
+        return new TracerMiddleware($config);
+    }
+}
diff --git a/items/src/App/src/Service/ItemService.php b/items/src/App/src/Service/ItemService.php
index b072870..09bb1e6 100644
--- a/items/src/App/src/Service/ItemService.php
+++ b/items/src/App/src/Service/ItemService.php
@@ -3,6 +3,8 @@ namespace App\Service;

 use App\Model\Item;
 use \PDO;
+use OpenTracing\GlobalTracer;
+use OpenTracing\Formats;

 class ItemService {

@@ -18,7 +20,18 @@ class ItemService {
      * list returns all the items
      */
     public function list() {
+        $spanContext = GlobalTracer::get()->extract(
+            Formats\HTTP_HEADERS,
+            getallheaders()
+        );
+        $spanOpt = [];
+        if ($spanContext != null) {
+            $spanOpt['child_of'] = $spanContext;
+        }
+        $span = GlobalTracer::get()->startSpan("mysql.select_items", $spanOpt);
+
         $q = $this->pdo->query("SELECT * FROM item");
+        $span->setTag("query", $q->queryString);
         $items = [];
         while ($row = $q->fetch()) {
             $i = new Item();
@@ -28,6 +41,7 @@ class ItemService {
             $i->price = $row[3];
             $items[] = $i;
         }
+        $span->finish();
         return $items;
     }
 }
```

## Discount

```diff
commit f6880e4341ba095d98346ae9d593c87b0ed73195
Author: Gianluca Arbezzano <gianarb92@gmail.com>
Date:   Mon Mar 18 13:01:23 2019 +0100

    Addded tracing support to discount service

    The discount service supports tracing via OpenTracing and Jaeger.

    Signed-off-by: Gianluca Arbezzano <gianarb92@gmail.com>

diff --git a/discount/package.json b/discount/package.json
index 1640ae1..b019353 100644
--- a/discount/package.json
+++ b/discount/package.json
@@ -12,6 +12,8 @@
   "dependencies": {
     "express": "^4.16.4",
     "express-pino-logger": "^4.0.0",
-    "mongodb": "^3.1.13"
+    "jaeger-client": "^3.14.4",
+    "mongodb": "^3.1.13",
+    "opentracing": "^0.14.3"
   }
 }
diff --git a/discount/server.js b/discount/server.js
index 50a32a9..b252923 100644
--- a/discount/server.js
+++ b/discount/server.js
@@ -2,10 +2,13 @@ var express = require("express");

 var app = express();

+var url = require('url');
+
+var opentracing = require("opentracing");
+var initJaegerTracer = require("jaeger-client").initTracer;
 const MongoClient = require('mongodb').MongoClient;
-const url = 'mongodb://discountdb:27017';
 const dbName = 'shopmany';
-const client = new MongoClient(url, { useNewUrlParser: true });
+const client = new MongoClient('mongodb://discountdb:27017', { useNewUrlParser: true });
 app.use(errorHandler)

 const logger = require('pino')()
@@ -14,6 +17,39 @@ const expressPino = require('express-pino-logger')({
 })
 app.use(expressPino)

+function initTracer(serviceName) {
+  var config = {
+    serviceName: serviceName,
+    sampler: {
+      type: "const",
+      param: 1,
+    },
+    reporter: {
+      agentHost: "jaeger-workshop",
+      logSpans: true,
+    },
+  };
+  var options = {
+    logger: {
+      info: function logInfo(msg) {
+        logger.info(msg, {
+          "service": "tracer"
+        })
+      },
+      error: function logError(msg) {
+        logger.error(msg, {
+          "service": "tracer"
+        })
+      },
+    },
+  };
+  return initJaegerTracer(config, options);
+}
+
+const tracer = initTracer("discount");
+opentracing.initGlobalTracer(tracer);
+app.use(expressMiddleware({tracer: tracer}));
+
 app.get("/health", function(req, res, next) {
   var resbody = {
     "status": "healthy",
@@ -41,11 +77,18 @@ app.get("/health", function(req, res, next) {
 app.get("/discount", function(req, res, next) {
   client.connect(function(err) {
     db = client.db(dbName);
+    const wireCtx = tracer.extract(opentracing.FORMAT_HTTP_HEADERS, req.headers);
+    const pathname = url.parse(req.url).pathname;
+    const span = tracer.startSpan("mongodb", {childOf: wireCtx});
+    span.setTag("query", "db.items.find()");
     db.collection('discount').find({}).toArray(function(err, discounts) {
       if (err != null) {
         req.log.error(err.toString());
+        span.setTag("error", true);
+        span.finish();
         return next(err)
       }
+      span.finish();
       var goodDiscount = null
       discounts.forEach(function (s) {
         if (s.itemID+"" == req.query.itemid) {
@@ -83,3 +126,40 @@ function errorHandler(err, req, res, next) {
 app.listen(3000, () => {
   logger.info("Server running on port 3000");
 });
+
+function expressMiddleware(options = {}) {
+  const tracer = options.tracer || opentracing.globalTracer();
+
+  return (req, res, next) => {
+    const wireCtx = tracer.extract(opentracing.FORMAT_HTTP_HEADERS, req.headers);
+    const pathname = url.parse(req.url).pathname;
+    const span = tracer.startSpan(pathname, {childOf: wireCtx});
+    span.logEvent("request_received");
+
+    span.setTag("http.method", req.method);
+    span.setTag("span.kind", "server");
+    span.setTag("http.url", req.url);
+
+    const responseHeaders = {};
+    tracer.inject(span, opentracing.FORMAT_TEXT_MAP, responseHeaders);
+    Object.keys(responseHeaders).forEach(key => res.setHeader(key, responseHeaders[key]));
+
+    Object.assign(req, {span});
+
+    const finishSpan = () => {
+      span.logEvent("request_finished");
+      const opName = (req.route && req.route.path) || pathname;
+      span.setOperationName(opName);
+      span.setTag("http.status_code", res.statusCode);
+      if (res.statusCode >= 500) {
+        span.setTag("error", true);
+        span.setTag("sampling.priority", 1);
+      }
+      span.finish();
+    };
+    res.on('close', finishSpan);
+    res.on('finish', finishSpan);
+
+    next();
+  };
+}
```

## Pay

```
commit 98b3c57ee9914eec77f87dffd6d49cbadfe9f4a5
Author: Gianluca Arbezzano <gianarb92@gmail.com>
Date:   Sat Mar 23 20:05:48 2019 +0100

    Added tracing support to pay svc

    Signed-off-by: Gianluca Arbezzano <gianarb92@gmail.com>

diff --git a/docker-compose.yaml b/docker-compose.yaml
index f56946c..859f052 100644
--- a/docker-compose.yaml
+++ b/docker-compose.yaml
@@ -70,6 +70,8 @@ services:
       - shopmany
     depends_on:
       - paydb
+    environment:
+      JAEGER_ENDPOINT: "http://jaeger-workshop:14268/api/traces"

   paydb:
     image: mysql:5.7.25
diff --git a/pay/build.gradle b/pay/build.gradle
index 50bb905..0fe3642 100644
--- a/pay/build.gradle
+++ b/pay/build.gradle
@@ -32,6 +32,7 @@ dependencies {
     compile("com.fasterxml.jackson.core:jackson-databind")
     compile("org.springframework.boot:spring-boot-starter-web"){ exclude group: 'org.springframework.boot', module: 'spring-boot-starter-logging'}
     compile('org.springframework.boot:spring-boot-starter-log4j2')
+    compile('io.jaegertracing:jaeger-client:0.32.0')
     testCompile('org.springframework.boot:spring-boot-starter-test')
 }

diff --git a/pay/src/main/java/pay/AppConfig.java b/pay/src/main/java/pay/AppConfig.java
index bb788cb..78662b9 100644
--- a/pay/src/main/java/pay/AppConfig.java
+++ b/pay/src/main/java/pay/AppConfig.java
@@ -9,6 +9,7 @@ public class AppConfig extends WebMvcConfigurerAdapter  {

     @Override
     public void addInterceptors(InterceptorRegistry registry) {
+       registry.addInterceptor(new TracingInterceptor());
        registry.addInterceptor(new LoggerInterceptor());
     }
 }
diff --git a/pay/src/main/java/pay/TracingInterceptor.java b/pay/src/main/java/pay/TracingInterceptor.java
new file mode 100644
index 0000000..b1c0118
--- /dev/null
+++ b/pay/src/main/java/pay/TracingInterceptor.java
@@ -0,0 +1,78 @@
+package pay;
+
+import org.springframework.stereotype.Component;
+import org.springframework.web.servlet.handler.HandlerInterceptorAdapter;
+import javax.servlet.http.HttpServletRequest;
+import javax.servlet.http.HttpServletResponse;
+import io.opentracing.Span;
+import io.opentracing.SpanContext;
+import io.opentracing.Tracer;
+import io.opentracing.propagation.TextMapExtractAdapter;
+import io.opentracing.propagation.Format;
+import io.jaegertracing.Configuration;
+import io.jaegertracing.Configuration.ReporterConfiguration;
+import io.jaegertracing.Configuration.SamplerConfiguration;
+import io.jaegertracing.internal.JaegerTracer;
+import java.util.Enumeration;
+import java.util.HashMap;
+import java.util.Map;
+
+@Component
+public class TracingInterceptor
+  extends HandlerInterceptorAdapter {
+
+    public static JaegerTracer initTracer(String service) {
+        SamplerConfiguration samplerConfig = SamplerConfiguration.fromEnv().withType("const").withParam(1);
+        ReporterConfiguration reporterConfig = ReporterConfiguration.fromEnv().withLogSpans(true);
+        Configuration config = new Configuration(service).withSampler(samplerConfig).withReporter(reporterConfig);
+    return config.getTracer();
+}
+
+    @Override
+    public boolean preHandle(
+      HttpServletRequest request,
+      HttpServletResponse response,
+      Object handler) {
+        Tracer tracer = initTracer("pay");
+
+        Map<String, String> headers = new HashMap<String, String>();
+        Enumeration<String> headerNames = request.getHeaderNames();
+        while (headerNames.hasMoreElements()) {
+            String key = (String) headerNames.nextElement();
+            String value = request.getHeader(key);
+            headers.put(key, value);
+        }
+
+        String operationName = request.getMethod()+" "+request.getRequestURL().toString();
+        Tracer.SpanBuilder spanBuilder = tracer.buildSpan(operationName);
+        SpanContext parentSpan = tracer.extract(Format.Builtin.HTTP_HEADERS, new TextMapExtractAdapter(headers));
+        if (parentSpan != null) {
+            spanBuilder = tracer.buildSpan(operationName).asChildOf(parentSpan);
+        }
+
+        Span span = spanBuilder.start();
+
+        span.setTag("path", request.getRequestURL().toString());
+        span.setTag("method", request.getMethod());
+        span.setTag("local_addr", request.getLocalAddr());
+        span.setTag("content_type", request.getContentType());
+        request.setAttribute("span", span);
+        return true;
+    }
+
+
+    @Override
+    public void afterCompletion(
+      HttpServletRequest request,
+      HttpServletResponse response,
+      Object handler,
+      Exception ex) {
+        Span span = (Span)request.getAttribute("span");
+        span.setTag("response_status",response.getStatus());
+        if (ex != null) {
+            span.setTag("error", true);
+            span.setTag("error_message", ex.getMessage());
+        }
+        span.finish();
+    }
+}
```

## Frontend

```diff
commit 62641a2f4e39ed5d4c07567278dc69427a9db3cf
Author: Gianluca Arbezzano <gianarb92@gmail.com>
Date:   Fri Mar 15 14:35:23 2019 +0100

    Added tracing to frontend

    Via OpenTracing and Jaeger we are not able to trace requests coming to
    the http server.

    We also configured the http client to pass the SpanContext, in this way
    other services can create child spans.

    Signed-off-by: Gianluca Arbezzano <gianarb92@gmail.com>

diff --git a/docker-compose.yaml b/docker-compose.yaml
index dc0a720..f56946c 100644
--- a/docker-compose.yaml
+++ b/docker-compose.yaml
@@ -96,6 +96,10 @@ services:
     volumes:
       - "./frontend:/opt/app"
     working_dir: "/opt/app"
+    environment:
+      JAEGER_SERVICE_NAME: frontend
+      JAEGER_ENDPOINT: "http://jaeger-workshop:14268/api/traces"
+      JAEGER_REPORTER_FLUSH_INTERVAL: 500ms
     depends_on:
       - item
       - pay
diff --git a/frontend/go.mod b/frontend/go.mod
index d86b3cb..b936b7f 100644
--- a/frontend/go.mod
+++ b/frontend/go.mod
@@ -3,7 +3,18 @@ module github.com/gianarb/shopmany/frontend
 go 1.12

 require (
+	github.com/apache/thrift v0.12.0 // indirect
+	github.com/codahale/hdrhistogram v0.0.0-20161010025455-3a0bb77429bd // indirect
+	github.com/docker/docker v1.13.1 // indirect
+	github.com/docker/go-connections v0.4.0 // indirect
+	github.com/docker/go-units v0.3.3 // indirect
 	github.com/jessevdk/go-flags v1.4.0
+	github.com/moby/moby v1.13.1 // indirect
+	github.com/opentracing-contrib/go-stdlib v0.0.0-20190205184154-464eb271c715
+	github.com/opentracing/opentracing-go v1.0.2
+	github.com/uber/jaeger-client-go v2.15.0+incompatible
+	github.com/uber/jaeger-lib v1.5.0
+	go.opencensus.io v0.19.1
 	go.uber.org/atomic v1.3.2 // indirect
 	go.uber.org/multierr v1.1.0 // indirect
 	go.uber.org/zap v1.9.1
diff --git a/frontend/go.sum b/frontend/go.sum
index 54a3d32..18cbd18 100644
--- a/frontend/handler/getitems.go
+++ b/frontend/handler/getitems.go
@@ -9,6 +9,7 @@ import (
 	"strconv"

 	"github.com/gianarb/shopmany/frontend/config"
+	opentracing "github.com/opentracing/opentracing-go"
 	"go.uber.org/zap"
 )

@@ -37,6 +38,13 @@ func getDiscountPerItem(ctx context.Context, hclient *http.Client, itemID int, d
 	if err != nil {
 		return 0, err
 	}
+	req.WithContext(ctx)
+	if span := opentracing.SpanFromContext(ctx); span != nil {
+		opentracing.GlobalTracer().Inject(
+			span.Context(),
+			opentracing.HTTPHeaders,
+			opentracing.HTTPHeadersCarrier(req.Header))
+	}
 	q := req.URL.Query()
 	q.Add("itemid", strconv.Itoa(itemID))
 	req.URL.RawQuery = q.Encode()
@@ -88,6 +96,14 @@ func (h *getItemsHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
 		http.Error(w, err.Error(), 500)
 		return
 	}
+	req.WithContext(ctx)
+	if span := opentracing.SpanFromContext(r.Context()); span != nil {
+		opentracing.GlobalTracer().Inject(
+			span.Context(),
+			opentracing.HTTPHeaders,
+			opentracing.HTTPHeadersCarrier(req.Header))
+	}
+
 	resp, err := h.hclient.Do(req)
 	if err != nil {
 		h.logger.Error(err.Error())
diff --git a/frontend/handler/health.go b/frontend/handler/health.go
index fa9e52f..7720a28 100644
--- a/frontend/handler/health.go
+++ b/frontend/handler/health.go
@@ -1,12 +1,14 @@
 package handler

 import (
+	"context"
 	"encoding/json"
 	"fmt"
 	"io/ioutil"
 	"net/http"

 	"github.com/gianarb/shopmany/frontend/config"
+	opentracing "github.com/opentracing/opentracing-go"
 	"go.uber.org/zap"
 )

@@ -50,7 +52,7 @@ func (h *healthHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
 	}
 	w.Header().Add("Content-Type", "application/json")

-	itemCheck := checkItem(h.config.ItemHost, h.hclient)
+	itemCheck := checkItem(r.Context(), h.hclient, h.config.ItemHost)
 	if itemCheck.Status == healthy {
 		b.Status = healthy
 	}
@@ -68,14 +70,23 @@ func (h *healthHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
 	fmt.Fprintf(w, string(body))
 }

-func checkItem(host string, hclient *http.Client) check {
+func checkItem(ctx context.Context, httpClient *http.Client, host string) check {
 	c := check{
 		Name:   "item",
 		Error:  "",
 		Status: unhealthy,
 	}
-	req, _ := http.NewRequest("GET", fmt.Sprintf("%s/health", host), nil)
-	resp, err := hclient.Do(req)
+	r, _ := http.NewRequest("GET", fmt.Sprintf("%s/health", host), nil)
+	r = r.WithContext(ctx)
+
+	if span := opentracing.SpanFromContext(ctx); span != nil {
+		opentracing.GlobalTracer().Inject(
+			span.Context(),
+			opentracing.HTTPHeaders,
+			opentracing.HTTPHeadersCarrier(r.Header))
+	}
+
+	resp, err := httpClient.Do(r)
 	if err != nil {
 		c.Error = err.Error()
 		return c
diff --git a/frontend/handler/pay.go b/frontend/handler/pay.go
index f3e5434..f87ad89 100644
--- a/frontend/handler/pay.go
+++ b/frontend/handler/pay.go
@@ -5,6 +5,7 @@ import (
 	"net/http"

 	"github.com/gianarb/shopmany/frontend/config"
+	opentracing "github.com/opentracing/opentracing-go"
 	"go.uber.org/zap"
 )

@@ -38,6 +39,13 @@ func (h *payHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
 		http.Error(w, err.Error(), 500)
 		return
 	}
+	req.WithContext(r.Context())
+	if span := opentracing.SpanFromContext(r.Context()); span != nil {
+		opentracing.GlobalTracer().Inject(
+			span.Context(),
+			opentracing.HTTPHeaders,
+			opentracing.HTTPHeadersCarrier(req.Header))
+	}
 	req.Header.Add("Content-Type", "application/json")
 	resp, err := h.hclient.Do(req)
 	if err != nil {
diff --git a/frontend/main.go b/frontend/main.go
index 35a084c..a310355 100644
--- a/frontend/main.go
+++ b/frontend/main.go
@@ -5,21 +5,44 @@ import (
 	"log"
 	"net/http"

+	"github.com/opentracing-contrib/go-stdlib/nethttp"
+	opentracing "github.com/opentracing/opentracing-go"
+	jaeger "github.com/uber/jaeger-client-go"
+	jconfig "github.com/uber/jaeger-client-go/config"
+
 	"github.com/gianarb/shopmany/frontend/config"
 	"github.com/gianarb/shopmany/frontend/handler"
 	flags "github.com/jessevdk/go-flags"
+	jaegerZap "github.com/uber/jaeger-client-go/log/zap"
+	"go.opencensus.io/plugin/ochttp"
 	"go.uber.org/zap"
 )

 func main() {
 	logger, _ := zap.NewProduction()
 	defer logger.Sync()
+
 	config := config.Config{}
 	_, err := flags.Parse(&config)
+	if err != nil {
+		logger.Fatal(err.Error())
+	}

+	cfg, err := jconfig.FromEnv()
+	if err != nil {
+		logger.Fatal(err.Error())
+	}
+	cfg.Reporter.LogSpans = true
+	cfg.Sampler = &jconfig.SamplerConfig{
+		Type:  "const",
+		Param: 1,
+	}
+	tracer, closer, err := cfg.NewTracer(jconfig.Logger(jaegerZap.NewLogger(logger.With(zap.String("service", "jaeger-go")))))
 	if err != nil {
-		panic(err)
+		logger.Fatal(err.Error())
 	}
+	defer closer.Close()
+	opentracing.SetGlobalTracer(tracer)

 	fmt.Printf("Item Host: %v\n", config.ItemHost)
 	fmt.Printf("Pay Host: %v\n", config.PayHost)
@@ -27,7 +50,7 @@ func main() {

 	mux := http.NewServeMux()

-	httpClient := &http.Client{}
+	httpClient := &http.Client{Transport: &ochttp.Transport{}}
 	fs := http.FileServer(http.Dir("static"))

 	httpdLogger := logger.With(zap.String("service", "httpd"))
@@ -44,11 +67,16 @@ func main() {
 	mux.Handle("/health", healthHandler)

 	log.Println("Listening on port 3000...")
-	http.ListenAndServe(":3000", loggingMiddleware(httpdLogger.With(zap.String("from", "middleware")), mux))
+	http.ListenAndServe(":3000", nethttp.Middleware(tracer, loggingMiddleware(httpdLogger.With(zap.String("from", "middleware")), mux)))
 }

 func loggingMiddleware(logger *zap.Logger, h http.Handler) http.Handler {
 	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
+		if span := opentracing.SpanFromContext(r.Context()); span != nil {
+			if sc, ok := span.Context().(jaeger.SpanContext); ok {
+				w.Header().Add("X-Trace-ID", sc.TraceID().String())
+			}
+		}
 		logger.Info(
 			"HTTP Request",
 			zap.String("Path", r.URL.Path),
```
\newpage

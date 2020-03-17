# Solution lesson 4 - Tracing

## Item

```diff
From 99bb8bc64da8dda88be47a74dd327ec540358ff9 Mon Sep 17 00:00:00 2001
From: Gianluca Arbezzano <gianarb92@gmail.com>
Date: Tue, 17 Mar 2020 14:05:48 +0100
Subject: [PATCH] feat(items): tracing instrumentation with b3 and opencensus

Signed-off-by: Gianluca Arbezzano <gianarb92@gmail.com>
---
 items/composer.json                           |  6 ++-
 items/config/autoload/containers.global.php   |  2 +
 items/config/autoload/local.php               |  4 ++
 items/config/pipeline.php                     |  2 +
 .../App/src/Middleware/TracerMiddleware.php   | 46 +++++++++++++++++++
 .../Middleware/TracerMiddlewareFactory.php    | 19 ++++++++
 items/src/App/src/Service/TracerFactory.php   | 45 ++++++++++++++++++
 7 files changed, 122 insertions(+), 2 deletions(-)
 create mode 100644 items/src/App/src/Middleware/TracerMiddleware.php
 create mode 100644 items/src/App/src/Middleware/TracerMiddlewareFactory.php
 create mode 100644 items/src/App/src/Service/TracerFactory.php

diff --git a/items/composer.json b/items/composer.json
index c0badf9..dadea8b 100644
--- a/items/composer.json
+++ b/items/composer.json
@@ -18,6 +18,7 @@
     "config": {
         "sort-packages": true
     },
+    "minimum-stability": "dev",
     "extra": {
         "zf": {
             "component-whitelist": [
@@ -39,6 +40,8 @@
     "require": {
         "php": "^7.1",
         "http-interop/http-middleware": "^0.5.0",
+        "monolog/monolog": "1.24.0",
+        "jcchavezs/zipkin-opentracing": "0.1.4",
         "zendframework/zend-component-installer": "^2.1.1",
         "zendframework/zend-config-aggregator": "^1.0",
         "zendframework/zend-diactoros": "^1.7.1 || ^2.0",
@@ -46,8 +49,7 @@
         "zendframework/zend-expressive-fastroute": "^3.0",
         "zendframework/zend-expressive-helpers": "^5.0",
         "zendframework/zend-servicemanager": "^3.3",
-        "zendframework/zend-stdlib": "^3.1",
-        "monolog/monolog": "1.24.0"
+        "zendframework/zend-stdlib": "^3.1"
     },
     "require-dev": {
         "phpunit/phpunit": "^7.0.1",
diff --git a/items/config/autoload/containers.global.php b/items/config/autoload/containers.global.php
index 12a5b18..d36eb04 100644
--- a/items/config/autoload/containers.global.php
+++ b/items/config/autoload/containers.global.php
@@ -21,7 +21,9 @@ return [
             App\Handler\Item::class => App\Handler\ItemFactory::class,
             App\Handler\Health::class => App\Handler\HealthFactory::class,
             "Logger" => App\Service\LoggerFactory::class,
+            "Tracer" => App\Service\TracerFactory::class,
             App\Middleware\LoggerMiddleware::class => App\Middleware\LoggerMiddlewareFactory::class,
+            App\Middleware\TracerMiddleware::class => App\Middleware\TracerMiddlewareFactory::class,
         ],
     ],
 ];
diff --git a/items/config/autoload/local.php b/items/config/autoload/local.php
index 824e725..3726cc6 100644
--- a/items/config/autoload/local.php
+++ b/items/config/autoload/local.php
@@ -15,4 +15,8 @@ return [
         "user" => "root",
         "pass" => "root",
     ],
+    "zipkin" => [
+        "serviceName" => 'items',
+        "reporterURL" => 'http://jaeger:9411/api/v2/spans',
+    ],
 ];
diff --git a/items/config/pipeline.php b/items/config/pipeline.php
index e9287fd..6e050ca 100644
--- a/items/config/pipeline.php
+++ b/items/config/pipeline.php
@@ -15,12 +15,14 @@ use Zend\Expressive\Router\Middleware\MethodNotAllowedMiddleware;
 use Zend\Expressive\Router\Middleware\RouteMiddleware;
 use Zend\Stratigility\Middleware\ErrorHandler;
 use App\Middleware\LoggerMiddleware;
+use App\Middleware\TracerMiddleware;
 
 /**
  * Setup middleware pipeline:
  */
 return function (Application $app, MiddlewareFactory $factory, ContainerInterface $container) : void {
     $app->pipe($container->get(LoggerMiddleware::class));
+    $app->pipe($container->get(TracerMiddleware::class));
     // The error handler should be the first (most outer) middleware to catch
     // all Exceptions.
     $app->pipe(ErrorHandler::class);
diff --git a/items/src/App/src/Middleware/TracerMiddleware.php b/items/src/App/src/Middleware/TracerMiddleware.php
new file mode 100644
index 0000000..6da42be
--- /dev/null
+++ b/items/src/App/src/Middleware/TracerMiddleware.php
@@ -0,0 +1,46 @@
+<?php
+namespace App\Middleware;
+
+use ErrorException;
+use OpenTracing\Formats;
+use OpenTracing\Tags;
+use OpenTracing\GlobalTracer;
+use Psr\Http\Message\ResponseInterface;
+use Psr\Http\Server\MiddlewareInterface;
+use Psr\Http\Message\ServerRequestInterface;
+use Psr\Http\Server\RequestHandlerInterface;
+
+class TracerMiddleware implements MiddlewareInterface
+{
+    private $tracer;
+
+    public function __construct($tracer)
+    {
+        $this->tracer = $tracer;
+    }
+
+    public function process(ServerRequestInterface $request, RequestHandlerInterface $handler) : ResponseInterface
+    {
+        $spanContext = $this->tracer->extract(
+            Formats\HTTP_HEADERS,
+            $request
+        );
+        $span = $this->tracer->startSpan($request->getMethod(), [
+            'child_of' => $spanContext,
+            'tags' => [
+                Tags\HTTP_METHOD => $request->getMethod(),
+                'http.path' => $request->getUri()->getPath(),
+            ]
+        ]);
+        
+        try {
+            $response = $handler->handle($request);
+            $span->setTag(Tags\HTTP_STATUS_CODE, $response->getStatusCode());
+            return $response;
+        } catch (\Throwable $e) {
+            $span->setTag(Tags\ERROR, $e->getMessage());
+        } finally {
+            $span->finish();
+        }
+    }
+}
diff --git a/items/src/App/src/Middleware/TracerMiddlewareFactory.php b/items/src/App/src/Middleware/TracerMiddlewareFactory.php
new file mode 100644
index 0000000..fe49d64
--- /dev/null
+++ b/items/src/App/src/Middleware/TracerMiddlewareFactory.php
@@ -0,0 +1,19 @@
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
+    private $tracer;
+
+    public function __invoke(ContainerInterface $container) {
+        $tracer = $container->get("Tracer");
+        return new TracerMiddleware($tracer);
+    }
+}
diff --git a/items/src/App/src/Service/TracerFactory.php b/items/src/App/src/Service/TracerFactory.php
new file mode 100644
index 0000000..6795347
--- /dev/null
+++ b/items/src/App/src/Service/TracerFactory.php
@@ -0,0 +1,45 @@
+<?php
+namespace App\Service;
+
+use Zipkin\Endpoint;
+use Psr\Log\NullLogger;
+use Zipkin\TracingBuilder;
+use OpenTracing\GlobalTracer;
+use OpenTracing\NoopTracer;
+use ZipkinOpenTracing\Tracer;
+use Zipkin\Samplers\BinarySampler;
+use Psr\Container\ContainerInterface;
+use Zipkin\Reporters\Http\CurlFactory;
+use Zipkin\Reporters\Http as HttpReporter;
+
+class TracerFactory
+{
+    public function __invoke(ContainerInterface $container)
+    {
+        $zipkinConfig = $container->get('config')['zipkin'] ?? [];
+        if (empty($zipkinConfig)) {
+            // If zipkin is not configured then we return an empty tracer.
+            return NoopTracer::create();
+        }
+
+        $endpoint = Endpoint::create($zipkinConfig['serviceName']);
+        $reporter = new HttpReporter(CurlFactory::create(), ["endpoint_url" => $zipkinConfig['reporterURL'] ?? 'http://localhost:9411/api/v2/spans']);
+        $sampler = BinarySampler::createAsAlwaysSample();
+        $tracing = TracingBuilder::create()
+            ->havingLocalEndpoint($endpoint)
+           ->havingSampler($sampler)
+           ->havingReporter($reporter)
+           ->build();
+
+        $zipkinTracer = new Tracer($tracing);
+
+        register_shutdown_function(function () {
+            /* Flush the tracer to the backend */
+            $zipkinTracer = GlobalTracer::get();
+            $zipkinTracer->flush();
+        });
+
+        GlobalTracer::set($zipkinTracer);
+        return $zipkinTracer;
+    }
+}
-- 
2.23.0
```

## Discount

```diff
From d646f1892643d65b409397c47b363e4e01b4c38a Mon Sep 17 00:00:00 2001
From: Gianluca Arbezzano <gianarb92@gmail.com>
Date: Thu, 12 Mar 2020 21:43:52 +0100
Subject: [PATCH] feat(discount): added tracing

Signed-off-by: Gianluca Arbezzano <gianarb92@gmail.com>
---
 discount/package.json |  8 ++++++++
 discount/server.js    | 26 ++++++++++++++++++--------
 discount/tracer.js    | 42 ++++++++++++++++++++++++++++++++++++++++++
 3 files changed, 68 insertions(+), 8 deletions(-)
 create mode 100644 discount/tracer.js

diff --git a/discount/package.json b/discount/package.json
index 1640ae1..fff748e 100644
--- a/discount/package.json
+++ b/discount/package.json
@@ -10,6 +10,14 @@
   "author": "",
   "license": "ISC",
   "dependencies": {
+    "@opentelemetry/api": "^0.5.0",
+    "@opentelemetry/exporter-jaeger": "^0.5.0",
+    "@opentelemetry/node": "^0.5.0",
+    "@opentelemetry/plugin-http": "^0.5.0",
+    "@opentelemetry/plugin-dns": "^0.5.0",
+    "@opentelemetry/plugin-mongodb": "^0.5.0",
+    "@opentelemetry/tracing": "^0.5.0",
+    "@opentelemetry/plugin-express": "^0.5.0",
     "express": "^4.16.4",
     "express-pino-logger": "^4.0.0",
     "mongodb": "^3.1.13"
diff --git a/discount/server.js b/discount/server.js
index 50a32a9..78b89e1 100644
--- a/discount/server.js
+++ b/discount/server.js
@@ -1,20 +1,26 @@
-var express = require("express");
+'use strict';
+
+const url = process.env.DISCOUNT_MONGODB_URL || 'mongodb://discountdb:27017';
+const jaegerHost = process.env.JAEGER_HOST || 'jaeger';

+const logger = require('pino')()
+const tracer = require('./tracer')('discount', jaegerHost, logger);
+
+var express = require("express");
 var app = express();

 const MongoClient = require('mongodb').MongoClient;
-const url = 'mongodb://discountdb:27017';
 const dbName = 'shopmany';
 const client = new MongoClient(url, { useNewUrlParser: true });
-app.use(errorHandler)

-const logger = require('pino')()
 const expressPino = require('express-pino-logger')({
   logger: logger.child({"service": "httpd"})
 })
+
+//app.use(errorHandler)
 app.use(expressPino)

-app.get("/health", function(req, res, next) {
+app.get("/health", function(req, res) {
   var resbody = {
     "status": "healthy",
     checks: [],
@@ -40,7 +46,11 @@ app.get("/health", function(req, res, next) {

 app.get("/discount", function(req, res, next) {
   client.connect(function(err) {
-    db = client.db(dbName);
+    if (err != null) {
+      req.log.error(err.toString());
+      return next(err)
+    }
+    let db = client.db(dbName);
     db.collection('discount').find({}).toArray(function(err, discounts) {
       if (err != null) {
         req.log.error(err.toString());
@@ -63,12 +73,12 @@ app.get("/discount", function(req, res, next) {
   });
 });

-app.use(function(req, res, next) {
+app.use(function(req, res) {
   req.log.warn("route not found");
   return res.status(404).json({error: "route not found"});
 });

-function errorHandler(err, req, res, next) {
+function errorHandler(err, req, res) {
   req.log.error(err.toString(), {
     error_status: err.status
   });
diff --git a/discount/tracer.js b/discount/tracer.js
new file mode 100644
index 0000000..a39d0c7
--- /dev/null
+++ b/discount/tracer.js
@@ -0,0 +1,42 @@
+'use strict';
+
+const opentelemetry = require('@opentelemetry/api');
+const { NodeTracerProvider } = require('@opentelemetry/node');
+const { SimpleSpanProcessor } = require('@opentelemetry/tracing');
+const { JaegerExporter } = require('@opentelemetry/exporter-jaeger');
+const { B3Propagator } = require('@opentelemetry/core');
+
+module.exports = (serviceName, jaegerHost, logger) => {
+  const provider = new NodeTracerProvider({
+    plugins: {
+      dns: {
+        enabled: true,
+        path: '@opentelemetry/plugin-dns',
+      },
+      mongodb: {
+        enabled: true,
+        path: '@opentelemetry/plugin-mongodb',
+      },
+      http: {
+        enabled: true,
+        path: '@opentelemetry/plugin-http',
+      },
+      express: {
+        enabled: true,
+        path: '@opentelemetry/plugin-express',
+      },
+    }
+  });
+
+  let exporter = new JaegerExporter({
+    logger: logger,
+    serviceName: serviceName,
+    host: jaegerHost
+  });
+
+  provider.addSpanProcessor(new SimpleSpanProcessor(exporter));
+  provider.register({
+    propagator: new B3Propagator(),
+  });
+  return opentelemetry.trace.getTracer("discount");
+};
--
2.23.0
```

## Pay

```
From 7917579a9541b1ef207e950f697165e622b55fee Mon Sep 17 00:00:00 2001
From: Gianluca Arbezzano <gianarb92@gmail.com>
Date: Sun, 15 Mar 2020 14:34:41 +0100
Subject: [PATCH] fix(pay): Trace with B3 and opentelemetry

Signed-off-by: Gianluca Arbezzano <gianarb92@gmail.com>
---
 pay/.gitignore                               |  10 ++
 pay/build.gradle                             |   6 +
 pay/gradlew                                  | 172 -------------------
 pay/src/main/java/pay/AppConfig.java         |   1 +
 pay/src/main/java/pay/Application.java       |  22 +++
 pay/src/main/java/pay/TracerInterceptor.java |  63 +++++++
 6 files changed, 102 insertions(+), 172 deletions(-)
 create mode 100644 pay/.gitignore
 delete mode 100755 pay/gradlew
 create mode 100644 pay/src/main/java/pay/TracerInterceptor.java

diff --git a/pay/.gitignore b/pay/.gitignore
new file mode 100644
index 0000000..70463c2
--- /dev/null
+++ b/pay/.gitignore
@@ -0,0 +1,10 @@
+.gradle
+build
+.settings
+.idea
+.project
+gradle/wrapper/gradle-wrapper.jar
+gradle/wrapper/gradle-wrapper.properties
+gradlew
+gradlew.bat
+
diff --git a/pay/build.gradle b/pay/build.gradle
index 50bb905..422f0ed 100644
--- a/pay/build.gradle
+++ b/pay/build.gradle
@@ -33,6 +33,12 @@ dependencies {
     compile("org.springframework.boot:spring-boot-starter-web"){ exclude group: 'org.springframework.boot', module: 'spring-boot-starter-logging'}
     compile('org.springframework.boot:spring-boot-starter-log4j2')
     testCompile('org.springframework.boot:spring-boot-starter-test')
+    compile('io.opentelemetry:opentelemetry-api:0.2.4')
+    compile('io.opentelemetry:opentelemetry-sdk:0.2.4')
+    compile('io.opentelemetry:opentelemetry-exporters-jaeger:0.2.4')
+    compile('io.opentelemetry:opentelemetry-exporters-logging:0.2.4')
+    compile('io.grpc:grpc-protobuf:1.24.0')
+    compile('io.grpc:grpc-netty-shaded:1.24.0')
 }


diff --git a/pay/gradlew b/pay/gradlew
deleted file mode 100755
index cccdd3d..0000000
--- a/pay/gradlew
+++ /dev/null
@@ -1,172 +0,0 @@
-#!/usr/bin/env sh
-
-##############################################################################
-##
-##  Gradle start up script for UN*X
-##
-##############################################################################
-
-# Attempt to set APP_HOME
-# Resolve links: $0 may be a link
-PRG="$0"
-# Need this for relative symlinks.
-while [ -h "$PRG" ] ; do
-    ls=`ls -ld "$PRG"`
-    link=`expr "$ls" : '.*-> \(.*\)$'`
-    if expr "$link" : '/.*' > /dev/null; then
-        PRG="$link"
-    else
-        PRG=`dirname "$PRG"`"/$link"
-    fi
-done
-SAVED="`pwd`"
-cd "`dirname \"$PRG\"`/" >/dev/null
-APP_HOME="`pwd -P`"
-cd "$SAVED" >/dev/null
-
-APP_NAME="Gradle"
-APP_BASE_NAME=`basename "$0"`
-
-# Add default JVM options here. You can also use JAVA_OPTS and GRADLE_OPTS to pass JVM options to this script.
-DEFAULT_JVM_OPTS=""
-
-# Use the maximum available, or set MAX_FD != -1 to use that value.
-MAX_FD="maximum"
-
-warn () {
-    echo "$*"
-}
-
-die () {
-    echo
-    echo "$*"
-    echo
-    exit 1
-}
-
-# OS specific support (must be 'true' or 'false').
-cygwin=false
-msys=false
-darwin=false
-nonstop=false
-case "`uname`" in
-  CYGWIN* )
-    cygwin=true
-    ;;
-  Darwin* )
-    darwin=true
-    ;;
-  MINGW* )
-    msys=true
-    ;;
-  NONSTOP* )
-    nonstop=true
-    ;;
-esac
-
-CLASSPATH=$APP_HOME/gradle/wrapper/gradle-wrapper.jar
-
-# Determine the Java command to use to start the JVM.
-if [ -n "$JAVA_HOME" ] ; then
-    if [ -x "$JAVA_HOME/jre/sh/java" ] ; then
-        # IBM's JDK on AIX uses strange locations for the executables
-        JAVACMD="$JAVA_HOME/jre/sh/java"
-    else
-        JAVACMD="$JAVA_HOME/bin/java"
-    fi
-    if [ ! -x "$JAVACMD" ] ; then
-        die "ERROR: JAVA_HOME is set to an invalid directory: $JAVA_HOME
-
-Please set the JAVA_HOME variable in your environment to match the
-location of your Java installation."
-    fi
-else
-    JAVACMD="java"
-    which java >/dev/null 2>&1 || die "ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.
-
-Please set the JAVA_HOME variable in your environment to match the
-location of your Java installation."
-fi
-
-# Increase the maximum file descriptors if we can.
-if [ "$cygwin" = "false" -a "$darwin" = "false" -a "$nonstop" = "false" ] ; then
-    MAX_FD_LIMIT=`ulimit -H -n`
-    if [ $? -eq 0 ] ; then
-        if [ "$MAX_FD" = "maximum" -o "$MAX_FD" = "max" ] ; then
-            MAX_FD="$MAX_FD_LIMIT"
-        fi
-        ulimit -n $MAX_FD
-        if [ $? -ne 0 ] ; then
-            warn "Could not set maximum file descriptor limit: $MAX_FD"
-        fi
-    else
-        warn "Could not query maximum file descriptor limit: $MAX_FD_LIMIT"
-    fi
-fi
-
-# For Darwin, add options to specify how the application appears in the dock
-if $darwin; then
-    GRADLE_OPTS="$GRADLE_OPTS \"-Xdock:name=$APP_NAME\" \"-Xdock:icon=$APP_HOME/media/gradle.icns\""
-fi
-
-# For Cygwin, switch paths to Windows format before running java
-if $cygwin ; then
-    APP_HOME=`cygpath --path --mixed "$APP_HOME"`
-    CLASSPATH=`cygpath --path --mixed "$CLASSPATH"`
-    JAVACMD=`cygpath --unix "$JAVACMD"`
-
-    # We build the pattern for arguments to be converted via cygpath
-    ROOTDIRSRAW=`find -L / -maxdepth 1 -mindepth 1 -type d 2>/dev/null`
-    SEP=""
-    for dir in $ROOTDIRSRAW ; do
-        ROOTDIRS="$ROOTDIRS$SEP$dir"
-        SEP="|"
-    done
-    OURCYGPATTERN="(^($ROOTDIRS))"
-    # Add a user-defined pattern to the cygpath arguments
-    if [ "$GRADLE_CYGPATTERN" != "" ] ; then
-        OURCYGPATTERN="$OURCYGPATTERN|($GRADLE_CYGPATTERN)"
-    fi
-    # Now convert the arguments - kludge to limit ourselves to /bin/sh
-    i=0
-    for arg in "$@" ; do
-        CHECK=`echo "$arg"|egrep -c "$OURCYGPATTERN" -`
-        CHECK2=`echo "$arg"|egrep -c "^-"`                                 ### Determine if an option
-
-        if [ $CHECK -ne 0 ] && [ $CHECK2 -eq 0 ] ; then                    ### Added a condition
-            eval `echo args$i`=`cygpath --path --ignore --mixed "$arg"`
-        else
-            eval `echo args$i`="\"$arg\""
-        fi
-        i=$((i+1))
-    done
-    case $i in
-        (0) set -- ;;
-        (1) set -- "$args0" ;;
-        (2) set -- "$args0" "$args1" ;;
-        (3) set -- "$args0" "$args1" "$args2" ;;
-        (4) set -- "$args0" "$args1" "$args2" "$args3" ;;
-        (5) set -- "$args0" "$args1" "$args2" "$args3" "$args4" ;;
-        (6) set -- "$args0" "$args1" "$args2" "$args3" "$args4" "$args5" ;;
-        (7) set -- "$args0" "$args1" "$args2" "$args3" "$args4" "$args5" "$args6" ;;
-        (8) set -- "$args0" "$args1" "$args2" "$args3" "$args4" "$args5" "$args6" "$args7" ;;
-        (9) set -- "$args0" "$args1" "$args2" "$args3" "$args4" "$args5" "$args6" "$args7" "$args8" ;;
-    esac
-fi
-
-# Escape application args
-save () {
-    for i do printf %s\\n "$i" | sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/' \\\\/" ; done
-    echo " "
-}
-APP_ARGS=$(save "$@")
-
-# Collect all arguments for the java command, following the shell quoting and substitution rules
-eval set -- $DEFAULT_JVM_OPTS $JAVA_OPTS $GRADLE_OPTS "\"-Dorg.gradle.appname=$APP_BASE_NAME\"" -classpath "\"$CLASSPATH\"" org.gradle.wrapper.GradleWrapperMain "$APP_ARGS"
-
-# by default we should be in the correct project dir, but when run from Finder on Mac, the cwd is wrong
-if [ "$(uname)" = "Darwin" ] && [ "$HOME" = "$PWD" ]; then
-  cd "$(dirname "$0")"
-fi
-
-exec "$JAVACMD" "$@"
diff --git a/pay/src/main/java/pay/AppConfig.java b/pay/src/main/java/pay/AppConfig.java
index bb788cb..d6e780a 100644
--- a/pay/src/main/java/pay/AppConfig.java
+++ b/pay/src/main/java/pay/AppConfig.java
@@ -10,5 +10,6 @@ public class AppConfig extends WebMvcConfigurerAdapter  {
     @Override
     public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new LoggerInterceptor());
+       registry.addInterceptor(new TracerInterceptor());
     }
 }
diff --git a/pay/src/main/java/pay/Application.java b/pay/src/main/java/pay/Application.java
index 1d8d39d..201fd73 100644
--- a/pay/src/main/java/pay/Application.java
+++ b/pay/src/main/java/pay/Application.java
@@ -1,5 +1,11 @@
 package pay;

+import io.grpc.ManagedChannel;
+import io.grpc.ManagedChannelBuilder;
+import io.opentelemetry.exporters.jaeger.JaegerGrpcSpanExporter;
+import io.opentelemetry.exporters.logging.LoggingSpanExporter;
+import io.opentelemetry.sdk.OpenTelemetrySdk;
+import io.opentelemetry.sdk.trace.export.SimpleSpansProcessor;
 import org.springframework.boot.SpringApplication;
 import org.springframework.boot.autoconfigure.SpringBootApplication;
 import org.springframework.http.ResponseEntity;
@@ -54,7 +60,23 @@ public class Application {
     }

     public static void main(String[] args) {
+        // Create a channel towards Jaeger end point
+        ManagedChannel jaegerChannel = ManagedChannelBuilder.forAddress("jaeger", 14250).usePlaintext().build();
+        // Export traces to Jaeger
+
+        JaegerGrpcSpanExporter jaegerExporter = JaegerGrpcSpanExporter.newBuilder()
+                .setServiceName("pay")
+                .setChannel(jaegerChannel)
+                .setDeadlineMs(30000)
+                .build();
+        // Export also to the console
+        LoggingSpanExporter loggingExporter = new LoggingSpanExporter();
+        OpenTelemetrySdk.getTracerProvider().addSpanProcessor(SimpleSpansProcessor.newBuilder(loggingExporter).build());
+        // Set to process the spans by the Jaeger Exporter
+        OpenTelemetrySdk.getTracerProvider()
+                .addSpanProcessor(SimpleSpansProcessor.newBuilder(jaegerExporter).build());
         SpringApplication.run(Application.class, args);
     }

 }
+
diff --git a/pay/src/main/java/pay/TracerInterceptor.java b/pay/src/main/java/pay/TracerInterceptor.java
new file mode 100644
index 0000000..a37a508
--- /dev/null
+++ b/pay/src/main/java/pay/TracerInterceptor.java
@@ -0,0 +1,63 @@
+package pay;
+
+import com.sun.net.httpserver.HttpExchange;
+import io.opentelemetry.OpenTelemetry;
+import io.opentelemetry.context.propagation.HttpTextFormat;
+import io.opentelemetry.trace.Span;
+import io.opentelemetry.trace.SpanContext;
+import io.opentelemetry.trace.Tracer;
+import io.opentelemetry.trace.propagation.B3Propagator;
+import org.springframework.stereotype.Component;
+import org.springframework.web.servlet.handler.HandlerInterceptorAdapter;
+
+import javax.servlet.http.HttpServletRequest;
+import javax.servlet.http.HttpServletResponse;
+
+import java.io.IOException;
+import java.net.URL;
+
+@Component
+public class TracerInterceptor
+        extends HandlerInterceptorAdapter {
+    // OTel API
+    private Tracer tracer =
+            OpenTelemetry.getTracerProvider().get("io.opentelemetry.pay.JaegerExample");
+
+    // false -> we expect multi header
+    B3Propagator b3Propagator = new B3Propagator(false);
+
+    B3Propagator.Getter<HttpServletRequest> getter = new B3Propagator.Getter<HttpServletRequest>() {
+        @javax.annotation.Nullable
+        @Override
+        public String get(HttpServletRequest carrier, String key) {
+            return carrier.getHeader(key);
+        }
+    };
+    private Span span;
+
+    @Override
+    public boolean preHandle(
+            HttpServletRequest request,
+            HttpServletResponse response,
+            Object handler) throws IOException {
+        URL url = new URL(request.getRequestURL().toString());
+        SpanContext remoteCtx = b3Propagator.extract(request, getter);
+        Span.Builder spanBuilder = tracer.spanBuilder(String.format("[%s] %d:%s", request.getMethod(), url.getPort(), url.getPath())).setSpanKind(Span.Kind.SERVER);
+        if(remoteCtx != null){
+            spanBuilder.setParent(remoteCtx);
+        }
+        span = spanBuilder.startSpan();
+        span.setAttribute("http.method", request.getMethod());
+        span.setAttribute("http.url", url.toString());
+        return true;
+    }
+    @Override
+    public void afterCompletion(
+            HttpServletRequest request,
+            HttpServletResponse response,
+            Object handler,
+            Exception ex) {
+        span.setAttribute("http.status_code", response.getStatus());
+        span.end();
+    }
+}
--
2.23.0
```

## Frontend

```diff
From 297539e0b76235ad8ef39c5e8e0f4c1080b12cf8 Mon Sep 17 00:00:00 2001
From: Gianluca Arbezzano <gianarb92@gmail.com>
Date: Wed, 11 Mar 2020 21:48:37 +0100
Subject: [PATCH] feat(frontend): Instrument http handlers

OpenTelemetry is is made of exporters, the easier to use is the stdout
one. It prints JSON to the process stdout.

Stdout is a good exporter but not the one you should use in production.
There are a lot of open source tracer around: Zipkin, Jaeger, Honeycomb,
AWS X-Ray, Google StackDriver. I tend to use Jaeger because it is in Go
and it is open source.

This commit adds the flag `--tracer` by default it is set to stdout, but
if you use `--tracer jaeger` the traces will be send to Jaeger. You can
override the Jaeger URl with `--tracer-jaeger-address`

Signed-off-by: Gianluca Arbezzano <gianarb92@gmail.com>
---
 docker-compose.yaml          |  2 +-
 frontend/config/config.go    |  8 +++---
 frontend/handler/getitems.go | 11 ++++++++
 frontend/handler/health.go   |  9 +++++--
 frontend/handler/pay.go      |  4 +++
 frontend/main.go             | 49 +++++++++++++++++++++++++++++++++---
 6 files changed, 74 insertions(+), 9 deletions(-)

diff --git a/docker-compose.yaml b/docker-compose.yaml
index bb9b123..6474bea 100644
--- a/docker-compose.yaml
+++ b/docker-compose.yaml
@@ -90,7 +90,7 @@ services:
   # frontend is the ui of the project
   frontend:
     image: golang:1.14.0-stretch
-    command: ["go", "run", "-mod", "vendor", "./main.go"]
+    command: ["go", "run", "-mod", "vendor", "./main.go", "--tracer", "jaeger", "--tracer-jaeger-address", "http://jaeger:14268/api/traces"]
     ports:
       - '3000:3000'
     volumes:
diff --git a/frontend/config/config.go b/frontend/config/config.go
index 5524a5b..55bd702 100644
--- a/frontend/config/config.go
+++ b/frontend/config/config.go
@@ -1,7 +1,9 @@
 package config

 type Config struct {
-	ItemHost     string `long:"item-host" description:"The hostname where the item service is located" default:"http://item"`
-	DiscountHost string `long:"discount-host" description:"The hostname where the discount service is located" default:"http://discount:3000"`
-	PayHost      string `long:"pay-host" description:"The hostname where the pay service is located" default:"http://pay:8080"`
+	ItemHost      string `long:"item-host" description:"The hostname where the item service is located" default:"http://item"`
+	DiscountHost  string `long:"discount-host" description:"The hostname where the discount service is located" default:"http://discount:3000"`
+	PayHost       string `long:"pay-host" description:"The hostname where the pay service is located" default:"http://pay:8080"`
+	Tracer        string `long:"tracer" description:"The place where traces get shiped to. By default it is stdout. Jaeger is also supported" default:"stdout"`
+	JaegerAddress string `long:"tracer-jaeger-address" description:"If Jaeger is set as tracer output this is the way you ovverride where to ship data to" default:"http://localhost:14268/api/traces"`
 }
diff --git a/frontend/handler/getitems.go b/frontend/handler/getitems.go
index 54a3d32..887b899 100644
--- a/frontend/handler/getitems.go
+++ b/frontend/handler/getitems.go
@@ -9,6 +9,9 @@ import (
 	"strconv"

 	"github.com/gianarb/shopmany/frontend/config"
+	"go.opentelemetry.io/otel/api/propagation"
+	"go.opentelemetry.io/otel/api/trace"
+	"go.opentelemetry.io/otel/plugin/httptrace"
 	"go.uber.org/zap"
 )

@@ -32,14 +35,20 @@ type DiscountResponse struct {
 	} `json:"discount"`
 }

+var props = propagation.New(propagation.WithInjectors(trace.B3{}))
+
 func getDiscountPerItem(ctx context.Context, hclient *http.Client, itemID int, discountHost string) (int, error) {
 	req, err := http.NewRequest("GET", fmt.Sprintf("%s/discount", discountHost), nil)
 	if err != nil {
 		return 0, err
 	}
+
 	q := req.URL.Query()
 	q.Add("itemid", strconv.Itoa(itemID))
 	req.URL.RawQuery = q.Encode()
+
+	ctx, req = httptrace.W3C(ctx, req)
+	propagation.InjectHTTP(ctx, props, req.Header)
 	resp, err := hclient.Do(req)
 	if err != nil {
 		return 0, err
@@ -88,6 +97,8 @@ func (h *getItemsHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
 		http.Error(w, err.Error(), 500)
 		return
 	}
+	ctx, req = httptrace.W3C(ctx, req)
+	propagation.InjectHTTP(ctx, props, req.Header)
 	resp, err := h.hclient.Do(req)
 	if err != nil {
 		h.logger.Error(err.Error())
diff --git a/frontend/handler/health.go b/frontend/handler/health.go
index fa9e52f..39fd873 100644
--- a/frontend/handler/health.go
+++ b/frontend/handler/health.go
@@ -1,12 +1,15 @@
 package handler

 import (
+	"context"
 	"encoding/json"
 	"fmt"
 	"io/ioutil"
 	"net/http"

 	"github.com/gianarb/shopmany/frontend/config"
+	"go.opentelemetry.io/otel/api/propagation"
+	"go.opentelemetry.io/otel/plugin/httptrace"
 	"go.uber.org/zap"
 )

@@ -50,7 +53,7 @@ func (h *healthHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
 	}
 	w.Header().Add("Content-Type", "application/json")

-	itemCheck := checkItem(h.config.ItemHost, h.hclient)
+	itemCheck := checkItem(r.Context(), h.config.ItemHost, h.hclient)
 	if itemCheck.Status == healthy {
 		b.Status = healthy
 	}
@@ -68,13 +71,15 @@ func (h *healthHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
 	fmt.Fprintf(w, string(body))
 }

-func checkItem(host string, hclient *http.Client) check {
+func checkItem(ctx context.Context, host string, hclient *http.Client) check {
 	c := check{
 		Name:   "item",
 		Error:  "",
 		Status: unhealthy,
 	}
 	req, _ := http.NewRequest("GET", fmt.Sprintf("%s/health", host), nil)
+	ctx, req = httptrace.W3C(ctx, req)
+	propagation.InjectHTTP(ctx, props, req.Header)
 	resp, err := hclient.Do(req)
 	if err != nil {
 		c.Error = err.Error()
diff --git a/frontend/handler/pay.go b/frontend/handler/pay.go
index f3e5434..49d63c1 100644
--- a/frontend/handler/pay.go
+++ b/frontend/handler/pay.go
@@ -5,6 +5,8 @@ import (
 	"net/http"

 	"github.com/gianarb/shopmany/frontend/config"
+	"go.opentelemetry.io/otel/api/propagation"
+	"go.opentelemetry.io/otel/plugin/httptrace"
 	"go.uber.org/zap"
 )

@@ -38,6 +40,8 @@ func (h *payHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
 		http.Error(w, err.Error(), 500)
 		return
 	}
+	ctx, req := httptrace.W3C(r.Context(), req)
+	propagation.InjectHTTP(ctx, props, req.Header)
 	req.Header.Add("Content-Type", "application/json")
 	resp, err := h.hclient.Do(req)
 	if err != nil {
diff --git a/frontend/main.go b/frontend/main.go
index 35a084c..5f5e157 100644
--- a/frontend/main.go
+++ b/frontend/main.go
@@ -8,6 +8,11 @@ import (
 	"github.com/gianarb/shopmany/frontend/config"
 	"github.com/gianarb/shopmany/frontend/handler"
 	flags "github.com/jessevdk/go-flags"
+	"go.opentelemetry.io/otel/api/global"
+	"go.opentelemetry.io/otel/exporters/trace/jaeger"
+	"go.opentelemetry.io/otel/exporters/trace/stdout"
+	"go.opentelemetry.io/otel/plugin/othttp"
+	sdktrace "go.opentelemetry.io/otel/sdk/trace"
 	"go.uber.org/zap"
 )

@@ -21,6 +26,44 @@ func main() {
 		panic(err)
 	}

+	exporter, err := stdout.NewExporter(stdout.Options{PrettyPrint: true})
+	if err != nil {
+		log.Fatal(err)
+	}
+	tp, err := sdktrace.NewProvider(sdktrace.WithConfig(sdktrace.Config{DefaultSampler: sdktrace.AlwaysSample()}),
+		sdktrace.WithSyncer(exporter))
+	if err != nil {
+		log.Fatal(err)
+	}
+	global.SetTraceProvider(tp)
+
+	if config.Tracer == "jaeger" {
+
+		logger.Info("Used the tracer output jaeger")
+		// Create Jaeger Exporter
+		exporter, err := jaeger.NewExporter(
+			jaeger.WithCollectorEndpoint(config.JaegerAddress),
+			jaeger.WithProcess(jaeger.Process{
+				ServiceName: "frontend",
+			}),
+		)
+		if err != nil {
+			log.Fatal(err)
+		}
+
+		// For demoing purposes, always sample. In a production application, you should
+		// configure this to a trace.ProbabilitySampler set at the desired
+		// probability.
+		tp, err := sdktrace.NewProvider(
+			sdktrace.WithConfig(sdktrace.Config{DefaultSampler: sdktrace.AlwaysSample()}),
+			sdktrace.WithSyncer(exporter))
+		if err != nil {
+			log.Fatal(err)
+		}
+		global.SetTraceProvider(tp)
+		defer exporter.Flush()
+	}
+
 	fmt.Printf("Item Host: %v\n", config.ItemHost)
 	fmt.Printf("Pay Host: %v\n", config.PayHost)
 	fmt.Printf("Discount Host: %v\n", config.DiscountHost)
@@ -39,9 +82,9 @@ func main() {
 	healthHandler.WithLogger(logger)

 	mux.Handle("/", fs)
-	mux.Handle("/api/items", getItemsHandler)
-	mux.Handle("/api/pay", payHandler)
-	mux.Handle("/health", healthHandler)
+	mux.Handle("/api/items", othttp.NewHandler(getItemsHandler, "http.GetItems"))
+	mux.Handle("/api/pay", othttp.NewHandler(payHandler, "http.Pay"))
+	mux.Handle("/health", othttp.NewHandler(healthHandler, "http.health"))

 	log.Println("Listening on port 3000...")
 	http.ListenAndServe(":3000", loggingMiddleware(httpdLogger.With(zap.String("from", "middleware")), mux))
--
2.23.0

From 297539e0b76235ad8ef39c5e8e0f4c1080b12cf8 Mon Sep 17 00:00:00 2001
From: Gianluca Arbezzano <gianarb92@gmail.com>
Date: Wed, 11 Mar 2020 21:48:37 +0100
Subject: [PATCH] feat(frontend): Instrument http handlers

OpenTelemetry is is made of exporters, the easier to use is the stdout
one. It prints JSON to the process stdout.

Stdout is a good exporter but not the one you should use in production.
There are a lot of open source tracer around: Zipkin, Jaeger, Honeycomb,
AWS X-Ray, Google StackDriver. I tend to use Jaeger because it is in Go
and it is open source.

This commit adds the flag `--tracer` by default it is set to stdout, but
if you use `--tracer jaeger` the traces will be send to Jaeger. You can
override the Jaeger URl with `--tracer-jaeger-address`

Signed-off-by: Gianluca Arbezzano <gianarb92@gmail.com>
---
 docker-compose.yaml          |  2 +-
 frontend/config/config.go    |  8 +++---
 frontend/handler/getitems.go | 11 ++++++++
 frontend/handler/health.go   |  9 +++++--
 frontend/handler/pay.go      |  4 +++
 frontend/main.go             | 49 +++++++++++++++++++++++++++++++++---
 6 files changed, 74 insertions(+), 9 deletions(-)

diff --git a/docker-compose.yaml b/docker-compose.yaml
index bb9b123..6474bea 100644
--- a/docker-compose.yaml
+++ b/docker-compose.yaml
@@ -90,7 +90,7 @@ services:
   # frontend is the ui of the project
   frontend:
     image: golang:1.14.0-stretch
-    command: ["go", "run", "-mod", "vendor", "./main.go"]
+    command: ["go", "run", "-mod", "vendor", "./main.go", "--tracer", "jaeger", "--tracer-jaeger-address", "http://jaeger:14268/api/traces"]
     ports:
       - '3000:3000'
     volumes:
diff --git a/frontend/config/config.go b/frontend/config/config.go
index 5524a5b..55bd702 100644
--- a/frontend/config/config.go
+++ b/frontend/config/config.go
@@ -1,7 +1,9 @@
 package config

 type Config struct {
-	ItemHost     string `long:"item-host" description:"The hostname where the item service is located" default:"http://item"`
-	DiscountHost string `long:"discount-host" description:"The hostname where the discount service is located" default:"http://discount:3000"`
-	PayHost      string `long:"pay-host" description:"The hostname where the pay service is located" default:"http://pay:8080"`
+	ItemHost      string `long:"item-host" description:"The hostname where the item service is located" default:"http://item"`
+	DiscountHost  string `long:"discount-host" description:"The hostname where the discount service is located" default:"http://discount:3000"`
+	PayHost       string `long:"pay-host" description:"The hostname where the pay service is located" default:"http://pay:8080"`
+	Tracer        string `long:"tracer" description:"The place where traces get shiped to. By default it is stdout. Jaeger is also supported" default:"stdout"`
+	JaegerAddress string `long:"tracer-jaeger-address" description:"If Jaeger is set as tracer output this is the way you ovverride where to ship data to" default:"http://localhost:14268/api/traces"`
 }
diff --git a/frontend/handler/getitems.go b/frontend/handler/getitems.go
index 54a3d32..887b899 100644
--- a/frontend/handler/getitems.go
+++ b/frontend/handler/getitems.go
@@ -9,6 +9,9 @@ import (
 	"strconv"

 	"github.com/gianarb/shopmany/frontend/config"
+	"go.opentelemetry.io/otel/api/propagation"
+	"go.opentelemetry.io/otel/api/trace"
+	"go.opentelemetry.io/otel/plugin/httptrace"
 	"go.uber.org/zap"
 )

@@ -32,14 +35,20 @@ type DiscountResponse struct {
 	} `json:"discount"`
 }

+var props = propagation.New(propagation.WithInjectors(trace.B3{}))
+
 func getDiscountPerItem(ctx context.Context, hclient *http.Client, itemID int, discountHost string) (int, error) {
 	req, err := http.NewRequest("GET", fmt.Sprintf("%s/discount", discountHost), nil)
 	if err != nil {
 		return 0, err
 	}
+
 	q := req.URL.Query()
 	q.Add("itemid", strconv.Itoa(itemID))
 	req.URL.RawQuery = q.Encode()
+
+	ctx, req = httptrace.W3C(ctx, req)
+	propagation.InjectHTTP(ctx, props, req.Header)
 	resp, err := hclient.Do(req)
 	if err != nil {
 		return 0, err
@@ -88,6 +97,8 @@ func (h *getItemsHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
 		http.Error(w, err.Error(), 500)
 		return
 	}
+	ctx, req = httptrace.W3C(ctx, req)
+	propagation.InjectHTTP(ctx, props, req.Header)
 	resp, err := h.hclient.Do(req)
 	if err != nil {
 		h.logger.Error(err.Error())
diff --git a/frontend/handler/health.go b/frontend/handler/health.go
index fa9e52f..39fd873 100644
--- a/frontend/handler/health.go
+++ b/frontend/handler/health.go
@@ -1,12 +1,15 @@
 package handler

 import (
+	"context"
 	"encoding/json"
 	"fmt"
 	"io/ioutil"
 	"net/http"

 	"github.com/gianarb/shopmany/frontend/config"
+	"go.opentelemetry.io/otel/api/propagation"
+	"go.opentelemetry.io/otel/plugin/httptrace"
 	"go.uber.org/zap"
 )

@@ -50,7 +53,7 @@ func (h *healthHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
 	}
 	w.Header().Add("Content-Type", "application/json")

-	itemCheck := checkItem(h.config.ItemHost, h.hclient)
+	itemCheck := checkItem(r.Context(), h.config.ItemHost, h.hclient)
 	if itemCheck.Status == healthy {
 		b.Status = healthy
 	}
@@ -68,13 +71,15 @@ func (h *healthHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
 	fmt.Fprintf(w, string(body))
 }

-func checkItem(host string, hclient *http.Client) check {
+func checkItem(ctx context.Context, host string, hclient *http.Client) check {
 	c := check{
 		Name:   "item",
 		Error:  "",
 		Status: unhealthy,
 	}
 	req, _ := http.NewRequest("GET", fmt.Sprintf("%s/health", host), nil)
+	ctx, req = httptrace.W3C(ctx, req)
+	propagation.InjectHTTP(ctx, props, req.Header)
 	resp, err := hclient.Do(req)
 	if err != nil {
 		c.Error = err.Error()
diff --git a/frontend/handler/pay.go b/frontend/handler/pay.go
index f3e5434..49d63c1 100644
--- a/frontend/handler/pay.go
+++ b/frontend/handler/pay.go
@@ -5,6 +5,8 @@ import (
 	"net/http"

 	"github.com/gianarb/shopmany/frontend/config"
+	"go.opentelemetry.io/otel/api/propagation"
+	"go.opentelemetry.io/otel/plugin/httptrace"
 	"go.uber.org/zap"
 )

@@ -38,6 +40,8 @@ func (h *payHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
 		http.Error(w, err.Error(), 500)
 		return
 	}
+	ctx, req := httptrace.W3C(r.Context(), req)
+	propagation.InjectHTTP(ctx, props, req.Header)
 	req.Header.Add("Content-Type", "application/json")
 	resp, err := h.hclient.Do(req)
 	if err != nil {
diff --git a/frontend/main.go b/frontend/main.go
index 35a084c..5f5e157 100644
--- a/frontend/main.go
+++ b/frontend/main.go
@@ -8,6 +8,11 @@ import (
 	"github.com/gianarb/shopmany/frontend/config"
 	"github.com/gianarb/shopmany/frontend/handler"
 	flags "github.com/jessevdk/go-flags"
+	"go.opentelemetry.io/otel/api/global"
+	"go.opentelemetry.io/otel/exporters/trace/jaeger"
+	"go.opentelemetry.io/otel/exporters/trace/stdout"
+	"go.opentelemetry.io/otel/plugin/othttp"
+	sdktrace "go.opentelemetry.io/otel/sdk/trace"
 	"go.uber.org/zap"
 )

@@ -21,6 +26,44 @@ func main() {
 		panic(err)
 	}

+	exporter, err := stdout.NewExporter(stdout.Options{PrettyPrint: true})
+	if err != nil {
+		log.Fatal(err)
+	}
+	tp, err := sdktrace.NewProvider(sdktrace.WithConfig(sdktrace.Config{DefaultSampler: sdktrace.AlwaysSample()}),
+		sdktrace.WithSyncer(exporter))
+	if err != nil {
+		log.Fatal(err)
+	}
+	global.SetTraceProvider(tp)
+
+	if config.Tracer == "jaeger" {
+
+		logger.Info("Used the tracer output jaeger")
+		// Create Jaeger Exporter
+		exporter, err := jaeger.NewExporter(
+			jaeger.WithCollectorEndpoint(config.JaegerAddress),
+			jaeger.WithProcess(jaeger.Process{
+				ServiceName: "frontend",
+			}),
+		)
+		if err != nil {
+			log.Fatal(err)
+		}
+
+		// For demoing purposes, always sample. In a production application, you should
+		// configure this to a trace.ProbabilitySampler set at the desired
+		// probability.
+		tp, err := sdktrace.NewProvider(
+			sdktrace.WithConfig(sdktrace.Config{DefaultSampler: sdktrace.AlwaysSample()}),
+			sdktrace.WithSyncer(exporter))
+		if err != nil {
+			log.Fatal(err)
+		}
+		global.SetTraceProvider(tp)
+		defer exporter.Flush()
+	}
+
 	fmt.Printf("Item Host: %v\n", config.ItemHost)
 	fmt.Printf("Pay Host: %v\n", config.PayHost)
 	fmt.Printf("Discount Host: %v\n", config.DiscountHost)
@@ -39,9 +82,9 @@ func main() {
 	healthHandler.WithLogger(logger)

 	mux.Handle("/", fs)
-	mux.Handle("/api/items", getItemsHandler)
-	mux.Handle("/api/pay", payHandler)
-	mux.Handle("/health", healthHandler)
+	mux.Handle("/api/items", othttp.NewHandler(getItemsHandler, "http.GetItems"))
+	mux.Handle("/api/pay", othttp.NewHandler(payHandler, "http.Pay"))
+	mux.Handle("/health", othttp.NewHandler(healthHandler, "http.health"))

 	log.Println("Listening on port 3000...")
 	http.ListenAndServe(":3000", loggingMiddleware(httpdLogger.With(zap.String("from", "middleware")), mux))
--
2.23.0
```

\newpage

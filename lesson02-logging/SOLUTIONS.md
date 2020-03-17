## Solution Lesson 2 - Logging

## Item

```diff
commit ec86756af8544c8158636c43c27c1b0f10ed497c
Author: Gianluca Arbezzano <gianarb92@gmail.com>
Date:   Thu Mar 14 10:27:38 2019 +0100

    Injected logger to item service

    The item service is not logging using Monolog

diff --git a/items/Dockerfile b/items/Dockerfile
index 58a1e86..2184cb1 100644
--- a/items/Dockerfile
+++ b/items/Dockerfile
@@ -2,3 +2,8 @@ FROM php:7.2-apache

 RUN a2enmod rewrite
 RUN docker-php-ext-install pdo_mysql
+
+RUN find /etc/apache2/sites-enabled/* -exec sed -i 's/#*[Cc]ustom[Ll]og/#CustomLog/g' {} \;
+RUN find /etc/apache2/sites-enabled/* -exec sed -i 's/#*[Ee]rror[Ll]og/#ErrorLog/g' {} \;
+RUN a2disconf other-vhosts-access-log
+
diff --git a/items/composer.json b/items/composer.json
index 50bea51..c0badf9 100644
--- a/items/composer.json
+++ b/items/composer.json
@@ -46,7 +46,8 @@
         "zendframework/zend-expressive-fastroute": "^3.0",
         "zendframework/zend-expressive-helpers": "^5.0",
         "zendframework/zend-servicemanager": "^3.3",
-        "zendframework/zend-stdlib": "^3.1"
+        "zendframework/zend-stdlib": "^3.1",
+        "monolog/monolog": "1.24.0"
     },
     "require-dev": {
         "phpunit/phpunit": "^7.0.1",
diff --git a/items/config/autoload/containers.global.php b/items/config/autoload/containers.global.php
index 511480b..12a5b18 100644
--- a/items/config/autoload/containers.global.php
+++ b/items/config/autoload/containers.global.php
@@ -20,6 +20,8 @@ return [
             App\Service\ItemService::class => App\Service\ItemServiceFactory::class,
             App\Handler\Item::class => App\Handler\ItemFactory::class,
             App\Handler\Health::class => App\Handler\HealthFactory::class,
+            "Logger" => App\Service\LoggerFactory::class,
+            App\Middleware\LoggerMiddleware::class => App\Middleware\LoggerMiddlewareFactory::class,
         ],
     ],
 ];
diff --git a/items/config/pipeline.php b/items/config/pipeline.php
index cfe8f0b..e9287fd 100644
--- a/items/config/pipeline.php
+++ b/items/config/pipeline.php
@@ -14,11 +14,13 @@ use Zend\Expressive\Router\Middleware\ImplicitOptionsMiddleware;
 use Zend\Expressive\Router\Middleware\MethodNotAllowedMiddleware;
 use Zend\Expressive\Router\Middleware\RouteMiddleware;
 use Zend\Stratigility\Middleware\ErrorHandler;
+use App\Middleware\LoggerMiddleware;

 /**
  * Setup middleware pipeline:
  */
 return function (Application $app, MiddlewareFactory $factory, ContainerInterface $container) : void {
+    $app->pipe($container->get(LoggerMiddleware::class));
     // The error handler should be the first (most outer) middleware to catch
     // all Exceptions.
     $app->pipe(ErrorHandler::class);
diff --git a/items/src/App/src/Handler/Item.php b/items/src/App/src/Handler/Item.php
index 2ea3d66..f1d9a64 100644
--- a/items/src/App/src/Handler/Item.php
+++ b/items/src/App/src/Handler/Item.php
@@ -6,18 +6,28 @@ use Psr\Http\Message\ServerRequestInterface;
 use Psr\Http\Server\RequestHandlerInterface;
 use Zend\Diactoros\Response\JsonResponse;
 use App\Service\ItemService;
+use Monolog\Logger;
+use Monolog\Processor\TagProcessor;

 class Item implements RequestHandlerInterface
 {
     private $itemService;
+    private $logger;

     function __construct(ItemService $itemService) {
         $this->itemService = $itemService;
+        $this->logger = new Logger('item_service');
     }

     public function handle(ServerRequestInterface $request) : ResponseInterface
     {
+        $this->logger->info("Get list of items");
         $items = $this->itemService->list();
+        $this->logger->info("Retrived list of items", ["num_items" => count($items)]);
         return new JsonResponse(['items' => $items]);
     }
+
+    public function withLogger($logger) {
+        $this->logger = $logger;
+    }
 }
diff --git a/items/src/App/src/Handler/ItemFactory.php b/items/src/App/src/Handler/ItemFactory.php
index a1db1df..7de3a2d 100644
--- a/items/src/App/src/Handler/ItemFactory.php
+++ b/items/src/App/src/Handler/ItemFactory.php
@@ -9,6 +9,7 @@ class ItemFactory
 {
     public function __invoke(ContainerInterface $container)
     {
-        return new Item($container->get(ItemService::class));
+        $h = new Item($container->get(ItemService::class));
+        return $h;
     }
 }
diff --git a/items/src/App/src/Middleware/LoggerMiddleware.php b/items/src/App/src/Middleware/LoggerMiddleware.php
new file mode 100644
index 0000000..64538c1
--- /dev/null
+++ b/items/src/App/src/Middleware/LoggerMiddleware.php
@@ -0,0 +1,54 @@
+<?php
+namespace App\Middleware;
+
+use ErrorException;
+use Psr\Http\Message\ResponseInterface;
+use Psr\Http\Message\ServerRequestInterface;
+use Psr\Http\Server\MiddlewareInterface;
+use Psr\Http\Server\RequestHandlerInterface;
+use Monolog\Processor\TagProcessor;
+
+class LoggerMiddleware implements MiddlewareInterface
+{
+    private $logger;
+
+    public function __construct($logger)
+    {
+        $this->logger = $logger;
+        $this->logger->pushProcessor(new TagProcessor([
+            "service" => "logger_middleware",
+        ]));
+    }
+
+    public function process(ServerRequestInterface $request, RequestHandlerInterface $handler) : ResponseInterface
+    {
+        $isGood = true;
+        try {
+            $response = $handler->handle($request);
+        } catch (Throwable $e) {
+            $this->logger->panic("HTTP Server", [
+                "path", $request->getUri()->getPath(),
+                "method", $request->getMethod(),
+                "status_code" => $response->getStatusCode(),
+                "error" => $e->getMessage(),
+            ]);
+            $isGood=false;
+        }
+        if ($isGood) {
+            if ($response->getStatusCode() >= 200 && $response->getStatusCode() <= 299) {
+                $this->logger->info("HTTP Server", [
+                    "path", $request->getUri()->getPath(),
+                    "method", $request->getMethod(),
+                    "status_code" => $response->getStatusCode(),
+                ]);
+            } else {
+                $this->logger->warn("HTTP Server", [
+                    "path", $request->getUri()->getPath(),
+                    "method", $request->getMethod(),
+                    "status_code" => $response->getStatusCode(),
+                ]);
+            }
+        }
+        return $response;
+    }
+}
diff --git a/items/src/App/src/Middleware/LoggerMiddlewareFactory.php b/items/src/App/src/Middleware/LoggerMiddlewareFactory.php
new file mode 100644
index 0000000..bd4fba9
--- /dev/null
+++ b/items/src/App/src/Middleware/LoggerMiddlewareFactory.php
@@ -0,0 +1,20 @@
+<?php
+namespace App\Middleware;
+
+use Psr\Container\ContainerInterface;
+use ErrorException;
+use Psr\Http\Message\ResponseInterface;
+use Psr\Http\Message\ServerRequestInterface;
+use Psr\Http\Server\MiddlewareInterface;
+use Psr\Http\Server\RequestHandlerInterface;
+use Monolog\Processor\TagProcessor;
+
+class LoggerMiddlewareFactory
+{
+    private $logger;
+
+    public function __invoke(ContainerInterface $container) {
+        $logger = $container->get("Logger");
+        return new LoggerMiddleware($logger);
+    }
+}
diff --git a/items/src/App/src/Service/LoggerFactory.php b/items/src/App/src/Service/LoggerFactory.php
new file mode 100644
index 0000000..cc60ae0
--- /dev/null
+++ b/items/src/App/src/Service/LoggerFactory.php
@@ -0,0 +1,20 @@
+<?php
+namespace App\Service;
+
+use Psr\Container\ContainerInterface;
+use Monolog\Logger;
+use Monolog\Handler\StreamHandler;
+use Monolog\Formatter\JsonFormatter;
+
+class LoggerFactory
+{
+    public function __invoke(ContainerInterface $container)
+    {
+        $logger = new Logger("items");
+        $handler = new StreamHandler('php://stdout');
+        $handler->setFormatter(new JsonFormatter());
+        $logger->pushHandler($handler);
+        return $logger;
+    }
+}
+
```

## Discount

```diff
commit cbc91b1d15b0564c89cb825b9540d309f90526eb
Author: Gianluca Arbezzano <gianarb92@gmail.com>
Date:   Sun Mar 17 19:20:10 2019 +0100

    Added logging support to discount service

    Signed-off-by: Gianluca Arbezzano <gianarb92@gmail.com>

diff --git a/discount/package.json b/discount/package.json
index 0647009..1640ae1 100644
--- a/discount/package.json
+++ b/discount/package.json
@@ -11,6 +11,7 @@
   "license": "ISC",
   "dependencies": {
     "express": "^4.16.4",
+    "express-pino-logger": "^4.0.0",
     "mongodb": "^3.1.13"
   }
 }
diff --git a/discount/server.js b/discount/server.js
index cedde93..50a32a9 100644
--- a/discount/server.js
+++ b/discount/server.js
@@ -8,6 +8,12 @@ const dbName = 'shopmany';
 const client = new MongoClient(url, { useNewUrlParser: true });
 app.use(errorHandler)

+const logger = require('pino')()
+const expressPino = require('express-pino-logger')({
+  logger: logger.child({"service": "httpd"})
+})
+app.use(expressPino)
+
 app.get("/health", function(req, res, next) {
   var resbody = {
     "status": "healthy",
@@ -21,6 +27,7 @@ app.get("/health", function(req, res, next) {
       "status": "healthy",
     };
     if (err != null) {
+      req.log.warn(err.toString());
       mongoCheck.error = err.toString();
       mongoCheck.status = "unhealthy";
       resbody.status = "unhealthy"
@@ -36,6 +43,7 @@ app.get("/discount", function(req, res, next) {
     db = client.db(dbName);
     db.collection('discount').find({}).toArray(function(err, discounts) {
       if (err != null) {
+        req.log.error(err.toString());
         return next(err)
       }
       var goodDiscount = null
@@ -47,6 +55,7 @@ app.get("/discount", function(req, res, next) {
       if (goodDiscount != null) {
         res.json({"discount": goodDiscount})
       } else {
+        req.log.warn("discount not found");
         res.status(404).json({ error: 'Discount not found' });
       }
       return
@@ -55,10 +64,14 @@ app.get("/discount", function(req, res, next) {
 });

 app.use(function(req, res, next) {
+  req.log.warn("route not found");
   return res.status(404).json({error: "route not found"});
 });

 function errorHandler(err, req, res, next) {
+  req.log.error(err.toString(), {
+    error_status: err.status
+  });
   var st = err.status
   if (st == 0 || st == null) {
     st = 500;
@@ -68,5 +81,5 @@ function errorHandler(err, req, res, next) {
 }

 app.listen(3000, () => {
-  console.log("Server running on port 3000");
+  logger.info("Server running on port 3000");
 });
```
## Pay

```diff
commit 0376a283dc843f7beee207b4201b0b57b7cb00ff
Author: Gianluca Arbezzano <gianarb92@gmail.com>
Date:   Sat Mar 23 16:09:13 2019 +0100

    Added log4j2 to pay svc

    Co-Authored-by: Walter Dal Mut  <walter.dalmut@gmail.com>
    Signed-off-by: Gianluca Arbezzano <gianarb92@gmail.com>

diff --git a/pay/build.gradle b/pay/build.gradle
index a8e253c..50bb905 100644
--- a/pay/build.gradle
+++ b/pay/build.gradle
@@ -26,9 +26,18 @@ sourceCompatibility = 1.8
 targetCompatibility = 1.8

 dependencies {
-    compile("org.springframework.boot:spring-boot-starter-web")
     compile("org.springframework.boot:spring-boot-starter-data-jpa")
     //compile("com.h2database:h2")
     compile 'mysql:mysql-connector-java'
+    compile("com.fasterxml.jackson.core:jackson-databind")
+    compile("org.springframework.boot:spring-boot-starter-web"){ exclude group: 'org.springframework.boot', module: 'spring-boot-starter-logging'}
+    compile('org.springframework.boot:spring-boot-starter-log4j2')
     testCompile('org.springframework.boot:spring-boot-starter-test')
 }
+
+
+configurations {
+    all {
+        exclude group: 'org.springframework.boot', module: 'spring-boot-starter-logging'
+    }
+}
diff --git a/pay/src/main/java/pay/AppConfig.java b/pay/src/main/java/pay/AppConfig.java
new file mode 100644
index 0000000..bb788cb
--- /dev/null
+++ b/pay/src/main/java/pay/AppConfig.java
@@ -0,0 +1,14 @@
+package pay;
+
+import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
+import org.springframework.web.servlet.config.annotation.WebMvcConfigurerAdapter;
+import org.springframework.stereotype.Component;
+
+@Component
+public class AppConfig extends WebMvcConfigurerAdapter  {
+
+    @Override
+    public void addInterceptors(InterceptorRegistry registry) {
+       registry.addInterceptor(new LoggerInterceptor());
+    }
+}
diff --git a/pay/src/main/java/pay/Application.java b/pay/src/main/java/pay/Application.java
index ef1194a..1d8d39d 100644
--- a/pay/src/main/java/pay/Application.java
+++ b/pay/src/main/java/pay/Application.java
@@ -5,10 +5,13 @@ import org.springframework.boot.autoconfigure.SpringBootApplication;
 import org.springframework.http.ResponseEntity;
 import org.springframework.web.bind.annotation.*;
 import javax.servlet.http.HttpServletResponse;
+import org.slf4j.Logger;
+import org.slf4j.LoggerFactory;

 @SpringBootApplication
 @RestController
 public class Application {
+    private static final Logger logger = LoggerFactory.getLogger(Application.class);
     private PayRepository payRepository;

     public Application(PayRepository payRepository) {
@@ -40,6 +43,7 @@ public class Application {
             status = "healthy";
             mysqlC.setStatus("healthy");
         } catch (Exception e) {
+            logger.error("Mysql healthcheck failed", e.getMessage());
             mysqlC.setStatus("unhealthy");
             mysqlC.setError(e.getMessage());
             response.setStatus(500);
diff --git a/pay/src/main/java/pay/LoggerInterceptor.java b/pay/src/main/java/pay/LoggerInterceptor.java
new file mode 100644
index 0000000..654229f
--- /dev/null
+++ b/pay/src/main/java/pay/LoggerInterceptor.java
@@ -0,0 +1,39 @@
+package pay;
+
+import org.springframework.stereotype.Component;
+import org.springframework.web.servlet.handler.HandlerInterceptorAdapter;
+import javax.servlet.http.HttpServletRequest;
+import javax.servlet.http.HttpServletResponse;
+import org.slf4j.Logger;
+import org.slf4j.LoggerFactory;
+
+@Component
+public class LoggerInterceptor
+  extends HandlerInterceptorAdapter {
+    private static final Logger logger = LoggerFactory.getLogger(Application.class);
+
+    @Override
+    public boolean preHandle(
+      HttpServletRequest request,
+      HttpServletResponse response,
+      Object handler) {
+        long startTime = System.currentTimeMillis();
+        logger.info("[Start HTTP Request]: Path" + request.getRequestURL().toString()
+				+ " StartTime=" + startTime);
+        request.setAttribute("startTime", startTime);
+
+        return true;
+    }
+
+    @Override
+    public void afterCompletion(
+      HttpServletRequest request,
+      HttpServletResponse response,
+      Object handler,
+      Exception ex) {
+        long startTime = (Long) request.getAttribute("startTime");
+        logger.info("[End HTTP Request]: Path" + request.getRequestURL().toString()
+				+ " EndTime=" + System.currentTimeMillis()
+                + " TimeTaken="+ (System.currentTimeMillis() - startTime));
+    }
+}
diff --git a/pay/src/main/resources/log4j2.xml b/pay/src/main/resources/log4j2.xml
new file mode 100644
index 0000000..7403409
--- /dev/null
+++ b/pay/src/main/resources/log4j2.xml
@@ -0,0 +1,16 @@
+<?xml version="1.0" encoding="UTF-8"?>
+<Configuration status="WARN" monitorInterval="30">
+    <Appenders>
+        <Console name="ConsoleJSONAppender" target="SYSTEM_OUT">
+            <JsonLayout complete="false" compact="false">
+                <KeyValuePair key="service" value="pay" />
+            </JsonLayout>
+        </Console>
+    </Appenders>
+
+    <Loggers>
+        <Root level="info">
+            <AppenderRef ref="ConsoleJSONAppender"/>
+        </Root>
+    </Loggers>
+</Configuration>
```

## Frontend

```diff
commit 32ca854035f78ab65f1ebb7b2d9c750f6670aaa1
Author: Gianluca Arbezzano <gianarb92@gmail.com>
Date:   Thu Mar 14 19:17:55 2019 +0100

    Added logging to frontend

    Signed-off-by: Gianluca Arbezzano <gianarb92@gmail.com>

diff --git a/frontend/handler/getitems.go b/frontend/handler/getitems.go
index 5019d55..54a3d32 100644
--- a/frontend/handler/getitems.go
+++ b/frontend/handler/getitems.go
@@ -9,6 +9,7 @@ import (
 	"strconv"

 	"github.com/gianarb/shopmany/frontend/config"
+	"go.uber.org/zap"
 )

 type ItemsResponse struct {
@@ -62,27 +63,41 @@ func getDiscountPerItem(ctx context.Context, hclient *http.Client, itemID int, d
 type getItemsHandler struct {
 	config  config.Config
 	hclient *http.Client
+	logger  *zap.Logger
 }

 func NewGetItemsHandler(config config.Config, hclient *http.Client) *getItemsHandler {
+	logger, _ := zap.NewProduction()
 	return &getItemsHandler{
 		config:  config,
 		hclient: hclient,
+		logger:  logger,
 	}
 }

+func (h *getItemsHandler) WithLogger(logger *zap.Logger) {
+	h.logger = logger
+}
+
 func (h *getItemsHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
 	ctx := r.Context()
 	w.Header().Add("Content-Type", "application/json")
 	req, err := http.NewRequest("GET", fmt.Sprintf("%s/item", h.config.ItemHost), nil)
 	if err != nil {
+		h.logger.Error(err.Error())
 		http.Error(w, err.Error(), 500)
 		return
 	}
 	resp, err := h.hclient.Do(req)
+	if err != nil {
+		h.logger.Error(err.Error())
+		http.Error(w, err.Error(), 500)
+		return
+	}
 	defer resp.Body.Close()
 	body, err := ioutil.ReadAll(resp.Body)
 	if err != nil {
+		h.logger.Error(err.Error())
 		http.Error(w, err.Error(), 500)
 		return
 	}
@@ -91,6 +106,7 @@ func (h *getItemsHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
 	}
 	err = json.Unmarshal(body, &items)
 	if err != nil {
+		h.logger.Error(err.Error())
 		http.Error(w, err.Error(), 500)
 		return
 	}
@@ -98,6 +114,7 @@ func (h *getItemsHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
 	for k, item := range items.Items {
 		d, err := getDiscountPerItem(ctx, h.hclient, item.ID, h.config.DiscountHost)
 		if err != nil {
+			h.logger.Error(err.Error())
 			http.Error(w, err.Error(), 500)
 			continue
 		}
@@ -106,6 +123,7 @@ func (h *getItemsHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {

 	b, err := json.Marshal(items)
 	if err != nil {
+		h.logger.Error(err.Error())
 		http.Error(w, err.Error(), 500)
 		return
 	}
diff --git a/frontend/handler/health.go b/frontend/handler/health.go
index 733d28f..fa9e52f 100644
--- a/frontend/handler/health.go
+++ b/frontend/handler/health.go
@@ -7,6 +7,7 @@ import (
 	"net/http"

 	"github.com/gianarb/shopmany/frontend/config"
+	"go.uber.org/zap"
 )

 const unhealthy = "unhealty"
@@ -24,15 +25,22 @@ type check struct {
 }

 func NewHealthHandler(config config.Config, hclient *http.Client) *healthHandler {
+	logger, _ := zap.NewProduction()
 	return &healthHandler{
 		config:  config,
 		hclient: hclient,
+		logger:  logger,
 	}
 }

 type healthHandler struct {
 	config  config.Config
 	hclient *http.Client
+	logger  *zap.Logger
+}
+
+func (h *healthHandler) WithLogger(logger *zap.Logger) {
+	h.logger = logger
 }

 func (h *healthHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
@@ -51,6 +59,7 @@ func (h *healthHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {

 	body, err := json.Marshal(b)
 	if err != nil {
+		h.logger.Error(err.Error())
 		w.WriteHeader(500)
 	}
 	if b.Status == unhealthy {
diff --git a/frontend/handler/pay.go b/frontend/handler/pay.go
index b3a8a24..f3e5434 100644
--- a/frontend/handler/pay.go
+++ b/frontend/handler/pay.go
@@ -5,20 +5,28 @@ import (
 	"net/http"

 	"github.com/gianarb/shopmany/frontend/config"
+	"go.uber.org/zap"
 )

 type payHandler struct {
 	config  config.Config
 	hclient *http.Client
+	logger  *zap.Logger
 }

 func NewPayHandler(config config.Config, hclient *http.Client) *payHandler {
+	logger, _ := zap.NewProduction()
 	return &payHandler{
 		config:  config,
 		hclient: hclient,
+		logger:  logger,
 	}
 }

+func (h *payHandler) WithLogger(logger *zap.Logger) {
+	h.logger = logger
+}
+
 func (h *payHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
 	w.Header().Add("Content-Type", "application/json")
 	if r.Method != "POST" {
diff --git a/frontend/main.go b/frontend/main.go
index ee16adc..35a084c 100644
--- a/frontend/main.go
+++ b/frontend/main.go
@@ -8,9 +8,12 @@ import (
 	"github.com/gianarb/shopmany/frontend/config"
 	"github.com/gianarb/shopmany/frontend/handler"
 	flags "github.com/jessevdk/go-flags"
+	"go.uber.org/zap"
 )

 func main() {
+	logger, _ := zap.NewProduction()
+	defer logger.Sync()
 	config := config.Config{}
 	_, err := flags.Parse(&config)

@@ -22,14 +25,35 @@ func main() {
 	fmt.Printf("Pay Host: %v\n", config.PayHost)
 	fmt.Printf("Discount Host: %v\n", config.DiscountHost)

+	mux := http.NewServeMux()
+
 	httpClient := &http.Client{}
 	fs := http.FileServer(http.Dir("static"))

-	http.Handle("/", fs)
-	http.Handle("/api/items", handler.NewGetItemsHandler(config, httpClient))
-	http.Handle("/api/pay", handler.NewPayHandler(config, httpClient))
-	http.Handle("/health", handler.NewHealthHandler(config, httpClient))
+	httpdLogger := logger.With(zap.String("service", "httpd"))
+	getItemsHandler := handler.NewGetItemsHandler(config, httpClient)
+	getItemsHandler.WithLogger(logger)
+	payHandler := handler.NewPayHandler(config, httpClient)
+	payHandler.WithLogger(logger)
+	healthHandler := handler.NewHealthHandler(config, httpClient)
+	healthHandler.WithLogger(logger)
+
+	mux.Handle("/", fs)
+	mux.Handle("/api/items", getItemsHandler)
+	mux.Handle("/api/pay", payHandler)
+	mux.Handle("/health", healthHandler)

 	log.Println("Listening on port 3000...")
-	http.ListenAndServe(":3000", nil)
+	http.ListenAndServe(":3000", loggingMiddleware(httpdLogger.With(zap.String("from", "middleware")), mux))
+}
+
+func loggingMiddleware(logger *zap.Logger, h http.Handler) http.Handler {
+	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
+		logger.Info(
+			"HTTP Request",
+			zap.String("Path", r.URL.Path),
+			zap.String("Method", r.Method),
+			zap.String("RemoteAddr", r.RemoteAddr))
+		h.ServeHTTP(w, r)
+	})
 }
```

\newpage

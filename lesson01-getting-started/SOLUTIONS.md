# Solution Lesson 1 - Healtcheck

## Item

```diff
commit 47a089f9b0f9fa08415c8a0d7f92f0f1a291a747
Author: Gianluca Arbezzano <gianarb92@gmail.com>
Date:   Thu Mar 14 09:40:16 2019 +0100

    Added healthcherck endpoint

    Signed-off-by: Gianluca Arbezzano <gianarb92@gmail.com>

diff --git a/items/config/autoload/containers.global.php b/items/config/autoload/containers.global.php
index 3166620..511480b 100644
--- a/items/config/autoload/containers.global.php
+++ b/items/config/autoload/containers.global.php
@@ -14,12 +14,12 @@ return [
         // not require arguments to the constructor. Map a service name to the
         // class name.
         'invokables' => [
-            // Fully\Qualified\InterfaceName::class => Fully\Qualified\ClassName::class,
         ],
         // Use 'factories' for services provided by callbacks/factory classes.
         'factories'  => [
             App\Service\ItemService::class => App\Service\ItemServiceFactory::class,
             App\Handler\Item::class => App\Handler\ItemFactory::class,
+            App\Handler\Health::class => App\Handler\HealthFactory::class,
         ],
     ],
 ];
diff --git a/items/config/routes.php b/items/config/routes.php
index fc0abb7..e37ed12 100644
--- a/items/config/routes.php
+++ b/items/config/routes.php
@@ -6,6 +6,7 @@ use Psr\Container\ContainerInterface;
 use Zend\Expressive\Application;
 use Zend\Expressive\MiddlewareFactory;
 use App\Handler\Item;
+use App\Handler\Health;

 /**
  * Setup routes with a single request method:
@@ -22,4 +23,5 @@ use App\Handler\Item;
  */
 return function (Application $app, MiddlewareFactory $factory, ContainerInterface $container) : void {
     $app->get('/item', Item::class);
+    $app->get('/health', Health::class);
 };
diff --git a/items/src/App/src/Handler/Health.php b/items/src/App/src/Handler/Health.php
new file mode 100644
index 0000000..47c210e
--- /dev/null
+++ b/items/src/App/src/Handler/Health.php
@@ -0,0 +1,49 @@
+<?php
+
+namespace App\Handler;
+use Psr\Http\Message\ResponseInterface;
+use Psr\Http\Message\ServerRequestInterface;
+use Psr\Http\Server\RequestHandlerInterface;
+use Zend\Diactoros\Response\JsonResponse;
+use App\Service\ItemService;
+use \PDO;
+
+class Health implements RequestHandlerInterface
+{
+
+    public function __construct($hostname, $username, $password, $dbname) {
+        $this->username = $username;
+        $this->hostname = $hostname;
+        $this->password = $password;
+        $this->dbname = $dbname;
+    }
+
+    public function handle(ServerRequestInterface $request) : ResponseInterface
+    {
+        $statusCode = 500;
+        $body = new \stdClass();
+        $body->status = "unhealthy";
+        $mySqlCheck = new \stdClass();
+        $mySqlCheck->name = "mysql";
+        $mySqlCheck->status = "unhealthy";
+
+        try {
+            $this->pdo = new PDO("mysql:host=$this->hostname;port=3306;dbname=$this->dbname", $this->username, $this->password);
+            $this->pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
+            $this->pdo->setAttribute(PDO::ATTR_EMULATE_PREPARES, false);
+
+            $statusCode = 200;
+            $body->status = "healthy";
+            $mySqlCheck->status = "healthy";
+
+        } catch(\PDOException $ex){
+            $mySqlCheck->error = $ex->getMessage();
+        }
+        $body->checks = [$mySqlCheck];
+
+        $response = new JsonResponse($body);
+        $response = $response->withStatus($statusCode);
+
+        return $response;
+    }
+}
diff --git a/items/src/App/src/Handler/HealthFactory.php b/items/src/App/src/Handler/HealthFactory.php
new file mode 100644
index 0000000..e974128
--- /dev/null
+++ b/items/src/App/src/Handler/HealthFactory.php
@@ -0,0 +1,14 @@
+<?php
+namespace App\Handler;
+
+use Psr\Container\ContainerInterface;
+use Zend\Expressive\Template\TemplateRendererInterface;
+
+class HealthFactory
+{
+    public function __invoke(ContainerInterface $container)
+    {
+        $mysqlConfig = $container->get('config')['mysql'];
+        return new Health($mysqlConfig['hostname'], $mysqlConfig['user'], $mysqlConfig['pass'], $mysqlConfig['dbname']);
+    }
+}
```

## Discount

```diff
commit 6eece7c468462dbeb5da24e6b4432d9853f0ecb8
Author: Gianluca Arbezzano <gianarb92@gmail.com>
Date:   Sun Mar 17 11:27:17 2019 +0100

    Added healthcheck to discount service

    Now the discount service has its own healthcheck endpoint.

    ```
    METHOD: GET
    PATH: /health
    ```

    It checks if th mongodb is reachable or not.

    Signed-off-by: Gianluca Arbezzano <gianarb92@gmail.com>

diff --git a/discount/server.js b/discount/server.js
index a7cb17b..cedde93 100644
--- a/discount/server.js
+++ b/discount/server.js
@@ -8,6 +8,28 @@ const dbName = 'shopmany';
 const client = new MongoClient(url, { useNewUrlParser: true });
 app.use(errorHandler)

+app.get("/health", function(req, res, next) {
+  var resbody = {
+    "status": "healthy",
+    checks: [],
+  };
+  var resCode = 200;
+
+  client.connect(function(err) {
+    var mongoCheck = {
+      "name": "mongo",
+      "status": "healthy",
+    };
+    if (err != null) {
+      mongoCheck.error = err.toString();
+      mongoCheck.status = "unhealthy";
+      resbody.status = "unhealthy"
+      resCode = 500;
+    }
+    resbody.checks.push(mongoCheck);
+    res.status(resCode).json(resbody)
+  });
+});

 app.get("/discount", function(req, res, next) {
   client.connect(function(err) {
```

## Pay

```diff
commit 123dfdc67d1fe0725de1d88f4a4173e6705b4639
Author: Gianluca Arbezzano <gianarb92@gmail.com>
Date:   Sat Mar 23 15:48:10 2019 +0100

    Added healthcheck for pay service

    Signed-off-by: Gianluca Arbezzano <gianarb92@gmail.com>

diff --git a/pay/src/main/java/pay/Application.java b/pay/src/main/java/pay/Application.java
index c66e0c0..ef1194a 100644
--- a/pay/src/main/java/pay/Application.java
+++ b/pay/src/main/java/pay/Application.java
@@ -4,11 +4,11 @@ import org.springframework.boot.SpringApplication;
 import org.springframework.boot.autoconfigure.SpringBootApplication;
 import org.springframework.http.ResponseEntity;
 import org.springframework.web.bind.annotation.*;
+import javax.servlet.http.HttpServletResponse;

 @SpringBootApplication
 @RestController
 public class Application {
-
     private PayRepository payRepository;

     public Application(PayRepository payRepository) {
@@ -27,6 +27,27 @@ public class Application {
         return ResponseEntity.ok("Success");
     }

+    @GetMapping("/health")
+    @ResponseBody
+    public HealthResponse health(HttpServletResponse response) {
+        HealthResponse h = new HealthResponse();
+        String status = "unhealthy";
+
+        HealthCheck mysqlC = new HealthCheck();
+        mysqlC.setName("mysql");
+        try {
+            payRepository.count();
+            status = "healthy";
+            mysqlC.setStatus("healthy");
+        } catch (Exception e) {
+            mysqlC.setStatus("unhealthy");
+            mysqlC.setError(e.getMessage());
+            response.setStatus(500);
+        }
+        h.setStatus(status);
+        h.addHealthCheck(mysqlC);
+        return h;
+    }

     public static void main(String[] args) {
         SpringApplication.run(Application.class, args);
diff --git a/pay/src/main/java/pay/HealthCheck.java b/pay/src/main/java/pay/HealthCheck.java
new file mode 100644
index 0000000..b3b7723
--- /dev/null
+++ b/pay/src/main/java/pay/HealthCheck.java
@@ -0,0 +1,31 @@
+package pay;
+
+public class HealthCheck {
+    private String status;
+    private String name;
+    private String error;
+
+    public String getStatus() {
+        return status;
+    }
+
+    public void setStatus(String status) {
+        this.status = status;
+    }
+
+    public String getName() {
+        return name;
+    }
+
+    public void setName(String name) {
+        this.name = name;
+    }
+
+    public String getError() {
+        return error;
+    }
+
+    public void setError(String error) {
+        this.error = error;
+    }
+}
diff --git a/pay/src/main/java/pay/HealthResponse.java b/pay/src/main/java/pay/HealthResponse.java
new file mode 100644
index 0000000..8431f53
--- /dev/null
+++ b/pay/src/main/java/pay/HealthResponse.java
@@ -0,0 +1,29 @@
+package pay;
+
+import java.util.*;
+
+public class HealthResponse {
+    private String status;
+
+    private List<HealthCheck> checks;
+
+    public HealthResponse () {
+        this.checks = new ArrayList<HealthCheck>();
+    }
+
+    public String getStatus() {
+        return status;
+    }
+
+    public void setStatus(String status) {
+        this.status = status;
+    }
+
+    public void addHealthCheck(HealthCheck h) {
+        this.checks.add(h);
+    }
+
+    public List<HealthCheck> getChecks() {
+        return checks;
+    }
+}
```

# Frontend

```diff
commit cbc932799735f55aa4c7c15aa4718e0206ab6f9d
Author: Gianluca Arbezzano <gianarb92@gmail.com>
Date:   Thu Mar 14 18:34:17 2019 +0100

    Added healthcheck endpoint to the frontend svc

    Now the frontend service has its healthcheck to validate if service that
    returns the list of items is working.

    Signed-off-by: Gianluca Arbezzano <gianarb92@gmail.com>

diff --git a/frontend/handler/health.go b/frontend/handler/health.go
new file mode 100644
index 0000000..733d28f
--- /dev/null
+++ b/frontend/handler/health.go
@@ -0,0 +1,87 @@
+package handler
+
+import (
+	"encoding/json"
+	"fmt"
+	"io/ioutil"
+	"net/http"
+
+	"github.com/gianarb/shopmany/frontend/config"
+)
+
+const unhealthy = "unhealty"
+const healthy = "healthy"
+
+type healthResponse struct {
+	Status string
+	Checks []check
+}
+
+type check struct {
+	Error  string
+	Status string
+	Name   string
+}
+
+func NewHealthHandler(config config.Config, hclient *http.Client) *healthHandler {
+	return &healthHandler{
+		config:  config,
+		hclient: hclient,
+	}
+}
+
+type healthHandler struct {
+	config  config.Config
+	hclient *http.Client
+}
+
+func (h *healthHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
+	b := healthResponse{
+		Status: unhealthy,
+		Checks: []check{},
+	}
+	w.Header().Add("Content-Type", "application/json")
+
+	itemCheck := checkItem(h.config.ItemHost, h.hclient)
+	if itemCheck.Status == healthy {
+		b.Status = healthy
+	}
+
+	b.Checks = append(b.Checks, itemCheck)
+
+	body, err := json.Marshal(b)
+	if err != nil {
+		w.WriteHeader(500)
+	}
+	if b.Status == unhealthy {
+		w.WriteHeader(500)
+	}
+	fmt.Fprintf(w, string(body))
+}
+
+func checkItem(host string, hclient *http.Client) check {
+	c := check{
+		Name:   "item",
+		Error:  "",
+		Status: unhealthy,
+	}
+	req, _ := http.NewRequest("GET", fmt.Sprintf("%s/health", host), nil)
+	resp, err := hclient.Do(req)
+	if err != nil {
+		c.Error = err.Error()
+		return c
+	}
+	defer resp.Body.Close()
+	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
+		c.Status = healthy
+		return c
+	}
+	b, err := ioutil.ReadAll(resp.Body)
+	if err != nil {
+		c.Error = err.Error()
+		return c
+	}
+	c.Error = string(b)
+
+	return c
+}
diff --git a/frontend/main.go b/frontend/main.go
index f78d524..ee16adc 100644
--- a/frontend/main.go
+++ b/frontend/main.go
@@ -28,6 +28,7 @@ func main() {
 	http.Handle("/", fs)
 	http.Handle("/api/items", handler.NewGetItemsHandler(config, httpClient))
 	http.Handle("/api/pay", handler.NewPayHandler(config, httpClient))
+	http.Handle("/health", handler.NewHealthHandler(config, httpClient))

 	log.Println("Listening on port 3000...")
 	http.ListenAndServe(":3000", nil)
```

\newpage

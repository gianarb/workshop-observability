# Monitoring stack with InfluxDB

## Lesson 3

As you saw along the course today there are a lot of tools that you can use to
build a monitoring infrastructure. You also know that it has to stay up when the
system is down. So it is not an easy job and that's why there are vendors and as
a service platform outside or inside cloud provider.

There are a good amount of open source tools that you can use. This is a select
pipeline that uses what provided by InfluxData the startup behind a popular time
series database called InfluxDB.

We are using InfluxDB v2, it is currently in Beta but well tested in its as a
service distribution called InfluxCloud.

With this lesson will familiarize with InfluxDB and its capabilities, precisely:


## Exercise: Familiarize with InfluxDB v2

**Time: 30minutes**

1. We will spin it up with the command:

```
$ docker-compose up -d influxdb
```

At this point you can follow [Getting Started with
InfluxDB](https://v2.docs.influxdata.com/v2.0/get-started/#set-up-influxdb)

When following the steps be sure to use the right informations:

* Enter a Username for your initial user.
* Enter a Password and Confirm Password for your user.
* Enter `workshop` as Organization Name.
* Enter `workshop` as your initial Bucket Name.  Click Continue.

2. [Create a token in the
   UI](https://v2.docs.influxdata.com/v2.0/security/tokens/create-token/)

### Start the Telegraf collector

Copy the token and paste it in: `./telegraf/telegraf.conf`

```
[[outputs.influxdb_v2]]
  urls = ["http://influxdb:9999"]
  token = "mOtZOovg_o7CNpB68pex5O5NheWSjsLEDWPXUFlJXqqYnycJMKJxJnmFAbfmwRnOJ2bRPAgY-VdFWhPeqH8hCg=="
  organization = "workshop"
  bucket = "workshop"
```

Start Telegraf via:

```bash
$ docker-compose up -d telegraf
```

Get back to the UI and you can [create a dashboard from the system
template](https://v2.docs.influxdata.com/v2.0/visualize-data/dashboards/create-dashboard/#create-dashboards-with-templates)
to visualize your data.


## Exercise: Configure Telegraf to use the healthcheck from our apps

**Time: 20minutes**

We coded an healthcheck for our application. This is a first useful signal to
understand if the applications are running or not.  Telegraf has a plugin called
`inputs.http_response` that can be used to ping and validate an HTTP endpoint.

Create a dashboard that uses these new metrics to tell you the status code
returned by the health check.


## Exercise: Import a dashboard that shows service availability

**Time: 10minutes**

This is the code to import:

```
{
 "meta": {
  "version": "1",
  "type": "dashboard",
  "name": "Service control room-Template",
  "description": "template created from dashboard: Service control room"
 },
 "content": {
  "data": {
   "type": "dashboard",
   "attributes": {
    "name": "Service control room",
    "description": ""
   },
   "relationships": {
    "label": {
     "data": []
    },
    "cell": {
     "data": [
      {
       "type": "cell",
       "id": "05663f2fd829f000"
      },
      {
       "type": "cell",
       "id": "0566404c0b69f000"
      },
      {
       "type": "cell",
       "id": "056640729b29f000"
      },
      {
       "type": "cell",
       "id": "0566408f8829f000"
      },
      {
       "type": "cell",
       "id": "056641b970a9f000"
      },
      {
       "type": "cell",
       "id": "0566472d9869f000"
      },
      {
       "type": "cell",
       "id": "0566473b7369f000"
      },
      {
       "type": "cell",
       "id": "05664807e4e9f000"
      },
      {
       "type": "cell",
       "id": "05664821c6e9f000"
      }
     ]
    },
    "variable": {
     "data": [
      {
       "type": "variable",
       "id": "05663a9e2be9f000"
      }
     ]
    }
   }
  },
  "included": [
   {
    "id": "05663f2fd829f000",
    "type": "cell",
    "attributes": {
     "x": 0,
     "y": 1,
     "w": 2,
     "h": 2
    },
    "relationships": {
     "view": {
      "data": {
       "type": "view",
       "id": "05663f2fd829f000"
      }
     }
    }
   },
   {
    "id": "0566404c0b69f000",
    "type": "cell",
    "attributes": {
     "x": 0,
     "y": 5,
     "w": 2,
     "h": 2
    },
    "relationships": {
     "view": {
      "data": {
       "type": "view",
       "id": "0566404c0b69f000"
      }
     }
    }
   },
   {
    "id": "056640729b29f000",
    "type": "cell",
    "attributes": {
     "x": 0,
     "y": 7,
     "w": 2,
     "h": 2
    },
    "relationships": {
     "view": {
      "data": {
       "type": "view",
       "id": "056640729b29f000"
      }
     }
    }
   },
   {
    "id": "0566408f8829f000",
    "type": "cell",
    "attributes": {
     "x": 0,
     "y": 3,
     "w": 2,
     "h": 2
    },
    "relationships": {
     "view": {
      "data": {
       "type": "view",
       "id": "0566408f8829f000"
      }
     }
    }
   },
   {
    "id": "056641b970a9f000",
    "type": "cell",
    "attributes": {
     "x": 0,
     "y": 0,
     "w": 5,
     "h": 1
    },
    "relationships": {
     "view": {
      "data": {
       "type": "view",
       "id": "056641b970a9f000"
      }
     }
    }
   },
   {
    "id": "0566472d9869f000",
    "type": "cell",
    "attributes": {
     "x": 2,
     "y": 1,
     "w": 6,
     "h": 2
    },
    "relationships": {
     "view": {
      "data": {
       "type": "view",
       "id": "0566472d9869f000"
      }
     }
    }
   },
   {
    "id": "0566473b7369f000",
    "type": "cell",
    "attributes": {
     "x": 2,
     "y": 3,
     "w": 6,
     "h": 2
    },
    "relationships": {
     "view": {
      "data": {
       "type": "view",
       "id": "0566473b7369f000"
      }
     }
    }
   },
   {
    "id": "05664807e4e9f000",
    "type": "cell",
    "attributes": {
     "x": 2,
     "y": 7,
     "w": 6,
     "h": 2
    },
    "relationships": {
     "view": {
      "data": {
       "type": "view",
       "id": "05664807e4e9f000"
      }
     }
    }
   },
   {
    "id": "05664821c6e9f000",
    "type": "cell",
    "attributes": {
     "x": 2,
     "y": 5,
     "w": 6,
     "h": 2
    },
    "relationships": {
     "view": {
      "data": {
       "type": "view",
       "id": "05664821c6e9f000"
      }
     }
    }
   },
   {
    "type": "view",
    "id": "05663f2fd829f000",
    "attributes": {
     "name": "Discont healthcheck status code",
     "properties": {
      "shape": "chronograf-v2",
      "type": "single-stat",
      "queries": [
       {
        "text": "from(bucket: \"workshop\")\n  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)\n  |> filter(fn: (r) => r._field == \"http_response_code\")\n  |> filter(fn: (r) => r.server == \"http://discount:3000/health\")\n  |> last()\n  |> yield(name: \"last\")",
        "editMode": "advanced",
        "name": "",
        "builderConfig": {
         "buckets": [],
         "tags": [
          {
           "key": "_measurement",
           "values": [],
           "aggregateFunctionType": "filter"
          }
         ],
         "functions": [],
         "aggregateWindow": {
          "period": "auto"
         }
        }
       }
      ],
      "prefix": "",
      "tickPrefix": "",
      "suffix": "",
      "tickSuffix": "",
      "colors": [
       {
        "id": "base",
        "type": "text",
        "hex": "#00C9FF",
        "name": "laser",
        "value": 0
       },
       {
        "id": "816c5320-9c48-4c09-b6f8-b7eff4368fd0",
        "type": "text",
        "hex": "#DC4E58",
        "name": "fire",
        "value": 400
       }
      ],
      "decimalPlaces": {
       "isEnforced": true,
       "digits": 2
      },
      "note": "This cell returns the last status code for the service. if no data are returned it means that the service is not well scraped by the telegraf plugin. Lickely it means that it down",
      "showNoteWhenEmpty": true
     }
    }
   },
   {
    "type": "view",
    "id": "0566404c0b69f000",
    "attributes": {
     "name": "Pay healthcheck status code",
     "properties": {
      "shape": "chronograf-v2",
      "type": "single-stat",
      "queries": [
       {
        "text": "from(bucket: v.bucket)\n  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)\n  |> filter(fn: (r) => r._field == \"http_response_code\")\n  |> filter(fn: (r) => r.server == \"http://pay:8080/health\")\n  |> last()\n  |> yield(name: \"last\")",
        "editMode": "advanced",
        "name": "",
        "builderConfig": {
         "buckets": [],
         "tags": [
          {
           "key": "_measurement",
           "values": [],
           "aggregateFunctionType": "filter"
          }
         ],
         "functions": [],
         "aggregateWindow": {
          "period": "auto"
         }
        }
       }
      ],
      "prefix": "",
      "tickPrefix": "",
      "suffix": "",
      "tickSuffix": "",
      "colors": [
       {
        "id": "base",
        "type": "text",
        "hex": "#00C9FF",
        "name": "laser",
        "value": 0
       },
       {
        "id": "816c5320-9c48-4c09-b6f8-b7eff4368fd0",
        "type": "text",
        "hex": "#DC4E58",
        "name": "fire",
        "value": 400
       }
      ],
      "decimalPlaces": {
       "isEnforced": true,
       "digits": 2
      },
      "note": "This cell returns the last status code for the service. if no data are returned it means that the service is not well scraped by the telegraf plugin. Lickely it means that it down",
      "showNoteWhenEmpty": true
     }
    }
   },
   {
    "type": "view",
    "id": "056640729b29f000",
    "attributes": {
     "name": "Frontend healthcheck status code",
     "properties": {
      "shape": "chronograf-v2",
      "type": "single-stat",
      "queries": [
       {
        "text": "from(bucket: v.bucket)\n  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)\n  |> filter(fn: (r) => r._field == \"http_response_code\")\n  |> filter(fn: (r) => r.server == \"http://frontend:3000/health\")\n  |> last()\n  |> yield(name: \"last\")",
        "editMode": "advanced",
        "name": "",
        "builderConfig": {
         "buckets": [],
         "tags": [
          {
           "key": "_measurement",
           "values": [],
           "aggregateFunctionType": "filter"
          }
         ],
         "functions": [],
         "aggregateWindow": {
          "period": "auto"
         }
        }
       }
      ],
      "prefix": "",
      "tickPrefix": "",
      "suffix": "",
      "tickSuffix": "",
      "colors": [
       {
        "id": "base",
        "type": "text",
        "hex": "#00C9FF",
        "name": "laser",
        "value": 0
       },
       {
        "id": "816c5320-9c48-4c09-b6f8-b7eff4368fd0",
        "type": "text",
        "hex": "#DC4E58",
        "name": "fire",
        "value": 400
       }
      ],
      "decimalPlaces": {
       "isEnforced": true,
       "digits": 2
      },
      "note": "This cell returns the last status code for the service. if no data are returned it means that the service is not well scraped by the telegraf plugin. Lickely it means that it down",
      "showNoteWhenEmpty": true
     }
    }
   },
   {
    "type": "view",
    "id": "0566408f8829f000",
    "attributes": {
     "name": "Item healthcheck status code",
     "properties": {
      "shape": "chronograf-v2",
      "type": "single-stat",
      "queries": [
       {
        "text": "from(bucket: v.bucket)\n  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)\n  |> filter(fn: (r) => r._field == \"http_response_code\")\n  |> filter(fn: (r) => r.server == \"http://item/health\")\n  |> last()\n  |> yield(name: \"last\")",
        "editMode": "advanced",
        "name": "",
        "builderConfig": {
         "buckets": [],
         "tags": [
          {
           "key": "_measurement",
           "values": [],
           "aggregateFunctionType": "filter"
          }
         ],
         "functions": [],
         "aggregateWindow": {
          "period": "auto"
         }
        }
       }
      ],
      "prefix": "",
      "tickPrefix": "",
      "suffix": "",
      "tickSuffix": "",
      "colors": [
       {
        "id": "base",
        "type": "text",
        "hex": "#00C9FF",
        "name": "laser",
        "value": 0
       },
       {
        "id": "816c5320-9c48-4c09-b6f8-b7eff4368fd0",
        "type": "text",
        "hex": "#DC4E58",
        "name": "fire",
        "value": 400
       }
      ],
      "decimalPlaces": {
       "isEnforced": true,
       "digits": 2
      },
      "note": "This cell returns the last status code for the service. if no data are returned it means that the service is not well scraped by the telegraf plugin. Lickely it means that it down",
      "showNoteWhenEmpty": true
     }
    }
   },
   {
    "type": "view",
    "id": "056641b970a9f000",
    "attributes": {
     "name": "Name this Cell",
     "properties": {
      "shape": "chronograf-v2",
      "type": "markdown",
      "note": "This dashboard is the control room for our set of services"
     }
    }
   },
   {
    "type": "view",
    "id": "0566472d9869f000",
    "attributes": {
     "name": "Discount status code distribution",
     "properties": {
      "shape": "chronograf-v2",
      "type": "histogram",
      "queries": [
       {
        "text": "from(bucket: \"workshop\")\n  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)\n  |> filter(fn: (r) => r._measurement == \"http_response\")\n  |> filter(fn: (r) => r.server == \"http://discount:3000/health\")",
        "editMode": "advanced",
        "name": "",
        "builderConfig": {
         "buckets": [],
         "tags": [
          {
           "key": "_measurement",
           "values": [],
           "aggregateFunctionType": "filter"
          }
         ],
         "functions": [],
         "aggregateWindow": {
          "period": "auto"
         }
        }
       }
      ],
      "colors": [
       {
        "id": "9d5cb0aa-18e4-4c81-a223-bec447bba26a",
        "type": "scale",
        "hex": "#31C0F6",
        "name": "Nineteen Eighty Four",
        "value": 0
       },
       {
        "id": "b19b236a-95e7-430f-a176-13df6b2557f7",
        "type": "scale",
        "hex": "#A500A5",
        "name": "Nineteen Eighty Four",
        "value": 0
       },
       {
        "id": "fb6915cf-61c1-47b6-bdd9-8a42061dc9a6",
        "type": "scale",
        "hex": "#FF7E27",
        "name": "Nineteen Eighty Four",
        "value": 0
       }
      ],
      "xColumn": "_time",
      "fillColumns": [
       "result"
      ],
      "xAxisLabel": "",
      "position": "stacked",
      "binCount": 0,
      "note": "",
      "showNoteWhenEmpty": false
     }
    }
   },
   {
    "type": "view",
    "id": "0566473b7369f000",
    "attributes": {
     "name": "Item status code distribution",
     "properties": {
      "shape": "chronograf-v2",
      "type": "histogram",
      "queries": [
       {
        "text": "from(bucket: \"workshop\")\n  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)\n  |> filter(fn: (r) => r._measurement == \"http_response\")\n  |> filter(fn: (r) => r.server == \"http://item/health\")",
        "editMode": "advanced",
        "name": "",
        "builderConfig": {
         "buckets": [],
         "tags": [
          {
           "key": "_measurement",
           "values": [],
           "aggregateFunctionType": "filter"
          }
         ],
         "functions": [],
         "aggregateWindow": {
          "period": "auto"
         }
        }
       }
      ],
      "colors": [
       {
        "id": "9d5cb0aa-18e4-4c81-a223-bec447bba26a",
        "type": "scale",
        "hex": "#31C0F6",
        "name": "Nineteen Eighty Four",
        "value": 0
       },
       {
        "id": "b19b236a-95e7-430f-a176-13df6b2557f7",
        "type": "scale",
        "hex": "#A500A5",
        "name": "Nineteen Eighty Four",
        "value": 0
       },
       {
        "id": "fb6915cf-61c1-47b6-bdd9-8a42061dc9a6",
        "type": "scale",
        "hex": "#FF7E27",
        "name": "Nineteen Eighty Four",
        "value": 0
       }
      ],
      "xColumn": "_time",
      "fillColumns": [
       "result"
      ],
      "xAxisLabel": "",
      "position": "stacked",
      "binCount": 0,
      "note": "",
      "showNoteWhenEmpty": false
     }
    }
   },
   {
    "type": "view",
    "id": "05664807e4e9f000",
    "attributes": {
     "name": "Frontend status code distribution",
     "properties": {
      "shape": "chronograf-v2",
      "type": "histogram",
      "queries": [
       {
        "text": "from(bucket: \"workshop\")\n  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)\n  |> filter(fn: (r) => r._measurement == \"http_response\")\n  |> filter(fn: (r) => r.server == \"http://frontend:3000/health\")",
        "editMode": "advanced",
        "name": "",
        "builderConfig": {
         "buckets": [],
         "tags": [
          {
           "key": "_measurement",
           "values": [],
           "aggregateFunctionType": "filter"
          }
         ],
         "functions": [],
         "aggregateWindow": {
          "period": "auto"
         }
        }
       }
      ],
      "colors": [
       {
        "id": "9d5cb0aa-18e4-4c81-a223-bec447bba26a",
        "type": "scale",
        "hex": "#31C0F6",
        "name": "Nineteen Eighty Four",
        "value": 0
       },
       {
        "id": "b19b236a-95e7-430f-a176-13df6b2557f7",
        "type": "scale",
        "hex": "#A500A5",
        "name": "Nineteen Eighty Four",
        "value": 0
       },
       {
        "id": "fb6915cf-61c1-47b6-bdd9-8a42061dc9a6",
        "type": "scale",
        "hex": "#FF7E27",
        "name": "Nineteen Eighty Four",
        "value": 0
       }
      ],
      "xColumn": "_time",
      "fillColumns": [
       "result"
      ],
      "xAxisLabel": "",
      "position": "stacked",
      "binCount": 0,
      "note": "",
      "showNoteWhenEmpty": false
     }
    }
   },
   {
    "type": "view",
    "id": "05664821c6e9f000",
    "attributes": {
     "name": "Pay status code distribution",
     "properties": {
      "shape": "chronograf-v2",
      "type": "histogram",
      "queries": [
       {
        "text": "from(bucket: \"workshop\")\n  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)\n  |> filter(fn: (r) => r._measurement == \"http_response\")\n  |> filter(fn: (r) => r.server == \"http://pay:8080/health\")",
        "editMode": "advanced",
        "name": "",
        "builderConfig": {
         "buckets": [],
         "tags": [
          {
           "key": "_measurement",
           "values": [],
           "aggregateFunctionType": "filter"
          }
         ],
         "functions": [],
         "aggregateWindow": {
          "period": "auto"
         }
        }
       }
      ],
      "colors": [
       {
        "id": "9d5cb0aa-18e4-4c81-a223-bec447bba26a",
        "type": "scale",
        "hex": "#31C0F6",
        "name": "Nineteen Eighty Four",
        "value": 0
       },
       {
        "id": "b19b236a-95e7-430f-a176-13df6b2557f7",
        "type": "scale",
        "hex": "#A500A5",
        "name": "Nineteen Eighty Four",
        "value": 0
       },
       {
        "id": "fb6915cf-61c1-47b6-bdd9-8a42061dc9a6",
        "type": "scale",
        "hex": "#FF7E27",
        "name": "Nineteen Eighty Four",
        "value": 0
       }
      ],
      "xColumn": "_time",
      "fillColumns": [
       "result"
      ],
      "xAxisLabel": "",
      "position": "stacked",
      "binCount": 0,
      "note": "",
      "showNoteWhenEmpty": false
     }
    }
   },
   {
    "id": "05663a9e2be9f000",
    "type": "variable",
    "attributes": {
     "name": "bucket",
     "arguments": {
      "type": "query",
      "values": {
       "query": "buckets()\n  |> filter(fn: (r) => r.name !~ /^_/)\n  |> rename(columns: {name: \"_value\"})\n  |> keep(columns: [\"_value\"])\n",
       "language": "flux"
      }
     },
     "selected": null
    },
    "relationships": {
     "label": {
      "data": []
     }
    }
   }
  ]
 },
 "labels": []
}
```

**PRO:** You can do another set of cells related to `latency`. It is an
important signal because if it grows too much it means that for some reason your
application is slower.

## Tips and Tricks

The `inputs.http_response` documentation is
[here](http://docs.influxdata.com/telegraf/v1.10/plugins/inputs/#http-response)

The telegraf configuration is under `./telegraf/telegraf.conf` and in order to
reload the configuration you can use `docker-compose restart telegraf`.

\newpage

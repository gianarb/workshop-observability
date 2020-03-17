---
title: "Application Monitoring"
author: Gianluca Arbezzano
geometry: "left=3cm,right=3cm,top=2cm,bottom=2cm"
fontfamily: helvet
output: pdf_document
---

\newpage

Microservices, cloud computing, DevOps, containers changed the way to write applications.
Nowadays we have smaller, much more distributed and replicated applications.
Sometime even across different languages.

A steam of logs is not enough to understand what it is going on. We need
correlation between requests across the board. We need more context to be able
to tell the story of our distributed system.

Now that developers are in the loop of running their application they need
different tools compared with what sysadmin are used to have. Because they need
to understand what it is happening inside their application.

That's why I developed this course. Because I think **application
instrumentation** will splay an important part in our journey to understand and
troubleshoot what is going now in our applications.

## Target

* Developers
* Solution Architect
* DevOps

## Practical
The practical part of the course is based on the code located at
[gianarb/shopmany](https://github.com/gianarb/shopmany)

## Material

This PDF is long, only because it contains all the code changes in form of git
patches. Otherwise it will be just a couple of page long.

This morning we learned in theory what tracing, logging, reliability means. This
afternoon we are gonna see it in practice. The exercise are divided in 4
lessons. The same areas we spoke about this morning

1. Lesson 1 - Health check
2. Lesson 2 - Logging
3. Lesson 3 - Infrastructure monitoring with InfluxDB & Jeager
3. Lesson 4 - Tracing

The PDF as I said contains the solution for those exercise, you can use them as
inspiration in case your blocked or to move forward with the servicesa that are
written in language you do not know about.

It is not easy to copy/paste from a PDF, that's why you still have the raw
patches in the [gianarb/workshop-observability](https://github.com/gianarb/workshop-observability) repository
under the `./patches` directory.

Or as a branch to [gianarb/shopmany](https://github.com/gianarb/shopmany).

## Timeline
This is an example of timeline that I used at the CloudConf 2019 in Italy.

09.00 Registration and presentation
09.30 - 13.00 Theory

* Observability vs monitoring
* Logs, events and traces
* How a monitoring infrastructure looks like: InfluxDB, Prometheus, Jaeger,
  Zipkin, Kapacitor, Telegraf...
* Deep dive on InfluxDB and the TICK Stack
* Deep dive on Distributed Tracing

13.00 - 14.00 Launch
14.00 - 17.00 Let's make our hands dirty
17.30 - 18.00 Recap, questions and so on

## Credits
This is probably one of the most important section! Instrumenting application is
hard because you need to build agreement. We know as a developer how
"complaining oriented" we are as a category. There are big communities, people
that are working to make all of this easy and possible. You will find a chapter
"Link" in every lesson with some of the blog posts I wrote and read about this
topic. Here I would like to share with you some of the people you should follow
if you are looking for inspiration around these topics:

* [Yuri Shkuro](https://github.com/yurishkuro) Opentracing and Jaeger Contributor
* [Charity Major](https://twitter.com/mipsytipsy) CTO of HoneyComb and pioneer of "Observability".
* [JDB](https://twitter.com/rakyll) Engineer at Google.
* [Brendan Gregg](http://www.brendangregg.com/) Performance Engineer at Netflix
* [InfluxData](https://influxdata.com) the company behind InfluxDB and its
  founder [Paul Dix](https://twitter.com/pauldix).

\newpage

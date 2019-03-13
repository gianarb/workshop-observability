First of all we need to get in touch with the applications we will instrument
and we will improve along this course.

I built a shiny, great, new e-commerce. Check it out from
[gianarb/shopmany](https://github.com/gianarb/shopmany) and read the README.md
in order to run it.

In short:

```
$ git clone git@github.com:gianarb/shopmany.git
$ cd shopmany
$ docker-compose up frontend
```

You can open your browser and visit the page: `3000`. You will resolve a very
nice e-commerce.

## Services
As you can see from the shopmany's README.md there are different services in different
languages. I am not expecting you to know all of them. I had a couple of friends
that helped me to write them down too.

Pick one, two or even all if you feel confident, but the goal is to instrument
and code only what you know.

Along the course we will get over all of them. I set it up in this way to tell
you that observability and application instrumentation are practices that are
over specific languages.

Every exercise has a `./SOLUTIONS.md` file that contains a `git diff` for every
application that shows how I implemented the code. The diff contains the commit
sha in the header. Uses the solution if you are blocked or to
[cherry-pick](https://git-scm.com/docs/git-cherry-pick) the
code for the applications that you are not developing.

For example if you are not working in java with the `pay` application you can
cherry pick the java code via:

```
git cherry-pick 123dfdc
```

## Exercise: Health endpoint

**Time: 20minutes**

It is time to make our hands dirty. From now you need to have selected the set
of applications or the application that you are gonna use along the course.
Leave the others behind.

The first exercise is to create an healthcheck endpoint.

The goal for every `/health` endpoint is to give you information about the
status of the running process. I saw a lot of bad implementation where the
endpoint was just returning a printed JSON as response without doing any check.

I would like you to create a new endpoint:

```
PATH: /health
METHOD: GET
BODY:
{
    "status": "healthy|unhelathy",
    "checks: [
        {
            "name": "mysql",
            "status": "healthy",
            "error": ""
        }
    ]
}
```
Based on the application you are modifying you need to check if the required
dependencies are working.

* `items` needs to check if `mysql` is working.
* `frontend` needs to check if `item` is up and running.
* `discount` needs to check if `mongodb` is up and running.
* `pay` needs to check if `mysql` is up and running.

If all the checks are `healthy` you return `200` as status code and the general
status is `healthy`. If one of them is not you populate the `error` for that
check, you mark it as unhealthy and the general status will become `unhealthy`
too.

All the checks needs to be `healthy` to mark the general status as `healthy`.

## Motivation
A strong healthcheck is important to troubleshoot applications where you didn't
write them. Because if across the company you agree on the same format the first
things you can do is to check for that endpoint.

Moving forward we will see how to use it for automation and monitoring.

## Tips and Tricks

You do not need to add dependencies here. The exercise just requires to code
a new endpoint.

## Link

* [Configure Liveness and Readiness Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/)
* [Kubernetes Liveness and Readiness Probes: Looking for More Feet](https://blog.colinbreck.com/kubernetes-liveness-and-readiness-probes-looking-for-more-feet/)

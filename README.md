# Crafty

Crafty is a dead simple but useful for personal projects CI server.

![Screencast1](/images/screencast1.gif)

## Features

- [x] event driven single threaded server
- [x] dynamic workers (inproc, fork or detach mode)
- [x] realtime updates
- [x] realtime log tails
- [x] REST API
- [x] integrations with GitHub, GitLab and BitBucket

## Configuration (YAML)

For default configuration see
[data/config.yml.example](https://github.com/vti/crafty/blob/master/data/config.yml.example) in this repository.

```yaml
---
pool:
    workers: 2
    mode: detach
projects:
    - id: app
      webhooks:
          - provider: rest
      build:
          - sleep 10
```

Configuration file is validated against Kwalify schema
[schema/config.yml](https://github.com/vti/crafty/blob/master/schema/config.yml).

## Installation

### Docker

*Using existing image*

From [Docker Hub](https://hub.docker.com/r/vtivti/crafty/).

    Pull image
    $ docker pull vtivti/crafty

    Prepare directories
    $ mkdir -p crafty/data
    $ cd crafty

    Prepare config file
    $ curl 'https://raw.githubusercontent.com/vti/crafty/master/data/config.yml.example' > data/config.yml

    Start container
    $ docker run -d --restart always -v $PWD/data/:/opt/crafty/data -p 5000:5000 --name crafty crafty

*Build your own image*

    $ git clone https://github.com/vti/crafty
    $ cd crafty
    $ sh util/docker-build.sh

### From scratch

You have to have *Perl* :camel: and *SQLite3* installed.

    Clone
    $ git clone https://github.com/vti/crafty
    $ cd crafty

    Bootstrap
    $ bin/bootstrap

    Run migrations (if any)
    $ bin/migrate

## Starting

    $ bin/crafty
    $ bin/crafty --listen :8888
    $ bin/crafty --config data/config.yml

## Integrations

Integrations are possible on both the incoming webhook and outgoing posthook. Examples can be found in
[examples](https://github.com/vti/crafty/blob/master/examples) directory.

### Example GitHub Integration

We are going to integrate incoming webhooks and commit status updates.

1. Generating personal token

Navigate to <https://github.com/settings/tokens> and create a personal token with `repo:status` permission.

2. Configuring Crafty

```yaml
---
projects:
    - id: test
      webhooks:
          - id: github
            cgi: github-webhook.sh
      build:
          - git clone http://github.com/vti/test
      post:
          - github-create-status.sh
```

Adjust `github-create-status.sh` by putting your token inside.

3. Creating webhook

Create the webhook on GitHub with the following url pattern:

    http://crafty.address/webhook/:webhook_id/:project_id

In our case:

    http://crafty.address/webhook/github/test

4. Push to your repository and check the crafty logs.

## REST API

### Essentials

#### Client Errors

1. Invalid format

    HTTP/1.1 400 Bad Request

    {"error":"Invalid JSON"}

2. Validation errors

    HTTP/1.1 422 Unprocessible Entity

    {"error":"Invalid fields","fields":{"project":"Required"}}

#### Server Errors

1. Something bad happened

    HTTP/1.1 500 System Error

    {"error":"Oops"}

### Build Management

#### List Builds

    GET /builds

**Response**

    HTTP/1.1 200 Ok
    Content-Type: application/json

    {
        "builds": [{
            "status": "S",
            "uuid": "d51ef218-2f1b-11e7-ab6d-4dcfdc676234",
            "pid": 0,
            "is_cancelable": "",
            "created": "2017-05-02 11:43:44.430438+0200",
            "finished": "2017-05-02 11:43:49.924477+0200",
            "status_display": "success",
            "is_new": "",
            "branch": "master",
            "project": "tu",
            "is_restartable": "1",
            "status_name": "Success",
            "duration": 6.48342710037231,
            "rev": "123",
            "version": 4,
            "message": "123",
            "author": "vti",
            "started": "2017-05-02 11:43:44.558950+0200"
        }, ...]
        "total": 5,
        "pager": {
            ...
        }
    }

**Example**

    $ curl http://localhost:5000/api/builds

#### Get Build

    GET /builds/:uuid

**Response**

    HTTP/1.1 200 Ok
    Content-Type: application/json

    {
        "build" :
        {
            "status": "S",
            "uuid": "d51ef218-2f1b-11e7-ab6d-4dcfdc676234",
            "pid": 0,
            "is_cancelable": "",
            "created": "2017-05-02 11:43:44.430438+0200",
            "finished": "2017-05-02 11:43:49.924477+0200",
            "status_display": "success",
            "is_new": "",
            "branch": "master",
            "project": "tu",
            "is_restartable": "1",
            "status_name": "Success",
            "duration": 6.48342710037231,
            "rev": "123",
            "version": 4,
            "message": "123",
            "author": "vti",
            "started": "2017-05-02 11:43:44.558950+0200"
        }
    }

**Example**

    $ curl http://localhost:5000/api/builds

#### Create Build

    POST /builds

**Content type**

Can be either `application/json` or `application/x-www-form-urlencoded`.

**Body params**

Required

- project=[string]
- rev=[string]
- branch=[string]
- author=[string]
- message=[string]

**Response**

    HTTP/1.1 200 Ok
    Content-Type: application/json

    {"uuid":"d51ef218-2f1b-11e7-ab6d-4dcfdc676234"}

**Example**

    $ curl http://localhost:5000/api/builds -d 'project=tu&rev=123&branch=master&author=vti&message=fix'

#### Cancel Build

    POST /builds/:uuid/cancel

**Response**

    HTTP/1.1 200 Ok
    Content-Type: application/json

    {"ok":1}

**Example**

    $ curl http://localhost:5000/api/builds/d51ef218-2f1b-11e7-ab6d-4dcfdc676234/cancel

#### Restart Build

    POST /builds/:uuid/restart

**Response**

    HTTP/1.1 200 Ok
    Content-Type: application/json

    {"ok":1}

**Example**

    $ curl http://localhost:5000/api/builds/d51ef218-2f1b-11e7-ab6d-4dcfdc676234/restart

### Build Logs

#### Download raw build log

    GET /builds/:uuid/log

**Response**

    HTTP/1.0 200 OK
    Content-Type: text/plain
    Content-Disposition: attachment; filename=6b90cf28-2f12-11e7-b73a-e1bddc676234.log

    [...]

**Example**

    $ curl http://localhost:5000/api/builds/d51ef218-2f1b-11e7-ab6d-4dcfdc676234/log

#### Watching the build log

    GET /builds/:uuid/tail

**Content Type**

Output is in `text/event-stream` format. More info at
[MDN](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events).

**Response**

    HTTP/1.0 200 OK
    Content-Type: text/event-stream; charset=UTF-8
    Access-Control-Allow-Methods: GET
    Access-Control-Allow-Credentials: true

    data: [...]

**Example**

    $ curl http://localhost:5000/api/builds/d51ef218-2f1b-11e7-ab6d-4dcfdc676234/tail

### Events

#### Watching events

    GET /events

**Content Type**

Output is in `text/event-stream` format. More info at
[MDN](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events).

**Response**

    HTTP/1.0 200 OK
    Content-Type: text/event-stream; charset=UTF-8
    Access-Control-Allow-Methods: GET
    Access-Control-Allow-Credentials: true

    data: [...]

**Example**

    $ curl http://localhost:5000/api/events

#### Create event

    POST /events

**Response**

    HTTP/1.0 200 OK
    Content-Type: application/json

    {"ok":1}

**Example**

    $ curl http://localhost:5000/api/events -H 'Content-Type: application/json' -d '["event", {"data":"here"}]'

## Troubleshooting

Try *verbose* mode

    $ bin/crafty --verbose

## Bug Reporting

<https://github.com/vti/crafty/issues>

## Copyright & License

Copyright (C) 2017, Viacheslav Tykhanovskyi

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

This program is distributed in the hope that it will be useful, but without any
warranty; without even the implied warranty of merchantability or fitness for
a particular purpose.

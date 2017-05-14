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
- [x] authentication

## Demo

Working demo is available at <http://crafty.showmetheco.de>.

## Configuration (YAML)

For default configuration see
[data/config.yml.example](https://github.com/vti/crafty/blob/master/data/config.yml.example) in this repository.

```yaml
---
access:
    mode: public
    users:
        - username: admin
          password: ab7762952be439c958a7398492a6a3706117e61a217e0e
          hashing: bcrypt
pool:
    workers: 2
    mode: detach
projects:
    - id: app
      build:
          - sleep 10
```

Configuration file is validated against Kwalify schema
[schema/config.yml](https://github.com/vti/crafty/blob/master/schema/config.yml).

## Authentication

Two modes are available: `public` and `private`. The first one `public` mode means that anonymous users can browse the
crafty server but cannot do any modifying operations like restarting, canceling etc. The `private` mode will not
accept not logged in users.

## Hashing passwords

A special utility `util/hash-password.pl` is provided to make hashing password easier. For example we want to create
a user `admin` with password `pa$$w0rd` using `bcrypt` hashing algorithm and salt `thisismysalt`:

```
$ bin/env util/hash-password.pl --hashing bcrypt --salt thisismysalt admin pa$$w0rd
username: admin
password: 1e52bcc68f3eef5eb9c9a116a678e81dcf7ffa659454dc
hashing: bcrypt
salt: thisismysalt
```

Put the output into `access.users` section of the config file.

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

    or try fast bootstrap (this can be faster, but still experimental)
    $ bin/bootstrap-fast

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

#### Authentication

Basic authentication is used. The username and password are loaded from the config:

```yaml
access:
    users:
       - username: api
         password: ab7762952be439c958a7398492a6a3706117e61a217e0e
         hashing: bcrypt
```

Example:

    curl http://api:password@localhost:5000/api/builds

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

# Crafty

Crafty is a dead simple but useful for personal projects CI server.

## Screencasts

![Screencast1](/images/screencast1.gif)

## Features

- [x] event driven single threaded server
- [x] dynamic workers (inproc, fork or detach mode)
- [x] realtime updates
- [x] realtime log tails
- [ ] REST API
- [ ] webhook integration with GitHub, GitLab and BitBucket

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

    $ git clone https://github.com/vti/crafty
    $ cd crafty
    $ bin/bootstrap
    $ bin/migrate
    $ bin/crafty

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

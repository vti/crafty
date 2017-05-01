#!/bin/sh

docker run -d --restart always -v $PWD/data/:/opt/crafty/data -p 5000:5000 --name crafty crafty

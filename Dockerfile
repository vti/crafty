FROM       debian:9

RUN apt-get update && apt-get install -y make gcc perl sqlite3

RUN mkdir -p /opt/crafty
COPY bin/ /opt/crafty/bin/
COPY util/ /opt/crafty/util/
COPY lib/ /opt/crafty/lib/
COPY schema/ /opt/crafty/schema/
COPY public/ /opt/crafty/public/
COPY templates/ /opt/crafty/templates/
COPY cpanfile /opt/crafty/

RUN cd /opt/crafty/; bin/bootstrap

EXPOSE 5000

VOLUME  ["/opt/crafty/data"]

COPY docker/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

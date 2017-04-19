FROM       debian:9

RUN apt-get update && apt-get install -y make gcc perl sqlite3

RUN mkdir -p /opt/crafty
COPY bin/ /opt/crafty/bin/
COPY lib/ /opt/crafty/lib/
COPY schema/ /opt/crafty/schema/
COPY public/ /opt/crafty/public/
COPY templates/ /opt/crafty/templates/
COPY cpanfile /opt/crafty/

RUN cd /opt/crafty/; PERL5LIB=".:$PERL5LIB" bin/cpanm -q -n --installdeps -L perl5 .

EXPOSE 5000

ENTRYPOINT ["/opt/crafty/bin/crafty"]

VOLUME  ["/opt/crafty/data"]

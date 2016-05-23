FROM pritunl/archlinux

RUN pacman -S --noconfirm mysql

ENV MYSQL_ROOT_PASSWORD 1234
ENV MYSQL_REPLICATION_PASSWORD 1234

COPY my.cnf.tmpl /tmp/my.cnf.tmpl
COPY reset.sh /reset.sh
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh","-e"]


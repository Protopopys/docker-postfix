FROM debian:jessie
#
LABEL maintainer="Protopopys <protopopys@gmail.com>"
#
RUN apt-get update && apt-get install -y \
            supervisor \
            postfix \
            sasl2-bin \
            opendkim \
            opendkim-tools \
            rsyslog
RUN sed -i "s/inet_interfaces = localhost/inet_interfaces = all/g" /etc/postfix/main.cf \
 && sed -i "s/^mydestination.*/mydestination = \$myhostname, localhost.\$mydomain, localhost/g" /etc/postfix/main.cf \
 && echo >> /etc/postfix/main.cf \
 && mkdir -p /etc/postfix/certs && mkdir -p /etc/opendkim/domainkeys  && mkdir /var/lib/rsyslog && mv /etc/supervisor/supervisord.conf /etc/supervisor/supervisord.default
# 
COPY --chown=root:root init.sh /root/init.sh
COPY --chown=root:root rsyslog.conf /etc/rsyslog.conf
COPY --chown=root:root listen.conf /etc/rsyslog.d/listen.conf
#
CMD /root/init.sh;/usr/bin/supervisord -c /etc/supervisor/supervisord.conf
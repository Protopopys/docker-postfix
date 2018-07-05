#!/bin/bash

if [[ -a /etc/supervisor/supervisord.conf ]]; then
  exit 0
fi
#supervisor
cat > /etc/supervisor/supervisord.conf <<EOF
[supervisord]
nodaemon=true
user=root
logfile=/var/log/surervisord.log
pidfile=/var/run/surervisord.pid
childlogdir=/var/log/supervisor

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[unix_http_server]
file = /var/run/supervisor.sock
chmod=0700
username = service
password = service

[supervisorctl]
serverurl=unix:///var/run/supervisor.sock
username = service
password = service

[program:postfix]
command=/usr/lib/postfix/master -c /etc/postfix -d
autostart=true
autorestart=true
startretries=2
startsecs=3
priority=1
killasgroup=true
stopasgroup=true

[program:rsyslog]
command=/usr/sbin/rsyslogd -n
autostart=true
autorestart=true
startretries=2
startsecs=3
priority=100
killasgroup=true
stopasgroup=true

[program:readlog]
command=/usr/bin/tail -f /var/log/maillog
autostart=true
autorestart=true
startretries=10
startsecs=3
priority=999
stdout_logfile=/proc/self/fd/1
stdout_logfile_maxbytes=0
stderr_logfile=/proc/self/fd/2
stderr_logfile_maxbytes=0
killasgroup=true
stopasgroup=true
EOF

if [[ -a /etc/postfix/sasl/smtpd.conf ]]; then
  echo "Already configured "
  exit 0
fi

############
#  postfix
############
postconf -F '*/*/chroot = n'
postconf -e myhostname=$maildomain
postconf -e message_size_limit=$maxmailsize
postconf -e mynetworks_style=subnet
postconf -e inet_protocols=ipv4
############
# SASL SUPPORT FOR CLIENTS
# The following options set parameters needed by Postfix to enable
# Cyrus-SASL support for authentication of mail clients.
############
# /etc/postfix/main.cf
postconf -e smtpd_use_tls=no
postconf -e smtpd_sasl_local_domain=$maildomain
postconf -e smtpd_sasl_auth_enable=yes
postconf -e broken_sasl_auth_clients=yes
postconf -e smtpd_recipient_restrictions=permit_sasl_authenticated,reject_unauth_destination
# smtpd.conf
echo "Create smtpd.conf"
cat >> /etc/postfix/sasl/smtpd.conf <<EOF
pwcheck_method: auxprop
auxprop_plugin: sasldb
mech_list: PLAIN LOGIN CRAM-MD5 DIGEST-MD5 NTLM
EOF
# sasldb2
echo $smtp_user | tr , \\n > /tmp/passwd
while IFS=':' read -r _user _pwd; do
  echo $_pwd | saslpasswd2 -p -c -u $maildomain $_user
done < /tmp/passwd
chown postfix.sasl /etc/sasldb2

############
# Enable TLS
############
echo "Cert checking"
if [[ -n "$(find /etc/postfix/certs -iname *.crt)" && -n "$(find /etc/postfix/certs -iname *.key)" ]]; then
  # /etc/postfix/main.cf
  postconf -e smtpd_tls_cert_file=$(find /etc/postfix/certs -iname *.crt)
  postconf -e smtpd_tls_key_file=$(find /etc/postfix/certs -iname *.key)
  postconf -e smtp_use_tls=yes
  postconf -e smtp_tls_mandatory_ciphers=high
  postconf -e smtp_tls_mandatory_protocols=!SSLv2,!SSLv3
  postconf -e tls_high_cipherlist=ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!3DES:!MD5:!PSK
  chmod 400 /etc/postfix/certs/*.*
  # /etc/postfix/master.cf
  postconf -M submission/inet="submission   inet   n   -   n   -   -   smtpd"
  postconf -P "submission/inet/syslog_name=postfix/submission"
  postconf -P "submission/inet/smtpd_tls_security_level=encrypt"
  postconf -P "submission/inet/smtpd_sasl_auth_enable=yes"
  postconf -P "submission/inet/milter_macro_daemon_name=ORIGINATING"
  postconf -P "submission/inet/smtpd_recipient_restrictions=permit_sasl_authenticated,reject_unauth_destination"
fi

#############
#  opendkim
#############
echo "Key checking"
if [[ -z "$(find /etc/opendkim/domainkeys -iname *.private)" ]]; then
  exit 0
fi
cat >> /etc/supervisor/supervisord.conf <<EOF
[program:opendkim]
command=/usr/sbin/opendkim -f
autostart=true
autorestart=true
startretries=2
startsecs=3
EOF
# /etc/postfix/main.cf
postconf -e milter_protocol=2
postconf -e milter_default_action=accept
postconf -e smtpd_milters=inet:localhost:12301
postconf -e non_smtpd_milters=inet:localhost:12301

cat >> /etc/opendkim.conf <<EOF
AutoRestart             Yes
AutoRestartRate         10/1h
UMask                   002
Syslog                  yes
SyslogSuccess           Yes
LogWhy                  Yes
Canonicalization        relaxed/simple
ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts
InternalHosts           refile:/etc/opendkim/TrustedHosts
KeyTable                refile:/etc/opendkim/KeyTable
SigningTable            refile:/etc/opendkim/SigningTable
Mode                    sv
PidFile                 /var/run/opendkim/opendkim.pid
SignatureAlgorithm      rsa-sha256
UserID                  opendkim:opendkim
Socket                  inet:12301@localhost
EOF

cat >> /etc/default/opendkim <<EOF
SOCKET="inet:12301@localhost"
EOF

cat >> /etc/opendkim/TrustedHosts <<EOF
127.0.0.1
localhost
192.168.0.1/24
*.$maildomain
EOF
cat >> /etc/opendkim/KeyTable <<EOF
  ${maildomain}._domainkey.$maildomain $maildomain:$maildomain:$(find /etc/opendkim/domainkeys -iname $maildomain.private)
EOF
cat >> /etc/opendkim/SigningTable <<EOF
  *@$maildomain $maildomain._domainkey.$maildomain
EOF
chown opendkim:opendkim $(find /etc/opendkim/domainkeys -iname *.private)
chmod 400 $(find /etc/opendkim/domainkeys -iname *.private)
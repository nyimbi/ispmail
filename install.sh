#!/bin/bash
#
# ISPmail Install Script for Ubuntu 14.04 LTS
#
# An unholy conglomerate of inspiration coming from the following sources:
# * https://workaround.org/book/export/html/447
# * http://sealedabstract.com/code/nsa-proof-your-e-mail-in-2-hours/
#
# Laborously created and furiously tested by Marcel Bischoff
# <https://github.com/herrbischoff>

# Update system
aptitude update && \
aptitude upgrade -y && \
aptitude dist-upgrade -y && \

# Install software
aptitude install ssh postfix postfix-mysql swaks mysql-server dovecot-mysql dovecot-pop3d dovecot-imapd dovecot-managesieved roundcube roundcube-plugins -y && \

# Generate self-signed certificate
openssl req -new -x509 -days 3650 -nodes -newkey rsa:4096 -out /etc/ssl/certs/mailserver.pem -keyout /etc/ssl/private/mailserver.pem && \

# Setup Apache for SSL
sed -i 's|/etc/ssl/certs/ssl-cert-snakeoil.pem|/etc/ssl/certs/mailserver.pem|' /etc/apache2/sites-available/default-ssl.conf && \
sed -i 's|/etc/ssl/private/ssl-cert-snakeoil.key|/etc/ssl/private/mailserver.pem|' /etc/apache2/sites-available/default-ssl.conf && \
a2ensite default-ssl && \
a2enmod ssl && \
service apache2 reload && \

# Setup database
mysql -u root -proot < db.sql && \

# Setup Postfix
cp mysql-virtual-mailbox-domains.cf /etc/postfix/mysql-virtual-mailbox-domains.cf && \
postconf -e virtual_mailbox_domains=mysql:/etc/postfix/mysql-virtual-mailbox-domains.cf && \

cp mysql-virtual-mailbox-maps.cf /etc/postfix/mysql-virtual-mailbox-maps.cf && \
postconf -e virtual_mailbox_maps=mysql:/etc/postfix/mysql-virtual-mailbox-maps.cf && \

cp mysql-virtual-alias-maps.cf /etc/postfix/mysql-virtual-alias-maps.cf && \
postconf -e virtual_alias_maps=mysql:/etc/postfix/mysql-virtual-alias-maps.cf && \

# Check Postfix config
#echo "This should output '1':" && \
#postmap -q example.org mysql:/etc/postfix/mysql-virtual-mailbox-domains.cf && \
echo "This should output '1':" && \
postmap -q john@example.org mysql:/etc/postfix/mysql-virtual-mailbox-maps.cf && \
echo "This should output 'john@example.com':" && \
postmap -q jack@example.org mysql:/etc/postfix/mysql-virtual-alias-maps.cf && \

# Setup Dovecot
#groupadd -g 5000 vmail && \
#useradd -g vmail -u 5000 vmail -d /var/vmail -m && \
chown -R vmail:vmail /var/vmail && \
chmod u+w /var/vmail && \
cp -r conf.d /etc/dovecot && \
cp dovecot-sql.conf.ext /etc/dovecot/dovecot-sql.conf.ext && \
chgrp vmail /etc/dovecot/dovecot.conf && \
chmod g+r /etc/dovecot/dovecot.conf && \
chown root:root /etc/dovecot/dovecot-sql.conf.ext && \
chmod go= /etc/dovecot/dovecot-sql.conf.ext && \
service dovecot restart && \

# Connect Postfix and Dovecot
cat postfix-dovecot-connect >> /etc/postfix/master.cf  && \
postconf -e virtual_transport=dovecot && \
postconf -e dovecot_destination_recipient_limit=1 && \
service postfix restart && \

# Enable SMTP authentication
postconf -e smtpd_sasl_type=dovecot && \
postconf -e smtpd_sasl_path=private/auth && \
postconf -e smtpd_sasl_auth_enable=yes && \
postconf -e smtpd_tls_security_level=may && \
postconf -e smtpd_tls_auth_only=yes && \
postconf -e smtpd_tls_cert_file=/etc/ssl/certs/mailserver.pem && \
postconf -e smtpd_tls_key_file=/etc/ssl/private/mailserver.pem && \
postconf -e smtpd_recipient_restrictions="permit_mynetworks permit_sasl_authenticated reject_unauth_destination" && \

# Add and setup fail2ban
aptitude install fail2ban && \
cp dovecot-pop3imap.conf /etc/fail2ban/filter.d/dovecot-pop3imap.conf && \
cat fail2ban-jail >> /etc/fail2ban/jail.conf && \
service fail2ban restart && \

# Add dspam
aptitude install dspam dovecot-antispam postfix-pcre dovecot-sieve -y

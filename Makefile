#
#	@(#) Makefile V2.4 (C) 2010-2019 by Roman Oreshnikov
#
# Сценарий работ учета сетевых подключений и управления DNS
#

# Рабочие файлы (порядок важен)
CFG	= Rdns.tst

# MS AD домены (для исключений)
AD	=

# Каталоги для работ с DNS
DIR	= $(PWD)/dns
CUR	= $(DIR)/cur
NEW	= $(DIR)/new

# Скрипт получения текущих мастер-зон с NS
DIG	= $(DIR)/dns.dig

# Перечень мастер-зон в формате конфигурации BIND
LST	= $(DIR)/dns.lst

# Таблица соединений
TAB	= $(DIR)/dns.htm

# SQLite3 dump
SQL	= $(DIR)/dns.sql

# SQLite3 база
DB	= $(DIR)/dns.db

# Мастер сервер
MAIN	= 127.0.0.1

# Управляемые NS сервера
SRV	=

# Исходники
SRC	= Named.conf Rdns.cfg Rdns.cgi Rdns.pl Rdns.tst RdnsUp.pl

# Default target
ALL:	$(DIR)/dns.ok

# Сверка мастер-зон с обновлением DNS RRs и сохранение актуальных мастер-зон
$(DIR)/dns.ok:	$(DIG)
	@[ -d "$(CUR)" ] || make NS; \
	if [ -d "$(NEW)" ]; then \
		umask 002; echo "### Checking zones"; \
		./RdnsUp.pl -is -a "$(AD)" $(CUR) $(NEW) && \
		/bin/rm -rf $(CUR) && /bin/mv $(NEW) $(CUR); \
	fi; >$@

# Выгрузка мастер-зон с NS
NS:	$(DIG)
	@umask 002; echo "### Geting zones from NS"; \
	if [ -d "$(CUR)" ]; then /bin/rm -f $(CUR)/*; \
	else /bin/mkdir -p "$(CUR)"; fi; \
	cd $(CUR) && . $(DIG)

# Обработка конфигурационных файлов
$(DIG):	$(CFG)
	@umask 002; echo "### Building the zones and support files"; \
	if [ -d "$(NEW)" ]; then /bin/rm -f $(NEW)/*; \
	else /bin/mkdir -p "$(NEW)"; fi; \
	./Rdns.pl -c $(DIG) -d $(NEW) -l $(LST) -t $(TAB) -s $(SQL) $(CFG); \
	/usr/bin/sqlite3 $(DB)~ '.read $(SQL)'; \
	/bin/chmod g+w $(DB)~; \
	/bin/mv $(DB)~ $(DB)

# Создание архива конфигурации NS сервера
$(DIR)/dns.tar: Named.conf
	@umask 002; echo "### Build configs for servers"; \
	/bin/mkdir -p $(DIR)/etc/named $(DIR)/var/named; \
	/bin/cp Named.conf $(DIR)/etc/named; \
	/bin/sed -e 's/Main/Slave/;s/Named/named/g;/allow-update/d' \
                -e 's/.*also-notify.*/\tnotify no;/' \
                -e 's/master;$$/slave;\n\tmasters { $(MAIN); };/' \
		Named.conf >$(DIR)/etc/named/named.conf; \
	/bin/tar -C $(DIR) --remove-files --owner=named --group=named -cf $@ \
		etc var

# Копирование конфигурации на NS сервера
DNS: $(DIR)/dns.tar
	@echo "### Install configs to NS"; \
	for H in $(SRV); do \
		/bin/cat $(DIR)/dns.tar | /usr/bin/ssh $$H /usr/bin/sudo \
		/bin/tar -C / -xf - etc/named/Named.conf etc/named/named.conf \
		/usr/bin/ssh $$H /usr/sbin/rndc reconfig; \
	done

# Сброс кэша NS серверов
flush:
	@echo "### Flushes all of the server's caches"; \
	for H in $(SRV); do /usr/bin/ssh $$H /usr/sbin/rndc flush; done

# Зачистка
clean:
	@echo "### Cleaning the work directory"; /bin/rm -rf $(DIR)

# Создание дистрибутива
dist: Makefile $(SRC)
	@set -e; \
	D=`/bin/sed '/@(#)/!d;s/^.*V\([^ ]*\).*/Rdns-\1/;q' Makefile`; \
	echo "Create $$D.tar.xz"; \
	[ ! -d "$$D" ] || /bin/rm -rf "$$D"; /bin/mkdir "$$D"; \
	/bin/cp Makefile "$$D"; \
	V=`/bin/sed '/@(#)/!d;s/^.*\(V.*\)$$/\1/;q' Makefile`; \
	for F in $(SRC); do \
		/bin/sed "s/\(@(#)\).*/\1 $$F $$V/" $$F >"$$D/$$F"; \
	done; \
	/bin/tar cf - --remove-files "$$D" | /usr/bin/xz -9c >"$$D.tar.xz"

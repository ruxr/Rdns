#
#	@(#) Makefile V3.1 (C) 2010-2023 by Roman Oreshnikov
#
# Сценарий работ по созданию таблиц подключений к ЛВС и внесения изменений в DNS
#

# Исходные рабочие файлы (порядок важен)
CFG	= Rdns.cfg

# Каталог для результирующих файлов
#WRK	:= /var/Rdns/

# Версия пакета
VER	:= $(shell sed '/@(#)/!d;s/.*V\([0-9.]*\).*/\1/' Makefile)

# Константы
BIN	:= Rdns			# Основной скрипт
CGI	:= Rdns.cgi		# Скрипт визуализации
CHK	:= Rchk			# Скрипт тестирования
DIR	:= $(WRK)Rdns.d		# Каталог описания зон
DNS	:= $(WRK)Rdns.dns	# Файл актуальных DNS записей
HTM	:= $(WRK)Rdns.htm	# Таблица объектов
LOG	:= $(WRK)Rdns.log	# Файл протокола тестирования
LST	:= $(WRK)Rdns.lst	# Перечень мастер-зон в формате BIND
OPT	:= -t $(HTM)		# При актуализации DNS, строим таблицу 
TAR 	:= Rdns-$(VER).tar.xz	# Дистрибутивный архив
#TMP	:= $(WRK)Rdns.tmp	# Каталог для автотеста
TST	:= Rdns.tst		# Сценарий автотеста
#UPD	:= -u			# Ключ актуализации DNS записей

.PHONY:	bind clean dist help html list sync test

bind:	$(DNS)

clean:
	@rm -rf $(DIR) $(DNS) $(HTM) $(LOG) $(LST) $(TAR) $(TMP)

dist:
	@tar -caf $(TAR) Makefile README $(BIN) $(CGI) $(CHK) $(TST)

help:
	@echo "  Доступные цели (по умолчанию - bind):";\
	[ -z "$(OPT)" ] && D= || D=" и таблицу объектов '$(strip $(HTM))'";\
	S=", сверить DNS записи";\
	echo "bind  - Создать '$(strip $(DNS))'$$D$$S";\
	echo "clean - Удалить целевые файлы и каталоги";\
	echo "dist  - Создать дистрибутивный архив '$(strip $(TAR))'";\
	echo "help  - Вывести справку по целям";\
	echo "html  - Создать таблицу объектов '$(strip $(HTM))'";\
	echo "list  - Создать список обслуживаемых зон '$(strip $(LST))'";\
	echo "sync  - Получить зоны с NS сервера в '$(strip $(DNS))'$$S";\
	echo "test  - Выполнить автотест работоспособности '$(strip $(TST))'";\
	echo "zone  - Создать файлы описания зон в каталоге '$(strip $(DIR))'"

html:	$(HTM)

list:	$(LST)

sync:	$(CFG)
	@$(SHELL) ./$(BIN) -x -c $(DNS) $(OPT) $^

test:	$(TST)
	@T=$(TMP); $(SHELL) ./$(CHK) -l $(LOG) -r $(BIN) $${T:+-t $(TMP)} $^

zone:	$(DIR)

$(DIR):	$(CFG)
	@mkdir -p $(DIR); $(SHELL) ./$(BIN) -d $(DIR) $^

$(DNS):	$(CFG)
	@$(SHELL) ./$(BIN) $(UPD) -c $(DNS) $(OPT) $^

$(HTM): $(CFG)
	@$(SHELL) ./$(BIN) -t $(HTM) $^

$(LST):	$(CFG)
	@$(SHELL) ./$(BIN) -l $(LST) $^

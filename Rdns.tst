#
#	@(#) Rdns.tst V3.0 (C) 2010-2023 by Roman Oreshnikov
#
CFG=	# Имя текущего входного файла
#
# Подготовительные действия
#
Cat() { echo "$ cat $@"; cat "$@"; }
Diff() { echo "$ diff -u $@"; diff -u "$@"; }
Cfg() {
	[ $# = 2 ] && shift && CFG=Test.cfg || CFG=Test-$NUM.cfg
	echo "; Тестовый файл $CFG$@" >$CFG
	sed = $CFG | sed 'N;s/^/     /;s/ *\(.\{5,\}\)\n/\1 /'
}
export CONTENT_TYPE='multipart/form-data; boundary=---------------------------7e713d161040c'
Ask() {
	[ $# = 0 ] && echo || echo '-----------------------------7e713d161040c
Content-Disposition: form-data; name="col"

'"$1"'
-----------------------------7e713d161040c
Content-Disposition: form-data; name="ask"

'"$2"'
-----------------------------7e713d161040c--'
}
export PATH=.:$PATH
#
# Собственно тесты
#
Tst 0:19	Получение справки
	Run -h

Tst 1:2		Входной файл не задан
	Run

Tst 1:2		Входной файл задан, но отсутствует
	Run NoFile

Tst 1:3		Неизвестный ключ запуска
	Run -X

Tst 1:2		Недопустимый параметр ключа запуска
	Run -l/

Tst 1:2		Дублирование параметра ключа запуска
	Run -l a -l b

Tst 1:2		Дублирование простого ключа запуска
	Run -xx

Tst 1:36	Проверка \$ORIGIN
	Cfg '
$ORIGIN		; пропущено значение
$ORIGIN . .	; допустимо только одно значение
$ORIGIN my.dom.	# примечание в строке начинается с ;
$ORIGIN ..	; корневой домен содержит единственную точку
$ORIGIN .z	; домен не может начинаться с .
$ORIGIN @.	; @ заменяет текущий домен, а он уже завершен .
$ORIGIN a--b.c.	; двойной минус запрещен
$ORIGIN a.-b.	; минус запрещен в начале доменного имени
$ORIGIN a-.d.	; минус запрещен в конце доменного имени
$ORIGIN	localhost.my.domain.	; Ok
; ниже превышение длины доменного имени
$ORIGIN aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
; далее набираем длинное имя
$ORIGIN very-very-very-very-long-domain-name	; допустимый домен
$ORIGIN very-very-very-very-long-domain-name	; ...
$ORIGIN very-very-very-very-long-domain-name	; ...
$ORIGIN very-very-very-very-long-domain-name	; ...
$ORIGIN very-very-very-very-long-domain-name	; ...
$ORIGIN very-very-very-long-domain-name		; ...
$ORIGIN very-very-very-long-domain-name		; ...
$ORIGIN domain	; превышение суммарной длины домена'
	Run $CFG

Tst 1:20	Проверка \$TTL
	Cfg '
$TTL		; пропущено значение
$TTL	10 0	; допустимо только одно значение
$TTL	xx	; требуется число
$TTL	10m	; суффиксы не поддерживаются
$TTL	0100	; число не может начинаться с 0
$TTL	0	; 0 не допустим
$TTL	10	; очень маленькое значение
$TTL	9999999	; слишком большое значение'
	Run $CFG

Tst 1:37	Проверка .Zone
	Cfg '
.Zone				; пропущено значение
.Zone	-			; недопустимое доменное имя
.Zone	.			; зарезервированная зона
.Zone	localhost.my.		; localhost зарезервирован
.Zone	10.in-addr.arpa.	; зарезервированная зона
.Zone	my.domain. ns-		; недопустимое имя NS сервера
.Zone	my.domain.		; уже зарегистрирована
.Zone	1.domain. ns ns		; дубликат NS
.Zone	new.domain. ns		; Ok
.Zone	11/			; недопустимая битовая маска
.Zone	11/x			; недопустимая битовая маска
.Zone	11//8			; недопустимая битовая маска
.Zone	11/2			; маленькая битовая маска
.Zone	11/25			; Ok
.Zone	12/24	localhost	; недопустимое имя NS сервера
.Zone	13/24	2.in-addr.arpa.	; недопустимое имя NS сервера
.Zone	10/24	1.1.1.		; Ok
.Zone	10.0/24	ns		; уже зарегистрирована'
	Run $CFG

Tst 1:24	Проверка стандартных DNS RR
	Cfg '
a-		; недопустимое доменное имя
a 0		; недопустимое значение для ttl
a 100		; маленькое значение для ttl
a 300	IN	; неформат
a IN	aaaa	; неизвестный тип DNS записи
a AAAA		; не поддерживается
a 300 IN NS	; не поддерживается
a IN	SOA	; не поддерживается
abc	SRV	; не поддерживается
def	TXT	; не поддерживается'
	Run $CFG

Tst 1:22	Проверка А RR
	Cfg '
$ORIGIN	my.domain.	; Ok
.Zone @			; Ok
.Zone	192.168/16	; Ok
a A			; неформат
a- A 1			; недопустимое доменное имя
a A 1			; недопустимый IP
a A 0.0.0.0		; IP в зарезервированной зоне
a A 10.0.0.1		; IP в незарегистрированной зоне
a. A	192.168.0.2	; Имя в незарегистрированной зоне
localhost A 127.0.0.1	; localhost зарезервирован
a A 192.168.0.1		; Ok'
	Run $CFG

Tst 1:23	Проверка CNAME RR
	Cfg '
$ORIGIN	my.domain.	; Ok
.Zone @			; Ok
.Zone	192.168/16	; Ok
a CNAME			; неформат
a CNAME	-		; недопустимое доменное имя
a CNAME	b		; отсутствует IP у целевого домена
a A	192.168.0.1 	; Ok
b CNAME	a		; Ok
a CNAME	b	 	; имя уже зарегистрировано
c CNAME	b		; целевой домен тоже CNAME
d CNAME	localhost	; localhost зарезервирован
d CNAME	1.in-addr.arpa.	; недопустимое доменное имя'
	Run $CFG

Tst 1:31	Проверка MX RR
	Cfg '
$ORIGIN	my.domain.	; Ok
.Zone	@		; Ok
.Zone	192.168/16	; Ok
a MX	0		; неформат
a MX 0	-		; недопустимое доменное имя
168.192.in-addr.arpa. MX 0 @ ; недопустимое доменное имя
a MX 00	b		; недопустимый приоритет
a MX 65536 b		; недопустимый приоритет
a MX 0	b		; отсутствует IP у целевого домена
b A	192.168.0.1	; Ok
c A	192.168.0.2	; Ok
a MX 0	b		; Ok
a MX 0	c		; повтор приоритета
a MX 10	c		; Ok
a MX 10	c		; повторная запись
a MX 15	c		; повтор целевого домена
a MX 20	localhost	; localhost зарезервирован'
	Run $CFG

Tst 1:25	Проверка PTR RR
	Cfg '
$ORIGIN	my.domain.	; Ok
.Zone @			; Ok
.Zone	192.168/16	; Ok
a PTR			; неформат
a PTR b			; a - не реверсный IP
$ORIGIN in-addr.arpa.	; Ok
1.1.1.10 PTR a		; недопустимое доменное имя
0.0.0.0 PTR a.		; IP в зарезервированном блоке
1.0.0.127 PTR	a.	; IP в зарезервированном блоке
1.0.0.10 PTR a.		; IP зона не зарегистрирована
1.0.168.192 PTR a.	; Ok
1.0.168.192 PTR b.	; дубликат
2.0.168.192 PTR localhost.my.	;localhost зарезервирован'
	Run $CFG

Tst 1:28	Регистрация домена с прямым и обратным IP адресом
	Cfg '
$ORIGIN	my.domain.	; Ok
.Zone @			; Ok
.Zone 10/8		; Ok
a-			; недопустимое доменное имя
a 1.2.3.256		; не IP
localhost 127.0.0.1	; зарезервированный доменое имя
a 127.0.0.1		; IP в зарезервированном блоке
b 192.168.0.1		; IP зона не зарегистрирована
a 10.1.1.1 2 3		; 3-й параметр не IP
c 10.1.2.3 10.4.5.6	; Ok
c 10.0.0.10		; домен зарегистрирован с другим IP
c1 10.0.0.1 0000	; недопустимый счетчик повтора
c2 10.0.0.2 1		; Ok
c3 10.0.0.3 2		; уже зарегистрирован
@ 10.10.10.10		; Ok'
	Run $CFG

Tst 1:17	Проверка порядка объявления зон и нахождения NS без IP
	Cfg '
$ORIGIN my.domain.			; Ok
.Zone @		ns ns1			; ns1 без IP
.Zone 10/8	ns ns1			; ns1 без IP
.Zone slave	ns.slave ns ns.null.	; ns.slave без IP
.Zone 10.10/16	ns.slave ns ns.null.	; ns.slave без IP
.Zone bad.null.	ns.null.		; объявлена раньше родительской
.Zone null.	ns.null.		; Ok
.Zone	192.168/16 ns.null.		; Ok
ns	10.0.0.1			; Ok'
	Run $CFG

Tst 1:30	Проверка ошибок объявления объектов и использования кроссовых соединений
	Cfg '
	a L1 aa:aa:bb:bb:cc:cc #1	; Ok
	a - aa:aa:bb:bb:cc:cc #1	; дубликат
	b L1 dd:dd:ee:ee:ff:ff #2	; Ok
	c L1 ab:cd:ef:01:23:45 #3	; линия уже занята
	d L123 aa:aa:bb:bb:cc:cc #4	; повтор мас-адреса
	e L123 01:23:45:67:89:1a #1	; повтор инвентарного №
	f 12:34:56:78:9A:BC 12:34:56:78:9a:bc ; повтор задания мас-адреса
	g ? 12:34:56:78:9a:bd #5 #6	; повтор задания инвентарного №
	=			; мало параметров
	= L2 /			; мало параметров
	= ? -			; зарезервированные имена
	= L2 L123		; линия уже занята
	= L5 L5			; одинаковые линии
	= L0 L5 L2 /cross	; Ok
	= L3 L4			; Ok'
	Run $CFG

Tst 1:27	Проверка ошибок объявления ссылок
	Cfg '
	bad	?	; Ok
	sw/0 -	@-	; ошибка именования ссылки
	sw/1	@a.	; ...
	sw/2	@a-.b	; ...
	sw/3	@/	; ...
	sw/4	@/G1/1	; ...
	sw/5	@/5	; ссылка сама на себя
	sw/6	@/1	; некорректный тип соединения
	sw/7	@BAD	; объект уже объявлен
	sw/8	@/0 @/8	; вторая ссылка
	sw1/V0	@Switch		; Ok
	sw1/Po1	- Trunk		; Ok
	sw1/Gi1	L1 @/Po1	; Ok
	sw1/Gi2	L2 @/Po1	; Ok'
	Run $CFG

Tst 0:137	Проверка полного файла конфигурации
	Cfg - '
##### Управление DNS записями:
# Обслуживаемые зоны
$ORIGIN	my.domain.
$TTL	10800		; 3h
.Zone	@		ns ns.domain.
.Zone	10.10/16	ns ns.domain.
.Zone	local		ns		; Внутренний домен
# Делегированные зоны
.Zone	slave		ns.slave ns	; Подчиненный домен
.Zone	10.10.128/23	ns.slave ns	; ...
# IP адреса внешних NS, если их имена в поддоменах обслуживаемых зон
ns.slave A	10.10.128.1
# Магистральный канал Центр-ЛВС 10.10.0.0/30
;gw-main-lvs	10.10.0.1	; Центр
gw-lvs-main	10.10.0.2	; ЛВС
# Магистральный канал ЛВС-Филиал 10.10.0.4/30
gw-lvs-slave	10.10.0.5	; ЛВС
;gw-slave-lvs	10.10.0.6	; Филиал
# Vlan1: Сегмент управления ЛВС 10.10.1.0/24
gw01		10.10.1.1
sw		10.10.1.2
ups		10.10.1.3
ns		10.10.1.10
ilo1		10.10.1.11
ilo2		10.10.1.12
ilo3		10.10.1.13
ilo4		10.10.1.14
ilo5		10.10.1.15
# Vlan2: Серверный сегмент 10.10.2.0/24
gw02		10.10.2.1
mail		10.10.2.2
fs		10.10.2.3
cluster		10.10.2.10
node01		10.10.2.11
node02		10.10.2.12
# Vlan3: Клиентский сегмент 10.10.3.0/24
gw03		10.10.3.1
boss		10.10.3.2
arm		10.10.3.3
printer		10.10.3.4
mfu		10.10.3.5
dhcp		10.10.3.10
dhcp32		10.10.3.32 16	; DHCP клиенты
# Специальные DNS записи
@		MX	0 mail.my.domain.
@		A	10.10.2.11
@		A	10.10.2.12
www		CNAME	fs
##### Учет оборудования и подключений:
# Кроссовые соединения
=	V1-1	V3-1
=	V1-2	V3-2
=	L13	V1-3	L31	/Проброс порта
# Телекоммуникационное оборудование
switch		-	#1234	/Коммутатор ЛВС
switch/Po1	-	Vlan2
switch/G01	E-gw/2	Trunk
switch/G02	E-ups	Vlan1
switch/G03	E-s01/1	Vlan2
switch/G04	E-s01/2	Vlan1
switch/G05	E-s01/M	Vlan1
switch/G06	E-s02/1		@/Po1
switch/G07	E-s02/2		@/Po1
switch/G08	E-s02/M	Vlan1
switch/G09	E-s03/1	Vlan2
switch/G11	E-s03/2		disable
switch/G12	E-s03/M	Vlan1
switch/G13	E-s04/1	Vlan2
switch/G14	E-s04/2		disable
switch/G15	E-s04/M	Vlan1
switch/G16	E-s05/1		disable
switch/G17	E-s05/2	Vlan3
switch/G18	E-s05/M	Vlan1
switch/G19	?		disable
switch/G20	?		disable
switch/G21	L10	Vlan3 PortSecurity
switch/G22	L11	Vlan3 PortSecurity
switch/G23	L20	Vlan3 PortSecurity
switch/G24	L22	Vlan3 PortSecurity
switch/Vlan1	-	@sw
#
router		-	#12345 /Маршрутизатор ЛВС
router/G1	V3-1	00:01:23:45:67:89	@gw-lvs-main	/ ЛВС-Центр
router/G2	E-gw/2	00:01:23:45:67:89	Trunk		/ ЛВС
router/G3	V3-2	00:01:23:45:67:89	@gw-lvs-slave	/ ЛВС-Филиал
router/Vlan1	-	00:01:23:45:67:89	@gw01
router/Vlan2	-	00:01:23:45:67:89	@gw02
router/Vlan3	-	00:01:23:45:67:89	@gw03
#
ups		E-ups
#
fo2e-1		-	#A-32-1	/Конвертер FO<->Ethernet
fo2e-1/F	V1-1
fo2e-1/L	FiberOpticCable01
#
fo2e-2		-	#A-32-2	/Конвертер FO<->Ethernet
fo2e-2/F	V1-2
fo2e-2/L	FiberOpticCable02
# Серверное оборудование
server01	-	#123456	/ns+mail
server01/G1	E-s01/1	11:01:23:45:67:89 @ns.my
server01/G2	E-s01/2	11:01:23:45:67:8a @mail
server01/M	E-s01/M	11:01:23:45:67:8b @ilo1
#
server02	-	#123457	/Файловый сервер
server02/Bond	-	@fs
server02/G1	E-s02/1	12:01:23:45:67:aa @/Bond
server02/G2	E-s02/2	12:01:23:45:67:ab @/Bond
server02/M	E-s02/M	12:01:23:45:67:ac @ilo2
#
server03	-	#123458	/1 узел кластера
server03/G1	E-s03/1	13:01:23:45:67:1a @Cluster @node01
server03/G2	E-s03/2	13:01:23:45:67:1b
server03/M	E-s03/M	13:01:23:45:67:1c @ilo3
#
server04	-	#123459 /2 узел кластера
server04/G1	E-s04/1	14:01:23:45:67:77 @Cluster @node02
server04/G2	E-s04/2	14:01:23:45:67:78
server04/M	E-s04/M	14:01:23:45:67:79 @ilo4
#
server05	-	#123460 /DHCP сервер
server05/G1	E-s05/1	15:01:23:45:67:31
server05/G2	E-s05/2	15:01:23:45:67:32 @DHCP
server05/M	E-s05/M	15:01:23:45:67:33 @ilo5
# Клиентское оборудование
arm		L10	aa:bb:cc:dd:ee:ff #567
laptop		L20	bb:aa:cc:dd:ee:bb #345	@Boss
mfu		L11	cc:aa:bb:cc:dd:cc #33-18
printer		L22	dd:ee:ff:aa:bb:dd #66'
	Run -c Rdns.dns -l Rdns.lst -t Rdns.htm $CFG

Tst 0:102	Проверка файла с актуальными DNS записями
	Cat Rdns.dns
	cp Rdns.dns Rdns.dig

Tst 0:28	Проверка файла со списком зон
	Cat Rdns.lst

Tst 0:141	Проверка файлов описания зон
	Run -d . $CFG
	for F in *.arpa *domain; do Cat "$F"; echo; done

Tst 0:89	Проверка файла с актуальной таблицей объектов
	Cat Rdns.htm

Tst 1:5	Проверка обнаружения ошибки в файле актуальных DNS записей
	echo "Bad record" >>Rdns.dns
	Run -c Rdns.dns $CFG

Tst 1:12	Проверка обнаружения ошибки загрузки DNS записей с NS сервера
	echo '#!/bin/sh
	echo
	echo "; <<>> DiG emulator <<>> $#"
	echo "; (1 server found)"
	echo ";; global options: +cmd"
	echo "; Transfer failed."' >dig
	chmod 755 dig
	Cat dig
	Run -x -c Rdns.dns $CFG

Tst 0:22	Проверка загрузки DNS записей с NS сервера
	echo '#!/bin/sh
	SOA="$3 10800 IN SOA ${2#@} root.${2#@} 1 86400 43200 604800 10800"
	echo
	echo "; <<>> DiG emulator <<>> $#"
	echo "; (1 server found)"
	echo ";; global options: +cmd"
	echo "$SOA"
	sed -n "/^zone $3/,/^zone/{/^zone/!p}" Rdns.dig
	echo "$SOA"
	echo ";; Query time: 0 msec"
	echo ";; SERVER: 127.0.0.1#53(localhost) (TCP)"
	echo ";; WHEN: $(date)"
	echo ";; XFR size: 0 records (messages 1, bytes 1)"
	echo' >dig
	Cat dig
	Run -x -c Rdns.dns $CFG

Tst 1:13	Смена IP адреса для хоста в файле конфигурации
	sed 's/10.10.3.3$/10.10.3.13/' $CFG >$CFG.new
	echo "$ sed 's/10.10.3.3$/10.10.3.13/' $CFG >$CFG.new"
	Diff $CFG $CFG.new

Tst 1:10	Проверка обнаружений обновлений при смене IP адреса
	Run -c Rdns.dns $CFG.new

Tst 1:14	Проверка обнаружения ошибки отправки обновлений DNS на NS сервер
	echo '#!/bin/sh
	echo "; Communication with 127.0.0.1#53 failed: operation canceled"' \
	>nsupdate
	chmod 755 nsupdate
	Cat nsupdate
	Run -u -c Rdns.dns $CFG.new

Tst 0:17	Проверка отправки обновлений DNS на NS сервер
	echo '#!/bin/sh
	while read R; do [ "x$R" = "xanswer" ] && break; done
	[ -n "$R" ] && echo "Answer:" ||
	echo "; Communication with 127.0.0.1#53 failed: operation canceled"' \
	>nsupdate
	Cat nsupdate
	Run -u -c Rdns.dns $CFG.new

Tst 1:24	Проверка наличия различий в файле актуальных DNS записей
        Diff Rdns.dig Rdns.dns

Tst 0:43	Проверка работоспособности Rdns.cgi
	RUN=$RUN.cgi
	Ask | Run

Tst 0:22	Проверка отработки поискового запроса в поле линии
	Ask 1 "a" | Run

Tst 0:25	Проверка отработки поискового запроса в поле DNS имени
	Ask 3 "^i" | Run

Tst 0:26	Проверка отработки поискового запроса в поле IP адреса
	Ask 4 "10.10.2" | Run

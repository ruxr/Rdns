#!/bin/sh
echo	'Content-Type: text/html; charset=utf-8

<!DOCTYPE html>
<HEAD>
<TITLE>Rdns</TITLE>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=utf-8"
<META HTTP-EQUIV="Pragma" CONTENT="no-cache" />
</HEAD>
<BODY>
<H2 ALIGN="center">Таблица подключений</H2>'
awk '
{
	if($0 ~ Bnd) getline; else next
	if($0 ~ Str) {
		sub(Str, "")
		gsub(/"/, "")
		sub(/\s*$/, "")
		n = $0; getline
	} else next
	if($0 ~ /^\s*$/) {
		getline
		sub(/^\s*/, "")
		sub(/\s*$/, "")
		I[n] = $0
	}
}
function Htm(s) {
	gsub(/&/, "\\&amp;", s)
	gsub(/</, "\\&lt;", s)
	gsub(/>/, "\\&gt;", s)
	return s
}
function Opt(i, t, v) { T[i] = t; V[i] = v }
function Val(s) { gsub(/"/, "\\&quot;", s); return s }
function Chk(s) {
	if(s == "") return 1
        if(s !~ /[\\{}()\[\]]/) return 0
	gsub(/\\./, " ", s)
	if(s ~ /\\/) return 1
	gsub(/\[[^\]]+\]/, " ", s)
	if(s ~ /[\[\]]/) return 1
	gsub(/\{[0-9]*,?[0-9]*\}/, " ", s)
	if(s ~ /[\{\}]/) return 1
	while(gsub(/\([^\)]+\)/, " ", s));
	if(s ~ /[\(\)]/) return 1
	return 0
}
BEGIN {
	Opt(0, "Сетевое имя устройства", "Имя")
	Opt(1, "Сопряженное устройство", "Подключение")
	Opt(2, "Маркировка порта СКС или соединительного кабеля", "Линия")
	Opt(3, "IP адрес устройства", "IP адрес")
	Opt(4, "MAC адрес устройства", "MAC адрес")
	Opt(5, "Параметры подключения", "Параметры")
	Opt(6, "Время подключения", "Время")
	Opt(7, "Характеристики устройства (инвентарный №)", "Характеристики")
	if((Bnd = ENVIRON["CONTENT_TYPE"]) != "") {
		Str="^multipart/form-data; boundary="
		sub(Str, "", Bnd)
		Str="^Content-Disposition: form-data; name="
	}
}
END {
	Col = strtonum(" " I["col"])
	if(Col > 7 || Col < 0) Col = 0
	Ask = s = I["ask"]
	gsub(/\\[\\\[\]]/, " ", n)
	if(s ~ /\[[^\]]*$/ || s ~ /\[\]/) Ask = ""
	S[Col] = "SELECTED"
	print	"<FORM METHOD=\"post\" ENCTYPE=\"multipart/form-data\"",
		"ACTION=\"/cgi-bin/Rdns.cgi\">\n" \
		"<SELECT NAME=\"col\" TITLE=\"Поле поиска\">"
	for(i in T) print "<OPTION VALUE=\"" i "\" TITLE=\"" T[i] "\"",
		 S[i] ">" V[i] "</OPTION>"
	print	"</SELECT>" \
		"<INPUT TYPE=\"text\" NAME=\"ask\" VALUE=\"" \
			Val(Ask) "\" TITLE=\"Шаблон поиска\"",
			"PLACEHOLDER=\"Что ищем?\" />" \
		"<INPUT TYPE=\"submit\" NAME=\"go\" VALUE=\"Искать\"",
			"TITLE=\"Выполнить поиск\" />" \
		"</FORM>\n<HR />"
	if(Chk(Ask)) exit 1
	print	"<TABLE BORDER=\"1\" CELLSPACING=\"0\" CELLPADING=\"0\">\n<TR>"
	for(i in T) print "<TH TITLE=\"" T[i] "\">" V[i]
	i = 0; n = Col + 2
	while((getline <"/home/noc/var/dns/dns.htm") > 0) {
		if($0 !~ /^<TR><TD>/) continue
		split($0, a, /<TD>/)
		if(a[n] ~ Ask) {
			D[++i] = $0
			if(Col) R[i] = sprintf("%s\n %05d", a[n], i)
		}
	}
	if(Col) {
		asort(R)
		for(i in R) {
			i = R[i]
			sub(/^.*\n/, "", i)
			i = strtonum(i)
			print D[i]
		}
	} else for(i in D) print D[i]
	print	"</TABLE>"
}'
[ $? = 0 ] || echo '
<p>Шаблон поиска представляет собой образец (набор образцов),
на основании совпадения с которым заданного поля, выводятся строки таблицы.
<p>Образец строится из элементов, для разделения образцов используется символ |.
<table>
<tr><td colspan=2>Элементы:
<tr><td><td>- любой алфавитно-цифровой символ (специальные символы:
. ? * + \ ( ) [ ] { } | - должны предваряться символом \)
<tr><td>.<td>- любой символ из доступных
<tr><td>[ ]<td>- символ из набора перечисленных, если набор
начинается с ^, то любой символ, за исключением перечисленных; два символа через - задают диапазон перечисления
<tr><td>( )<td>- последовательность элементов
<tr><td><br><td>
<tr><td colspan=2>Повторы:
<tr><td>?<td>- предыдущий элемент может встретиться 0 или 1 раз
<tr><td>*<td>- предыдущий элемент может встретиться 0 или более раз
<tr><td>+<td>- предыдущий элемент должен встретиться 1 или более раз
<tr><td>{n}<td>- предыдущий элемент должен встретиться ровно n раз
<tr><td>{n,}<td>- предыдущий элемент должен встретиться n раз или более
<tr><td>{,m}<td>- предыдущий элемент может встретиться не более m раз
<tr><td>{n,m}<td>- предыдущий элемент должен встретиться как минимум n,
но не более m раз
<tr><td><br><td>
<tr><td colspan=2>Якоря:
<tr><td>^<td>- в начале образца, обозначает привязку к началу поля
<tr><td>$<td>- в конце образца, обозначает привязку к концу поля
</table>'
echo	'<HR />
<P STYLE="text-align:right;font:italic 70% small-caption;">
@(#) Rdns.cgi V1.23 © 2015-2022 by Roman Oreshnikov</P>
</BODY>
</HTML>'

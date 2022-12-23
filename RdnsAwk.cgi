#!/bin/sh
awk '
function Htm(s) {
	gsub(/&/, "&amp;", s)
	gsub(/</, "&lt;", s)
	gsub(/>/, "&gt;", s)
	return s
}
function Opt(i, t, v) { T[i] = t; V[i] = v }
function Val(s) { s = Htm(s); gsub(/"/, "&quote", s); return s }
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
	print	"Content-Type: text/html; charset=utf-8\n\n" \
		"<!DOCTYPE html>\n<HEAD>\n<TITLE>Rdns</TITLE>\n" \
		"<META HTTP-EQUIV=\"Content-Language\" CONTENT=\"ru\" />\n" \
		"<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html;",
		"charset=utf-8\" />\n" \
		"<META HTTP-EQUIV=\"Pragma\" CONTENT=\"no-cache\" />\n" \
		"</HEAD>\n<BODY>\n" \
		"<H2 ALIGN=\"center\">Таблица подключений</H2>\n" \
		"<FORM METHOD=\"post\" ENCTYPE=\"multipart/form-data\"",
		"ACTION=\"/cgi-bin/RdnsAwk.cgi\">" \
		"<SELECT NAME=\"col\" TITLE=\"Поле поиска\">"
}
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
END {
	Col = strtonum(" " I["col"])
	if(Col > 7 || Col < 0) Col = 0
	Ask = s = I["ask"]
	gsub(/\\[\\\[\]]/, " ", n)
	if(s ~ /\[[^\]]*$/ || s ~ /\[\]/) Ask = ""
	S[Col] = "SELECTED"
	for(i in T) print "<OPTION VALUE=\"" i "\" TITLE=\"" T[i] "\"",
		 S[i] ">" V[i] "</OPTION>"
	print	"</SELECT>" \
		"<INPUT TYPE=\"text\" NAME=\"ask\" VALUE=\"" \
			Val(Ask) "\" TITLE=\"Шаблон поиска\" />" \
		"<INPUT TYPE=\"submit\" NAME=\"go\" VALUE=\"Искать\"",
			"TITLE=\"Выполнить поиск\" />" \
		"</FORM>"
	if(Ask != "") {
		print	"<HR />\n<TABLE BORDER=\"1\" CELLSPACING=\"0\"",
			"CELLPADING=\"0\">\n<TR>"
		for(i in T) print "<TH TITLE=\"" T[i] "\">" V[i]
		i = 0; n = Col + 2
		while(getline <"/home/noc/var/dns/dns.htm") {
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
		print "</TABLE>"
	}
	print	"<HR />\n" \
		"<P ALIGN=\"right\" STYLE=\"font:italic 70% small-caption;\">" \
		"@(#) Rdns.cgi V1.22 © 2015-2022 by Roman Oreshnikov</P>\n" \
		"</BODY>\n</HTML>"
}'

#!/bin/sh
export LANG=C
awk '
{
	if($0 ~ Bnd) getline
	else next
	if($0 !~ Str) next
	sub(Str, "")
	gsub(/"/, "")
	sub(/\s*$/, "")
	n = $0
	getline
	if($0 !~ /^\s*$/) next
	getline
	sub(/^\s*/, "")
	sub(/\s*$/, "")
	if(n == "col") { if($0 ~ /^[0-9]$/) N = $0; next }
	else if($0 ~ /[\\{}()\[\]]/) {
		s = $0; gsub(/\\./, " ", s); if(s ~ /\\/) next
		gsub(/\[[^\]]+\]/, " ", s); if(s ~ /[\[\]]/) next
		gsub(/\{[0-9]*,?[0-9]*\}/, " ", s); if(s ~ /[\{\}]/) next
		while(gsub(/\([^\)]+\)/, " ", s));
		if(s ~ /[\(\)]/) next
	}
	S = A = $0
	gsub(/"/, "\\&quot;", A)
}
function cmp_domain(i1, v1, i2, v2, a, b) {
	sub(/[\n<].*/, "", i1)
	sub(/[\n<].*/, "", i2)
	i1 = split(i1, a, /\./)
	i2 = split(i2, b, /\./)
	for(;;) {
		if(a[i1] > b[i2]) return 1
		if(a[i1--] < b[i2--]) return -1
		if(!i1 && !i2) return 0
		if(!i1) return -1
		if(!i2) return 1
	}
}
function cmp_ip(i1, v1, i2, v2, a, b) {
	i1 = split(i1, a, /[.\n]/)
	i2 = split(i2, b, /[.\n]/)
	for(i1 = 0; i1++ < 4;) {
		if(a[i1] > b[i1]) return 1
		if(a[i1] < b[i1]) return -1
	}
}
BEGIN {
	N = 0
	if(Bnd = ENVIRON["CONTENT_TYPE"]) {
		Str="^multipart/form-data; boundary="; sub(Str, "", Bnd)
		Str="^Content-Disposition: form-data; name="
	}
}
END {
	F = "Rdns.htm"
	if((s = ENVIRON["DOCUMENT_ROOT"]) != "") F = s "/" F
	print "Content-Type: text/html; charset=utf-8\n"
	while((getline <F) > 0)
		if($0 ~ /^<TR><TD>/) {
			if(S == "") continue
			split($0, a, /<TD>/); if(a[N] !~ S) continue
			D[++i] = $0; R[sprintf("%s\n%7d", a[N], i)]
		} else if($0 ~ /^<TR><TH/) {
			n = 0; s = ""
			while(match($0, /(<[^>]*>)([^<]*)(.*)/, a)) {
				$0 = a[3]; if(!s) s = a[1]
				else s = s a[1] "<INPUT NAME=\"col\" "\
					"TYPE=\"radio\" VALUE=\"" n "\""\
					(n++ == N ? " CHECKED" : "") ">" a[2]
			}
			print s; N += 2
		} else if($0 ~ /^<H2 /) {
			sub(/<\/H2>/, ""); print "<FORM METHOD=\"post\"",
				"ENCTYPE=\"multipart/form-data\">\n" $0 "<BR>" \
				"<INPUT NAME=\"ask\" TITLE=\"Шаблон поиска\"",
				"PLACEHOLDER=\"Что ищем?\" VALUE=\"" A \
				"\" onChange=\"this.form.submit()\"></H2>"
		} else if($0 ~ /^<\/TABLE/) break
		else print
	if(N == 2) for(i in D) print D[i]
	else {
		if(N == 5) asorti(R, a, "cmp_domain")
		else if(N == 6) asorti(R, a, "cmp_ip")
		else asorti(R, a)
		for(i in a) { sub(/^.*\n\s*/, "", a[i]); print D[a[i]] }
	}
	print $0 "\n</FORM>"
	if(S == "") print "<P>Шаблон поиска представляет собой образец (набор",
		"образцов), на основании совпадения с которым заданного поля,",
		"выводятся строки таблицы.\n<p>Образец строится из элементов,",
		"для разделения образцов используется символ «<B>|</B>».\n"\
		"<TABLE>\n<TR><TD COLSPAN=\"2\">Элементы:\n<TR><TD><TD>-",
		"любой алфавитно-цифровой символ (специальные символы: «<B>.",
		"? * + \\ ( ) [ ] { } |</B>» - должны предваряться символом",
		"«<B>\\</B>»)\n<TR><TD><B>.</B><TD>- любой символ из",
		"доступных\n<TR><TD STYLE=\"vertical-align:top\"><B>[]</B>"\
		"<TD>- символ из набора перечисленных, если набор начинается с",
		"«<B>^</B>», то любой символ, за исключением перечисленных;"\
		"<BR>два символа через «<B>-</B>» задают диапазон перечисления",
		"(например: «<B>[5-7]</B>» определяет символ «<B>5</B>» или",
		"«<B>6</B>» или «<B>7</B>»)\n<TR><TD><B>()</B><TD>-",
		"группировка элементов\n<TR><TD><BR><TD>\n<TR><TD",
		"COLSPAN=\"2\">Повторы:\n<TR><TD><B>?</B><TD>- элемент может",
		"встретиться <B>0</B> или <B>1</B> раз\n<TR><TD><B>*</B><TD>-",
		"элемент может встретиться <B>0</B> или более раз\n<TR><TD>"\
		"<B>+</B><TD>- элемент должен встретиться <B>1</B> или более",
		"раз\n<TR><TD><B>{N}</B><TD>- элемент должен встретиться ровно",
		"<B>N</B> раз\n<TR><TD><B>{N,}</B><TD>- элемент должен",
		"встретиться <B>N</B> раз или более\n<TR><TD><B>{,M}</B><TD>-",
		"элемент может встретиться не более <B>M</B> раз\n<TR><TD>"\
		"<B>{N,M}</B><TD>- элемент должен встретиться как минимум",
		"<B>N</B>, но не более <B>M</B> раз\n<TR><TD><BR><TD>\n<TR><TD",
		"COLSPAN=\"2\">Якоря:\n<TR><TD><B>^</B><TD>- в начале образца,",
		"обозначает привязку к началу поля\n<TR><TD><B>$</B><TD>- в",
		"конце образца, обозначает привязку к концу поля\n</TABLE>\n"\
		"<HR>"
	print "<P STYLE=\"text-align:right;font:italic 70% small-caption;\">"\
		"@(#) Rdns.cgi V3.1 © 2015-2023 by Roman Oreshnikov</P>"
	while((getline <F) >0) print
}'

#!/usr/bin/perl
#
my $SIG = '
	@(#) Rdns.cgi V2.4 (C) 2010-2019 by Roman Oreshnikov
';
#
#	CGI-скрипт поиска по данным сформированным Rdns.pl
#
use strict;
use integer;
use warnings;
use DBI;

# Имя SQLite version 3 базы
my $DBNAME = '/home/noc/var/dns/dns.db';

#
# Секция HTML утилит
#
my %t2h = qw/" &quot; < &lt; > &gt; & &amp;/;	# Экранируемые символы
my @X = qw/0 1 2 3 4 5 6 7 8 9 A B C D E F/;	# Шестнадцатиричные цифры

# a $key[, @val] - Сборка атрибута с экранированием значения
sub a { $_ = "@_"; s/([<>"])/$t2h{$1}/g; s/([^ ]+) ?(.*)/$1="$2"/; $_ }

# h @txt - Экранирование строки для использования вне тэгов
sub h { map {defined $_ or $_ = ''} @_; $_ = "@_"; s/([&<>])/$t2h{$1}/g; $_ }

# b @txt - Экранирование блока строк
sub b { h @_; s/\n/<BR \/>/g; $_ }

# x $char - Получить шестнадцатиричный код символа
sub x { my $c = ord $_[0]; '%'. $X[($c >> 4) & 15]. $X[$c & 15] }

# u @url - Экранирование URL
sub u { $_ = "@_"; s/([^!#\$&'()+-;=?-Z_a-z~])/x $1/eg; $_ }

# p @key_val - Сбор и экранирование параметров URL
sub p {
	my($r, $i, $t) = ('', '?');
	foreach $t (@_){
		$_ = $t;
		s/([^a-zA-Z,-: \$()\@_~])/x $1/eg;
		s/ /+/g;
		$r .= $i. $_;
		$i = ($i eq '=') ? '&' : '='
	}
	$r
}

#
# Секция разбора параметров CGI
#
my %CGI;	# GET/POST/COOKIE: name => value

# Set $CGI $pattern - Заполнение %CGI разбором $_
sub Set {
	my($h, $p, @s) = @_;
	s/\+/ /g;
	foreach (split /$p/) {
		foreach (split /=/) {
			s/%([0-9A-Fa-f]{2})/chr hex $1/eg;
			push @s, $_;
			last if $#s
		}
		$_ = shift @s;
		$h->{$_} = @s ? shift @s : ''
	}
}

# Cgi - Разбор параметров запроса
sub Cgi {
	defined ($_ = $ENV{'REQUEST_METHOD'}) or return;
	if($_ eq 'GET') {
		Set \%CGI, '&' if defined ($_ = $ENV{'QUERY_STRING'})
	} elsif($_ eq 'POST' and defined $ENV{'CONTENT_LENGTH'} and
			defined ($_ = $ENV{'CONTENT_TYPE'}) and
			s/^multipart\/form-data; boundary=//) {
		my($k, $v, $s, $f, $m, $n);
		my($b, $c) = ($_, 'Content-Disposition: form-data; name');
		while(<>) {
			if($s and /^\s*$/) {
				$s = undef
			} elsif(/^--\Q$b\E(--)?\s+$/) {
				if(defined $k) {
					$_ = $CGI{$k};
					$CGI{$k} = defined $_ ? "$_\n$v" : $v;
					$k = undef
				}
				$v = $f = undef
			} elsif(defined $f) {
				if(not defined $m) {
					s/^Content-Type: //;
					s/\s+$//;
					($s, $m) = (1, $_)
				}
			} elsif(defined $k) {
				s/\s+$//;
				$v = defined $v ? "$v\n$_": $_
			} elsif(/^$c="([^"]*)"(; filename="([^"]*)")?\s+$/) {
				$k = $1;
				if(defined $2) {
					($f, $m, $n) = (($v = $3), undef, '')
				} else {
					($s, $v) = (1, undef)
				}
			}
		}
	}
	if(defined ($_ = $ENV{'HTTP_COOKIE'})) {
		my %h;
		Set \%h, ';\s+';
		foreach (keys %h) { defined $CGI{$_} or $CGI{$_} = $h{$_} }
	}
}

#
# Секция HTML тэгов
#
# Title [@title] - Атрибут TITLE
sub Title { a 'TITLE', @_ }

# A $href[, $txt[, @title]] - Гиперссылка A
sub A {
	my($h, $v) = @_;
	defined $h and $h ne '' or return '';
	defined $v and $v =~ /\S/ or $v = $h;
	$h = a 'HREF', $h;
	$h .= ' '. Title @_[2..$#_] if defined $_[2];
	"<A $h>". h($v). '</A>'
}

# Input $type, $name, $value[, @attr] - Тэг INPUT
sub Input {
	join ' ', '<INPUT', a('TYPE', shift), a('NAME', shift),
		a('VALUE', shift), @_, '/>'
}

# CheckBox @attr - Поле выбора
sub CheckBox { Input 'checkbox', @_ }

# Submit @attr - Кнопка SUBMIT
sub Submit { Input 'submit', @_ }

# Reset @attr - Кнопка RESET
sub Reset { Input 'reset', @_ }

# Hidden @attr - Теневой параметр HIDDEN
sub Hidden { Input 'hidden', @_ }

# Text @attr - Однострочное поле ввода TEXT
sub Text { Input 'text', @_ }

# Area $name, $value - Многострочное поле ввода TEXTAREA
sub Area { '<TEXTAREA NAME="'. (shift). "\">". h(shift). '</TEXTAREA>' }

# Option $value, $txt, $title[, @attr] - Пункт списка вариантов OPTION
sub Option {
	my($v, $t) = (a('VALUE', shift), h(shift));
	join(' ', '<OPTION', $v, Title(shift), @_). ">$t</OPTION>"
}

# Options $@opt - Список вариантов OPTION
sub Options {
	my($a, $p) = (shift);
	foreach $p (@$a) { push @_, Option @$p }
	@_
}

# Select $name, $@opt[, @attr] - Список вариантов SELECT
sub Select {
	my($n, $o) = (a('NAME', shift), shift);
	join "\n", join(' ', '<SELECT', $n, @_). '>', Options($o), '</SELECT>'
}

# Form @html- Форма ввода данных
sub Form {
	$_ = defined ($_ = $ENV{'SCRIPT_NAME'}) ? u($_) : '';
	'<FORM METHOD="post" ENCTYPE="multipart/form-data" ACTION="'. $_. '">',
	@_, "\n</FORM>\n"
}

# TR @html - Строка таблицы
sub TR { join '', '<TR>', @_, "</TR>\n" }

# TH @html - Ячейка заголовка таблицы
sub TH { map {"<TH>$_</TH>"} @_ }

# TD @html - Ячейка таблицы
sub TD { map {"<TD>$_</TD>"} @_ }

#
# Секция работы с БД
#
my $DB;		# Интерфейс БД
my $DBE;	# Ошибка БД

# DBerr [@txt] - Обработка ошибки и закрытие БД
sub DBerr {
	$DB or return undef;
	$DBE = "Ошибка выполнения «@_» - ". $DB->errstr if @_;
	DBI->disconnect_all();
	$DB = undef
}

# SqlDo @sql - Выполнение простой SQL команды
sub SqlDo { $DB and $DB->do("@_") or DBerr "@_" }

# DBinit - Открытие БД
sub DBinit {
	$DB = DBI->connect("dbi:SQLite:dbname=$DBNAME", '', '',
		{PrintError => 0}) or $DBE = "Ошибка открытия базы $DBNAME";
	$DB
}

# DBend - Завершение работы с БД
sub DBend { DBerr; return $DBE }

# Sql @sql - Выполнение сложной SQL команды
sub Sql {
	my $q;
	$DB and $q = $DB->prepare("@_") and $q->execute() and return $q;
	DBerr "@_"
}

# SqlRow $que - Получить данные
sub SqlRow { return $_[0] ? $_[0]->fetchrow_array() : () }

# SqlTxt @txt - Экранирование кавычек
sub SqlTxt {
	if(($_ = "@_") eq '') { return 'NULL' } else { s/'/''/g; return "'$_'" }
}

#
# Секция выполнения
#
Cgi;

# Поля DB
my @FIL = ('src', 'dst', 'line', 'ip', 'mac', 'opt', 'ts', 'sys');
# Поля поиска
my @TAB = (
	[(0, 'Domain', 'Сетевое имя устройства')]
,	[(1, 'Target','Сопряженное устройство')]
,	[(2, 'Подключение', 'Маркировка порта СКС или соединительного кабеля')]
,	[(3, 'IP адрес', 'IP адрес устройства')]
,	[(4, 'MAC адрес', 'MAC адрес устройства')]
,	[(5, 'Параметры', 'Параметры подключения')]
,	[(6, 'TimeStamp', 'Время подключения')]
,	[(7, 'Устройство', 'Имя устройства (инвентарный №)')]
);

my $ASK = '';	# Шаблон поиска
my $COL = 0;	# № поля поиска
$ASK = $_ if defined ($_ = $CGI{'ask'});
$COL = $_ if defined ($_ = $CGI{'col'}) and /^(0|([1-9]\d*))$/ and $_ <= $#FIL;
push @{$TAB[$COL]}, 'SELECTED';	# Отмечаем выбранную колонку

# Шапка ответа
print	'Content-Language: ru
Content-Type: text/html; charset=utf-8

<!DOCTYPE html>
<HTML LANG="ru">
<HEAD>
<TITLE>Rdns</TITLE>
<META HTTP-EQUIV="Content-Language" CONTENT="ru" />
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=utf-8" />
<META HTTP-EQUIV="Pragma" CONTENT="no-cache" />
</HEAD>
<BODY>
<H2 ALIGN="center">Таблица подключений</H2>
';

# Форма запроса
print	Form Select('col', \@TAB, Title('Поле поиска')),
	Text('ask', $ASK, Title('Шаблон поиска')),
	Submit('go', 'Искать', Title('Выполнить поиск'));

# Собственно ответ
if($ASK ne '' and DBinit) {
	my $q = 'SELECT * FROM db';
	$COL == 0 and $ASK eq '*' or $q = $q .
		" WHERE $FIL[$COL] GLOB ". SqlTxt($ASK). " ORDER BY $FIL[$COL]";
	print "<HR />\n", '<TABLE BORDER="1" CELLSPACING="0">', "\n",
		TR TH map {$_->[1]} @TAB;
	$q = Sql $q;
	while(@_ = SqlRow $q) { print TR TD map {h $_} @_ }
	print "</TABLE>\n"
}
print "<HR />\n", h($_), "\n" if $_ = DBend;

# Завершение ответа
print '<HR />
<P ALIGN="right" STYLE="font: italic 70% small-caption;">', $SIG,
'</P>
</BODY>
</HTML>
'

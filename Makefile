PREFIX = /usr/

all: install

install:
	install -Dm 755 yatext.sh ${DESTDIR}${PREFIX}bin/yatext

uninstall:
	rm ${DESTDIR}${PREFIX}bin/yatext

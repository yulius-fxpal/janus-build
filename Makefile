APPDIR?=/app
export PKG_CONFIG_PATH=${APPDIR}/lib/pkgconfig
CFLAGS=$(shell PKG_CONFIG_PATH=${APPDIR}/lib/pkgconfig pkg-config --cflags libsrtp2 libwebsockets)
LDFLAGS=-Wl,--start-group $(shell PKG_CONFIG_PATH=${APPDIR}/lib/pkgconfig pkg-config --libs libsrtp2 libwebsockets) -lpthread

default: ${APPDIR} submodules libsrtp libwebsockets usrsctp boringssl janus

test:
	echo "Test: ${CFLAGS}"

deps:
	sudo apt install libmicrohttpd-dev libjansson-dev libnice-dev \
		libssl-dev libsofia-sip-ua-dev libglib2.0-dev \
		libopus-dev libogg-dev libcurl4-openssl-dev liblua5.3-dev \
		pkg-config gengetopt libtool automake cmake golang

clean:
	rm -rf libwebsockets/build
	rm -rf boringssl/build
	make -C usrsctp distclean
	make -C libsrtp distclean
	make -C janus-gateway distclean

tarball: janus.tgz
janus.tgz: /app/bin/janus
	rm -f janus.tgz
	tar -zcvf janus.tgz ${APPDIR}

submodules: janus-gateway
janus-gateway:
	git submodule init
	git submodule update

distclean:
	rm -rf ${APPDIR}/* libsrtp libwebsockets usrsctp janus-gateway

${APPDIR}:
	sudo mkdir -p ${APPDIR}
	sudo chown ${USER} ${APPDIR}

libsrtp: ${APPDIR}/include/srtp2/srtp.h
${APPDIR}/include/srtp2/srtp.h:
	cd libsrtp && ./configure --prefix=${APPDIR} --enable-openssl
	make -C libsrtp 
	make -C libsrtp install

libwebsockets: ${APPDIR}/include/libwebsockets.h
${APPDIR}/include/libwebsockets.h:
	mkdir -p libwebsockets/build
	cd libwebsockets/build && cmake -DLWS_MAX_SMP=1 -DCMAKE_INSTALL_PREFIX:PATH=${APPDIR} -DCMAKE_C_FLAGS="-fpic" ..
	cd libwebsockets/build && make && make install

usrsctp: ${APPDIR}/include/usrsctp.h
${APPDIR}/include/usrsctp.h:
	cd usrsctp && ./bootstrap && \
		./configure --prefix=${APPDIR}
	make -C usrsctp
	make -C usrsctp install

boringssl: ${APPDIR}/lib/libssl.a
${APPDIR}/lib/libssl.a:
	sed -i s/" -Werror"//g boringssl/CMakeLists.txt
	mkdir -p boringssl/build
	cd boringssl/build && cmake -DCMAKE_CXX_FLAGS="-lrt" -DCMAKE_C_FLAGS="-fPIC" ..
	make -C boringssl/build && \
		cp -R boringssl/include ${APPDIR}/include && \
		cp boringssl/build/ssl/libssl.a boringssl/build/crypto/libcrypto.a ${APPDIR}/lib/


janus: ${APPDIR}/bin/janus ${APPDIR}/etc/janus/janus.cfg
${APPDIR}/bin/janus: janus-gateway/Makefile
	cd janus-gateway && make && make install

janus-gateway/Makefile: janus-gateway/configure
	cd janus-gateway && ./configure \
		--prefix=${APPDIR} \
		--enable-websockets \
		--enable-data-channels \
		--enable-libsrtp2 \
		--enable-dtls-settimeout \
		--enable-boringssl=${APPDIR}/include \
		CFLAGS="${CFLAGS}" \
		LDFLAGS="${LDFLAGS}"

janus-gateway/configure:
	cd janus-gateway && ./autogen.sh
	
${APPDIR}/etc/janus/janus.cfg: janus-gateway/Makefile
	cd janus-gateway && make configs

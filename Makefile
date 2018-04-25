APPDIR=/app
export PKG_CONFIG_PATH=${APPDIR}/lib/pkgconfig

default: ${APPDIR} libsrtp2 libwebsockets usrsctp janus

deps:
	apt install libmicrohttpd-dev libjansson-dev libnice-dev \
		libssl-dev libsrtp-dev libsofia-sip-ua-dev libglib2.0-dev \
		libopus-dev libogg-dev libcurl4-openssl-dev liblua5.3-dev \
		pkg-config gengetopt libtool automake

${APPDIR}:
	sudo mkdir -p /app
	sudo chown ${USER} /app

libsrtp2: ${APPDIR}/include/srtp2/srtp.h
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

janus: ${APPDIR}/janus
${APPDIR}/janus: janus-gateway/Makefile ${APPDIR}/etc/janus/janus.cfg
	cd janus-gateway && make && make install

janus-gateway/Makefile: janus-gateway/configure
	cd janus-gateway && ./configure \
		--prefix=${APPDIR} \
		--enable-websockets --enable-data-channels \
		CFLAGS="-I${APPDIR}/include" \
		LDFLAGS="-L${APPDIR}/lib -lusrsctp -lsrtp -lwebsockets"

janus-gateway/configure:
	cd janus-gateway && ./autogen.sh
	
${APPDIR}/etc/janus/janus.cfg: janus-gateway/Makefile
	cd janus-gateway && make configs

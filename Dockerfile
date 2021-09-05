FROM alpine:3.13.6 AS builder

RUN apk add --no-cache \
  linux-headers \
  bash \
  git \
  python3 \
  make \
  cmake \
  g++

ENV COPYDIR=/build
ENV BUILD_CLIENT=0
ENV BUILD_SERVER=1
ENV USE_CURL=1
ENV USE_CODEC_OPUS=1
ENV USE_VOIP=1

WORKDIR /build
RUN git clone https://github.com/ioquake/ioq3.git ioq3

WORKDIR /build/ioq3
RUN make -j$(nproc --all)
RUN make copyfiles

WORKDIR /files
RUN wget https://files.ioquake3.org/quake3-latest-pk3s.zip
RUN wget -P /build/baseq3 https://github.com/nrempel/q3-server/raw/master/baseq3/pak0.pk3
RUN unzip quake3-latest-pk3s.zip
RUN cp quake3-latest-pk3s/baseq3/* /build/baseq3/
RUN cp quake3-latest-pk3s/missionpack/* /build/missionpack/

WORKDIR /build
RUN echo $'#!/bin/sh \n\
/home/ioq3.run +exec server.cfg +exec levels.cfg +exec bots.cfg' > run.sh
RUN chmod 777 run.sh
RUN mv ioq3ded.* ioq3.run

FROM alpine:3.13.6 AS runner
WORKDIR /home
COPY --from=builder /build/baseq3 baseq3
COPY --from=builder /build/ioq3 ioq3
COPY --from=builder /build/ioq3.run ioq3.run
COPY --from=builder /build/missionpack missionpack
COPY --from=builder /build/run.sh run.sh

EXPOSE 27960/udp
CMD [ "/home/run.sh" ]

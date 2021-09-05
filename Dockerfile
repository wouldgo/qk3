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
RUN make -j5
RUN make copyfiles

WORKDIR /files
RUN wget https://files.ioquake3.org/quake3-latest-pk3s.zip
RUN wget -P /build/baseq3 https://github.com/nrempel/q3-server/raw/master/baseq3/pak0.pk3
RUN unzip quake3-latest-pk3s.zip
RUN cp quake3-latest-pk3s/baseq3/* /build/baseq3/
RUN cp quake3-latest-pk3s/missionpack/* /build/missionpack/

SHELL ["/bin/bash", "-c"]

WORKDIR /build/baseq3
RUN echo $'// general server info \n\
seta sv_hostname "Q3A CTF"   // name that appears in server list \n\
seta g_motd "Hard CTF 24/7"         // message that appears when connecting \n\
seta sv_maxclients 16               // max number of clients than can connect \n\
seta sv_pure 1                      // pure server, no altered pak files \n\
seta g_quadfactor 4                 // quad damage strength (3 is normal) \n\
seta g_friendlyFire 1               // friendly fire motherfucker \n\
\n\
// capture the flag \n\
seta g_gametype 4                   // 0:FFA, 1:Tourney, 2:FFA, 3:TD, 4:CTF \n\
seta g_teamAutoJoin 0               // 0:goes into spectator mode, 1:auto joins a team \n\
seta g_teamForceBalance 0           // 0:free selection, 1:forces player to join weak team \n\
seta timelimit 30                   // Time limit in minutes \n\
seta capturelimit 8                 // Capture limit for CTF \n\
seta fraglimit 0                    // Frag limit \n\
\n\
// team deathmatch \n\
//seta g_gametype 3                 // 0:FFA, 1:Tourney, 2:FFA, 3:TD, 4:CTF \n\
//seta g_teamAutoJoin 0             // 0:goes into spectator mode, 1:auto joins a team \n\
//seta g_teamForceBalance 1         // 0:free selection, 1:forces player to join weak team \n\
//seta timelimit 15                 // Time limit in minutes \n\
//seta fraglimit 25                 // Frag limit \n\
\n\
// free for all \n\ \n\
//seta g_gametype 0                 // 0:FFA, 1:Tourney, 2:FFA, 3:TD, 4:CTF \n\
//seta timelimit 10                 // Time limit in minutes \n\
//seta fraglimit 15                 // Frag limit \n\
\n\
seta g_weaponrespawn 2              // weapon respawn in seconds \n\
seta g_inactivity 120               // kick players after being inactive for x seconds \n\
seta g_forcerespawn 0               // player has to press primary button to respawn \n\
seta g_log server.log               // log name \n\
seta logfile 3                      // probably some kind of log verbosity? \n\
seta rconpassword "secret"          // sets RCON password for remote console \n\
\n\
seta rate "12400"                   // not sure \n\
seta snaps "40"                     // what this \n\
seta cl_maxpackets "40"             // stuff is \n\
seta cl_packetdup "1"               // all about \n\
' > server.cfg

RUN echo $'set dm1 "map q3ctf4; set nextmap vstr dm2" \n\
set dm2 "map q3ctf3; set nextmap vstr dm3" \n\
set dm3 "map q3ctf2; set nextmap vstr dm4" \n\
set dm4 "map q3ctf1; set nextmap vstr dm1" \n\
vstr dm1 \n\
' > levels.cfg

RUN echo $'seta bot_enable 1       // Allow bots on the server \n\
seta bot_nochat 1       // Shut those fucking bots up \n\
seta g_spskill 1        // Default skill of bots [1-5] \n\
seta bot_minplayers 5   // This fills the server with bots to satisfy the minimum \n\
\n\
//## Manual adding of bots. syntax: \n\
//## addbot name [skill] [team] [delay] \n\
//addbot doom       4   blue    10 \n\
//addbot bones      4   blue    10 \n\
//addbot slash      4   blue    10 \n\
//addbot orbb       4   red     10 \n\
//addbot major      4   red     10 \n\
//addbot hunter     4   red     10 \n\
//addbot bitterman  4   red     10 \n\
//addbot keel       4   red     10 \n\
' > bots.cfg

WORKDIR /build
RUN echo $'#!/bin/sh \n\
/home/ioq3.run +exec server.cfg +exec levels.cfg +exec bots.cfg' > run.sh
RUN chmod 777 run.sh

FROM alpine:3.13.6 AS runner
WORKDIR /home
COPY --from=builder /build/baseq3 baseq3
COPY --from=builder /build/ioq3 ioq3
COPY --from=builder /build/ioq3ded.x86_64 ioq3.run
COPY --from=builder /build/missionpack missionpack
COPY --from=builder /build/run.sh run.sh

EXPOSE 27960/udp
CMD [ "/home/run.sh" ]

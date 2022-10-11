FROM linuxserver/rdesktop:ubuntu-mate
COPY sources.list /etc/apt/sources.list
RUN apt update
COPY simsun.ttc /usr/share/fonts/windows
RUN sudo apt -y install language-pack-zh-hans fontconfig
RUN sudo dpkg-reconfigure locales 

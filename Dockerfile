FROM ubuntu:16.04

RUN apt-get -y update
RUN apt-get -y install gcc make
RUN apt-get -y install tar pkg-config
RUN apt-get -y install libsdl1.2-dev libsdl-image1.2-dev
RUN apt-get -y install crasm
RUN apt-get -y install fceux

# Build lib6502
WORKDIR /src
WORKDIR /src/lib6502
COPY ./lib6502 /src/lib6502
RUN tar -xzf lib6502.tar.gz
WORKDIR /src/lib6502/lib6502-1.3
RUN make install

# Build dreamboy
WORKDIR /src
COPY . /src
RUN make
CMD ["/bin/cat", "/src/dreamboy.nes"]

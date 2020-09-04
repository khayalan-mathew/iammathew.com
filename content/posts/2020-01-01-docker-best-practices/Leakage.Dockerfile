FROM ubuntu:latest

ARG PRIVATE_TOKEN

COPY ./download_private_stuff.sh .

RUN ./download_private_stuff.sh $PRIVATE_TOKEN
FROM ubuntu:latest as builder

WORKDIR /

ARG PRIVATE_TOKEN

COPY ./download_private_stuff.sh .

RUN ./download_private_stuff.sh $PRIVATE_TOKEN

FROM ubuntu:latest

COPY --from=builder /private_stuff .
FROM --platform=$BUILDPLATFORM quay.io/projectquay/golang:1.24 AS builder
ARG TARGETOS
ARG TARGETARCH
WORKDIR /go/src/app
COPY . .
RUN TARGETOS=${TARGETOS} TARGETARCH=${TARGETARCH} make build

FROM alpine
WORKDIR /
COPY --from=builder /go/src/app/build/* .

CMD ["./kbot"]
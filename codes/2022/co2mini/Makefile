
.PHONY: build

all: build deploy


co2mini: main.go
	GOOS=linux GOARCH=arm GOARM=6 go build

build: co2mini

deploy:
	rsync -v co2mini rasp-zero:~/


package main

import (
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/zserge/hid"
)

const (
	vendorID = "04d9:a052:0200:00"
	co2op    = 0x50
	tempop   = 0x42
)

var (
	key = []byte{0x86, 0x41, 0xc9, 0xa8, 0x7f, 0x41, 0x3c, 0xac}
)

type CO2MiniRecord struct {
	sync.Mutex
	co2  int
	temp float64
}

func New() *CO2MiniRecord {
	return &CO2MiniRecord{
		co2:  -1,
		temp: -1,
	}
}

var r = New()

func monitor(device hid.Device) {
	if err := device.Open(); err != nil {
		log.Println("Open error: ", err)
		return
	}
	defer device.Close()

	if err := device.SetReport(0, key); err != nil {
		log.Fatal(err)
	}

	for {
		if buf, err := device.Read(-1, 1*time.Second); err == nil {
			dec := buf
			if len(dec) == 0 {
				continue
			}
			val := int(dec[1])<<8 | int(dec[2])
			if dec[0] == co2op {
				// log.Printf("co2:%d ppm", val)
				r.Lock()
				r.co2 = val
				r.Unlock()
			}
			if dec[0] == tempop {
				temp := float64(val)/16.0 - 273.15
				r.Lock()
				r.temp = temp
				r.Unlock()
			}
		}
	}
}

func main() {
	hid.UsbWalk(func(device hid.Device) {
		info := device.Info()
		id := fmt.Sprintf("%04x:%04x:%04x:%02x", info.Vendor, info.Product, info.Revision, info.Interface)
		if id != vendorID {
			return
		}

		go monitor(device)
		for {
			log.Println("%v", r)
			time.Sleep(60 * time.Second)
		}
	})
}

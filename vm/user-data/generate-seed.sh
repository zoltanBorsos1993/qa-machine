#!/bin/bash

THIS_DIR=$(dirname $0)

cd $THIS_DIR

{ echo instance-id: $(uuidgen); echo local-hostname: qa-machine; } > meta-data

if [ -e seed.iso ]; then
	rm -f seed.iso
fi

genisoimage  -output seed.iso -volid cidata -joliet -rock user-data meta-data

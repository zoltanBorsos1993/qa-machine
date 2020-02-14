#!/bin/bash

set -e

THIS_DIR=$(dirname $0)

cd $THIS_DIR

QA_DOMAIN_NAME="qa-machine"
QA_DOMAIN_XML_FILE_NAME="$QA_DOMAIN_NAME-domain.xml"

QA_NETWORK_NAME="qa-network"
QA_NETWORK_XML_FILE_NAME="$QA_NETWORK_NAME.xml"

CLOUD_IMAGE_PATH="images/bionic-server-cloudimg-amd64.img"
ORIGINAL_CLOUD_IMAGE_PATH="images/bionic-server-cloudimg-amd64.original.img"

function teardown_existing() {
	if virsh list --all --name | grep $QA_DOMAIN_NAME; then
		echo Domain $QA_DOMAIN_NAME exits. Deleting it first.
		virsh destroy $QA_DOMAIN_NAME || true
		virsh undefine $QA_DOMAIN_NAME
	fi
}

function generate_config_drive_iso() {
	echo Regenerating seed.iso...
	./user-data/generate-seed.sh
}

function create_disk_image() {
	rm -f $CLOUD_IMAGE_PATH
	cp $ORIGINAL_CLOUD_IMAGE_PATH $CLOUD_IMAGE_PATH
	qemu-img resize $CLOUD_IMAGE_PATH +15G
}

function create_domain() {
	echo Defining domain...
	virt-install --print-xml\
	--dry-run \
	--import \
	--check path_in_use=off \
	-n $QA_DOMAIN_NAME \
	--memory 4096 \
	--vcpus 2 \
	--os-variant ubuntu18.04 \
	--network network="$QA_NETWORK_NAME" \
	--disk path=$(readlink -e images/bionic-server-cloudimg-amd64.img) \
	--disk path=$(readlink -e user-data/seed.iso),device=cdrom > $QA_DOMAIN_XML_FILE_NAME

	virsh define $QA_DOMAIN_XML_FILE_NAME
}

function create_network() {
	if virsh net-list --all --name | grep $QA_NETWORK_NAME; then
		echo Network $QA_NETWORK_NAME exits. Deleting it first.
		virsh net-destroy $QA_NETWORK_NAME || true
		virsh net-undefine $QA_NETWORK_NAME
	fi

	virsh net-define $QA_NETWORK_XML_FILE_NAME
	virsh net-start $QA_NETWORK_NAME
	virsh net-autostart $QA_NETWORK_NAME
}

function start_domain() {
	virsh start $QA_DOMAIN_NAME

	echo Wait for OS to boot. It takes around 30 to 45 secs.

	timeout_cnt=0
	while ! virsh net-dhcp-leases qa-network | grep qa-machine > /dev/null; do
		sleep 2

		timeout_cnt=$[timeout_cnt + 1]
		if [ $timeout_cnt -gt $[120 / 2] ]; then
			echo Failed to start VM or obtain IP address for it!
			echo Exiting...
			exit 1
		fi

		echo Waiting for domain to come up...
	done

	ipv4_address=$(virsh net-dhcp-leases qa-network | awk '/qa-machine/ { print substr($5, 1, index($5, "/") - 1) }')
	echo IPv4 address: $ipv4_address
}

teardown_existing
generate_config_drive_iso
create_disk_image
create_domain
create_network
start_domain

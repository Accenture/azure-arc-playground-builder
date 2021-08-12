# !/bin/bash

# Create directories and mount points to be used for persistent volumes
# this should be run when docker deamon is not running.
# Reference: https://github.com/docker/for-win/issues/5325#issuecomment-567594291

base_dir='/mnt/arcdata'
wsl_dir='/mnt/wsl/arcdata'
sudo umount -R /mnt/wsl/arcdata/vol*
sudo rm -r $base_dir
sudo rm -r $wsl_dir

PV_COUNT=12
for i in $(seq 1 $PV_COUNT); do

  vol="vol$i"
  dir="$base_dir/$vol"
  wsl="$wsl_dir/$vol"
  sudo mkdir -p $dir
  sudo mkdir -p $wsl

  sudo mount --bind $dir $wsl

  echo "Created mountpoint $wsl"
done
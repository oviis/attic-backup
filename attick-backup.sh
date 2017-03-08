#!/bin/bash
# Example would be to run this script as follows:
# efs-backup.sh $src $dst efs-12345
#
set +x

# Input arguments
source=$1
destination=$2
efsid=$3
s3bucket=$4
#atticPw=$5

#we need here to separete directories for running things in parallel
BACKUP_SRC="/backup-$efsid"
BACKUP_DST="/mnt/backups-$efsid"
##you need to change your bucket here
S3_BUCKET="$s3bucket"

echo "export ATTIC_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes"
export ATTIC_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes

if [ ! -d ${BACKUP_SRC} ]; then
  echo "sudo mkdir ${BACKUP_SRC}"
  sudo mkdir ${BACKUP_SRC}
fi 

if [ ! -d ${BACKUP_DST} ]; then
  echo "sudo mkdir ${BACKUP_DST}"
  sudo mkdir ${BACKUP_DST}
fi

#mounting NFS EFS from AWS
if ! awk '{print $2}' /proc/mounts | grep -qs "^${BACKUP_SRC}$"; then 
  echo "sudo mount -t nfs -o nfsvers=4.1 -o rsize=1048576 -o wsize=1048576 -o timeo=600 -o retrans=2 -o hard $source ${BACKUP_SRC}"
  sudo mount -t nfs -o nfsvers=4.1 -o rsize=1048576 -o wsize=1048576 -o timeo=600 -o retrans=2 -o hard $source ${BACKUP_SRC}
fi

if ! awk '{print $2}' /proc/mounts | grep -qs "^${BACKUP_DST}$"; then
  echo "sudo mount -t nfs -o nfsvers=4.1 -o rsize=1048576 -o wsize=1048576 -o timeo=600 -o retrans=2 -o hard $destination ${BACKUP_DST}"
  sudo mount -t nfs -o nfsvers=4.1 -o rsize=1048576 -o wsize=1048576 -o timeo=600 -o retrans=2 -o hard $destination ${BACKUP_DST}
fi


if [ ! -d ${BACKUP_DST}/$efsid ]; then
  echo "sudo mkdir -p ${BACKUP_DST}/$efsid"
  sudo mkdir -p ${BACKUP_DST}/$efsid
  echo "sudo chmod 700 ${BACKUP_DST}/$efsid"
  sudo chmod 700 ${BACKUP_DST}/$efsid
  echo "sudo attic init -v ${BACKUP_DST}/$efsid"
  sudo attic init -v ${BACKUP_DST}/$efsid
fi


echo "sudo attic create --stats ${BACKUP_DST}/$efsid::backup-`date +%Y-%m-%d` ${BACKUP_SRC}"
sudo attic create -v --stats ${BACKUP_DST}/$efsid::backup-`date +%Y-%m-%d` ${BACKUP_SRC}

# Use the `prune` subcommand to maintain 7 daily, 3 weekly
echo "Use the 'attic prune' subcommand to maintain 7 daily, 3 weekly"
echo "sudo attic prune -v ${BACKUP_DST}/$efsid  --keep-daily=7 --keep-weekly=3"
sudo attic prune -v ${BACKUP_DST}/$efsid  --keep-daily=7 --keep-weekly=3
atticStatus=$?

# sync to S3, for this you need a s3cmd binary and configure it with your keys
echo "s3cmd sync -H ${BACKUP_DST}/$efsid s3://com.abi.efs.backup"
sudo s3cmd sync -H ${BACKUP_DST}/$efsid s3://com.abi.efs.backup


echo "sudo umount ${BACKUP_SRC}"
sudo umount ${BACKUP_SRC}
echo "sudo umount ${BACKUP_DST}"
sudo umount ${BACKUP_DST}
exit $atticStatus

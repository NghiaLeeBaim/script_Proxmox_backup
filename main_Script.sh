#!/bin/bash

# Thư mục lưu trữ tạm thời
TMP_DIR="/var/tmp"

# Số lượng bản sao lưu giữ lại cục bộ
MIN_LOCAL_BACKUPS=3

# Cấu hình S3
S3_ENDPOINT="YOUR_ENDPOINT"
S3_BUCKET="YOUR_BUCKET"
AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY"
AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY"
AWS_REGION="YOUR_REGION"

# Đảm bảo script được chạy với quyền root
if [[ $EUID -ne 0 ]]; then
  echo "============================================"
  echo "Script này cần được chạy với quyền root." >&2
  exit 1
fi

# Lấy thông tin cluster và node
NODE_NAME=$(hostname)
NOW=$(date +%Y-%m-%d)
BACKUP_FILE="proxmox-config-$NODE_NAME-$NOW.tar.gz"

# Thư mục lưu tạm bản sao lưu
BACKUP_DIR="$TMP_DIR/proxmox-backup-$NOW"
mkdir -p "$BACKUP_DIR"


# Hàm kiểm tra aws-cli đã được cài đặt, nếu chưa thì cài đặt
function check_aws_installed() {
  if ! command -v aws &> /dev/null; then
    echo "============================================"
    echo "aws-cli chưa được cài đặt. Đang tiến hành cài đặt..."
    if [[ -f /etc/debian_version ]]; then
      apt update && apt install -y awscli || {
        echo "============================================"
        echo "Lỗi: Không thể cài đặt aws-cli." >&2
        exit 1
      }
    elif [[ -f /etc/redhat-release ]]; then
      yum install -y awscli || {
        echo "============================================"
        echo "Lỗi: Không thể cài đặt aws-cli." >&2
        exit 1
      }
    else
      echo "============================================"
      echo "Lỗi: Hệ điều hành không được hỗ trợ để cài đặt aws-cli." >&2
      exit 1
    fi
  fi
}

# Hàm kiểm tra và cấu hình aws-cli
function aws_configure() {
  echo "============================================"
  echo "Đang cấu hình AWS CLI..."
  aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
  aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
  aws configure set region "$AWS_REGION"
}

# Hàm sao lưu các file cấu hình
function backup_config() {
  echo "============================================"
  echo "Đang sao lưu các file cấu hình..."

  cp /etc/hosts /root/
  cp /etc/network/interfaces /root/

  tar --warning='no-file-ignored' -cvPf "$BACKUP_DIR/var-lib-pve.tar" /var/lib/pve-cluster/.

  tar --warning='no-file-ignored' -cvPf "$BACKUP_DIR/root.tar" --one-file-system /root/.

  tar -czf "$BACKUP_DIR/corosync-backup.tar.gz" /etc/corosync
}

# Hàm nén các file sao lưu
function compress_backup() {
  echo "============================================"
  echo "Đang nén các file sao lưu..."
  tar --use-compress-program=pigz -cvPf "$TMP_DIR/$S3_BUCKET-$BACKUP_FILE" -C "$BACKUP_DIR" . || {
  echo "============================================"
  echo "Lỗi: Không thể nén các file sao lưu." >&2
    exit 1
  }
}

# Hàm upload file lên S3
function upload_to_s3() {
  echo "============================================"
  echo "Đang upload bản sao lưu lên S3..."
  aws s3 cp "$TMP_DIR/$S3_BUCKET-$BACKUP_FILE" --endpoint-url "$S3_ENDPOINT" "s3://$S3_BUCKET/" || {
  echo "============================================"    
  echo "Lỗi: Upload lên S3 thất bại." >&2
    exit 1
  }
  echo "============================================"
  echo "Upload thành công lên s3://$S3_BUCKET/."
}

# Hàm xóa các bản sao lưu cũ trên máy cục bộ
function clean_local_backups() {
  echo "============================================"
  echo "Đang xóa các bản sao lưu cũ trên máy cục bộ..."
  BACKUPS_LIST=$(ls -t "$TMP_DIR/proxmox-config-*.tar.gz" 2>/dev/null)
  BACKUPS_COUNT=$(echo "$BACKUPS_LIST" | wc -l)

  if [[ $BACKUPS_COUNT -gt $MIN_LOCAL_BACKUPS ]]; then
    BACKUPS_TO_DELETE=$(echo "$BACKUPS_LIST" | tail -n $(($BACKUPS_COUNT - $MIN_LOCAL_BACKUPS)))
    for BACKUP in $BACKUPS_TO_DELETE; do
      echo "============================================"
      echo "Xóa backup cũ: $BACKUP"
      rm -f "$BACKUP"
    done
  else
    echo "============================================"
    echo "Số lượng bản sao lưu cục bộ đã đủ hoặc ít hơn $MIN_LOCAL_BACKUPS, không cần xóa."
  fi
}

# Hàm thêm script vào cronjobs nếu chưa có hoặc sửa lại nếu lỗi
function add_to_cron() {
  CRON_JOB="0 2 * * * /bin/bash $(realpath $0)"
  if ! crontab -l 2>/dev/null | grep -F "$CRON_JOB" > /dev/null; then
    echo "============================================"
    echo "Đang thêm script vào cronjobs..."
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab - || {
      echo "============================================"
      echo "Lỗi: Không thể thêm script vào cronjobs." >&2
      exit 1
    }
    echo "============================================"
    echo "Đã thêm script vào cronjobs để chạy hàng ngày lúc 2 giờ sáng."
  else
    echo "============================================"
    echo "Script đã tồn tại trong cronjobs, SKIPPED"
  fi
}


# Thực thi script
check_aws_installed
aws_configure
backup_config
compress_backup
upload_to_s3
clean_local_backups
add_to_cron

echo "============================================"
echo "Quá trình sao lưu hoàn tất."

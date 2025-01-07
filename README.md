# **Proxmox Backup Script**

## **Tính năng**
1. **Nhập credential của S3:**
   - Cho phép dễ dàng thay đổi các thông số `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `S3_ENDPOINT`, và `S3_BUCKET` trực tiếp trong script.
2. **Kiểm tra và tự động cài đặt aws-cli:**
   - Script đảm bảo `aws-cli` được cài đặt trước khi thực thi.
3. **Tự động cấu hình AWS CLI:**
   - Tự động cấu hình các thông tin cần thiết như `access_key`, `secret_key`, và `region`.
4. **Tự động thêm cronjob:**
   - Thêm cronjob chạy định kỳ hàng ngày vào lúc 2 giờ sáng nếu chưa có. Nếu đã tồn tại, script sẽ bỏ qua bước này.
5. **Sao lưu và nén file cấu hình:**
   - Sao lưu các file quan trọng như `/etc/hosts`, `/etc/network/interfaces`, `/etc/corosync`.
   - Sử dụng `pigz` để nén dữ liệu nhanh chóng.
6. **Dọn dẹp bản sao lưu cục bộ:**
   - Tự động xóa các bản sao lưu cũ, chỉ giữ lại số lượng bản sao lưu tối thiểu được cấu hình (`MIN_LOCAL_BACKUPS`).
7. **Hiển thị giao diện rõ ràng:**
   - Hiển thị trạng thái từng bước trong quá trình thực thi.

---

## **Ưu điểm**
1. **Cấu hình S3 đơn giản:**
   - Chỉ cần chỉnh sửa script để thay đổi thông tin S3, không yêu cầu cấu hình phức tạp.
2. **Tự động hóa toàn diện:**
   - Quá trình cài đặt package, sao lưu, và tạo lịch trình được tự động hóa hoàn toàn.
3. **Hỗ trợ đa nền tảng:**
   - Tương thích với cả hệ điều hành Debian và Red Hat.
4. **Tích hợp cronjob:**
   - Script tự động xử lý cronjob mà không cần cấu hình thủ công.
5. **Hiển thị trạng thái:**
   - Dễ dàng theo dõi từng bước thực hiện nhờ giao diện hiển thị rõ ràng.

---

## **Nhược điểm**
1. **Tùy chỉnh thủ công:**
   - Nếu cần thay đổi nội dung file sao lưu, phải chỉnh sửa trực tiếp trong script.
2. **Bảo mật thông tin S3:**
   - Thông tin S3 được lưu trong script ở dạng văn bản rõ ràng, dễ bị lộ nếu không bảo vệ tốt.
3. **Tính toàn vẹn file:**
   - Chưa kiểm tra checksum của file sau khi upload lên S3, có thể xảy ra lỗi hoặc mất dữ liệu.
4. **Thiếu mã hóa dữ liệu:**
   - File sao lưu không được mã hóa, dễ bị lộ thông tin nhạy cảm.
5. **Hỗ trợ môi trường cluster:**
   - Script hiện chỉ sao lưu cấu hình cho một node trong cluster.

---

## **Hướng dẫn sử dụng**

### 1. **Cập nhật thông tin S3**
- Mở script và chỉnh sửa các thông số:
  ```bash
  S3_ENDPOINT="https://s3-hcm5-r1.longvan.net"
  S3_BUCKET="nghialvs"
  AWS_ACCESS_KEY_ID="YourAccessKey"
  AWS_SECRET_ACCESS_KEY="YourSecretKey"
  AWS_REGION="YourRegion"
  CRON_JOB="0 2 * * * /bin/bash $(realpath $0)"

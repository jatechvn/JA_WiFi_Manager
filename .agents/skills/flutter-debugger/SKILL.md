---
name: flutter-debugger
description: Kỹ năng fix bug dựa trên phương pháp Hypothesis-Driven Debugging (gỡ lỗi theo giả thuyết). Kích hoạt khi có lỗi nghiêm trọng, lỗi không rõ ràng hoặc khi fix nhiều lần không được.
---

# Flutter Debugger Skill (Hypothesis-Driven)

Kỹ năng này áp dụng tư duy gỡ lỗi có hệ thống, không đoán mò code mà tập trung vào tìm hiểu nguyên nhân gốc rễ (Root Cause) của lỗi trong dự án Flutter.

## Quy trình thực hiện (Dành cho Agent)
1. **Thu thập dữ liệu (Context):** Không được sửa code ngay. Nếu người dùng chỉ đưa mã lỗi ngắn, hãy yêu cầu cung cấp toàn bộ Stack Trace hoặc nội dung file liên quan.
2. **Phân tích (Analyze):** Tự động chạy lệnh `flutter analyze` hoặc đọc kỹ Stack Trace để truy vết các hàm được gọi (Call Stack).
3. **Lập Giả Thuyết (Hypothesis):** 
   - Suy nghĩ từng bước (step-by-step) về luồng dữ liệu gây ra lỗi.
   - Nêu ra rõ ràng ít nhất 2 nguyên nhân cốt lõi (root cause) CÓ THỂ xảy ra.
4. **Đề xuất và Sửa lỗi:**
   - Dựa trên giả thuyết khả dĩ nhất, tiến hành sửa mã nguồn.
   - **Quy tắc Giả định sai (Assume Wrong):** Nếu người dùng phản hồi rằng cách sửa không hiệu quả, Agent BẮT BUỘC phải giả định hướng tiếp cận trước đó là sai. Bỏ qua hoàn toàn hướng đi cũ và chuyển sang giả thuyết thứ 2.
5. **Đề phòng Tương lai:** Sau khi fix xong, nhắc nhở người dùng về các Edge Cases (dữ liệu null, lỗi mạng, v.v.) có thể làm hỏng logic này trong tương lai.

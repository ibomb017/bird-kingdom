package com.birdkingdom.dto;

public class AuthDTO {

    public static class SendCodeRequest {
        private String phone;
        public SendCodeRequest() {}
        public SendCodeRequest(String phone) { this.phone = phone; }
        public String getPhone() { return phone; }
        public void setPhone(String phone) { this.phone = phone; }
    }

    public static class SendCodeResponse {
        private Boolean success;
        private String message;
        public SendCodeResponse() {}
        public SendCodeResponse(Boolean success, String message) { this.success = success; this.message = message; }
        public Boolean getSuccess() { return success; }
        public void setSuccess(Boolean success) { this.success = success; }
        public String getMessage() { return message; }
        public void setMessage(String message) { this.message = message; }
    }

    public static class LoginRequest {
        private String phone;
        private String code;
        public LoginRequest() {}
        public LoginRequest(String phone, String code) { this.phone = phone; this.code = code; }
        public String getPhone() { return phone; }
        public void setPhone(String phone) { this.phone = phone; }
        public String getCode() { return code; }
        public void setCode(String code) { this.code = code; }
    }

    public static class LoginResponse {
        private Boolean success;
        private String message;
        private String token;
        private UserDTO user;
        public LoginResponse() {}
        public LoginResponse(Boolean success, String message, String token, UserDTO user) {
            this.success = success; this.message = message; this.token = token; this.user = user;
        }
        public Boolean getSuccess() { return success; }
        public void setSuccess(Boolean success) { this.success = success; }
        public String getMessage() { return message; }
        public void setMessage(String message) { this.message = message; }
        public String getToken() { return token; }
        public void setToken(String token) { this.token = token; }
        public UserDTO getUser() { return user; }
        public void setUser(UserDTO user) { this.user = user; }
    }

    public static class UpdateProfileRequest {
        private String nickname;
        private String bio;
        private String avatarUrl;
        public UpdateProfileRequest() {}
        public UpdateProfileRequest(String nickname, String bio, String avatarUrl) {
            this.nickname = nickname; this.bio = bio; this.avatarUrl = avatarUrl;
        }
        public String getNickname() { return nickname; }
        public void setNickname(String nickname) { this.nickname = nickname; }
        public String getBio() { return bio; }
        public void setBio(String bio) { this.bio = bio; }
        public String getAvatarUrl() { return avatarUrl; }
        public void setAvatarUrl(String avatarUrl) { this.avatarUrl = avatarUrl; }
    }

    public static class VerifyOldPhoneRequest {
        private String oldCode;
        public VerifyOldPhoneRequest() {}
        public VerifyOldPhoneRequest(String oldCode) { this.oldCode = oldCode; }
        public String getOldCode() { return oldCode; }
        public void setOldCode(String oldCode) { this.oldCode = oldCode; }
    }

    public static class ChangePhoneRequest {
        private String newPhone;
        private String newCode;
        public ChangePhoneRequest() {}
        public ChangePhoneRequest(String newPhone, String newCode) { this.newPhone = newPhone; this.newCode = newCode; }
        public String getNewPhone() { return newPhone; }
        public void setNewPhone(String newPhone) { this.newPhone = newPhone; }
        public String getNewCode() { return newCode; }
        public void setNewCode(String newCode) { this.newCode = newCode; }
    }

    public static class ChangePhoneResponse {
        private Boolean success;
        private String message;
        public ChangePhoneResponse() {}
        public ChangePhoneResponse(Boolean success, String message) { this.success = success; this.message = message; }
        public Boolean getSuccess() { return success; }
        public void setSuccess(Boolean success) { this.success = success; }
        public String getMessage() { return message; }
        public void setMessage(String message) { this.message = message; }
    }

    public static class SetPasswordRequest {
        private String password;
        public SetPasswordRequest() {}
        public SetPasswordRequest(String password) { this.password = password; }
        public String getPassword() { return password; }
        public void setPassword(String password) { this.password = password; }
    }

    public static class PasswordLoginRequest {
        private String phone;
        private String password;
        public PasswordLoginRequest() {}
        public PasswordLoginRequest(String phone, String password) { this.phone = phone; this.password = password; }
        public String getPhone() { return phone; }
        public void setPhone(String phone) { this.phone = phone; }
        public String getPassword() { return password; }
        public void setPassword(String password) { this.password = password; }
    }

    public static class VipPurchaseRequest {
        private String vipType;  // MONTHLY, YEARLY, LIFETIME
        private Integer duration; // 购买时长（月数），永久会员忽略此字段
        public VipPurchaseRequest() {}
        public VipPurchaseRequest(String vipType, Integer duration) { this.vipType = vipType; this.duration = duration; }
        public String getVipType() { return vipType; }
        public void setVipType(String vipType) { this.vipType = vipType; }
        public Integer getDuration() { return duration; }
        public void setDuration(Integer duration) { this.duration = duration; }
    }

    public static class VipPurchaseResponse {
        private Boolean success;
        private String message;
        private String vipType;
        private String expireDate;
        private Integer remainingDays;
        public VipPurchaseResponse() {}
        public VipPurchaseResponse(Boolean success, String message, String vipType, String expireDate, Integer remainingDays) {
            this.success = success;
            this.message = message;
            this.vipType = vipType;
            this.expireDate = expireDate;
            this.remainingDays = remainingDays;
        }
        public Boolean getSuccess() { return success; }
        public void setSuccess(Boolean success) { this.success = success; }
        public String getMessage() { return message; }
        public void setMessage(String message) { this.message = message; }
        public String getVipType() { return vipType; }
        public void setVipType(String vipType) { this.vipType = vipType; }
        public String getExpireDate() { return expireDate; }
        public void setExpireDate(String expireDate) { this.expireDate = expireDate; }
        public Integer getRemainingDays() { return remainingDays; }
        public void setRemainingDays(Integer remainingDays) { this.remainingDays = remainingDays; }
    }
}

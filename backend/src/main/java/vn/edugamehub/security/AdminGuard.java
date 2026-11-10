package vn.edugamehub.security;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import com.google.firebase.auth.FirebaseToken;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;

/** Chỉ chấp nhận Firebase ID Token hợp lệ và UID nằm trong danh sách Admin do chủ sở hữu cấu hình. */
@Component
public class AdminGuard {
    private final FirebaseAuth auth;
    private final Set<String> admins;
    private final Set<String> adminEmails;

    public AdminGuard(FirebaseAuth auth,
                      @Value("${app.admin-uids}") String adminUids,
                      @Value("${app.admin-emails}") String allowedEmails) {
        this.auth = auth;
        this.admins = Arrays.stream(adminUids.split(","))
                .map(String::trim).filter(s -> !s.isEmpty()).collect(Collectors.toUnmodifiableSet());
        this.adminEmails = Arrays.stream(allowedEmails.split(","))
                .map(s -> s.trim().toLowerCase(java.util.Locale.ROOT))
                .filter(s -> !s.isEmpty()).collect(Collectors.toUnmodifiableSet());
    }

    public String requireAdmin(String authorization) {
        if (authorization == null || !authorization.startsWith("Bearer ")) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Thiếu Firebase ID Token.");
        }
        try {
            FirebaseToken token = auth.verifyIdToken(authorization.substring(7).trim());
            String email = token.getEmail();
            boolean emailAllowed = email != null && token.isEmailVerified()
                    && adminEmails.contains(email.toLowerCase(java.util.Locale.ROOT));
            if (!admins.contains(token.getUid()) && !emailAllowed) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Tài khoản không có quyền Admin.");
            }
            return token.getUid();
        } catch (FirebaseAuthException ex) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Token không hợp lệ hoặc hết hạn.");
        }
    }
}

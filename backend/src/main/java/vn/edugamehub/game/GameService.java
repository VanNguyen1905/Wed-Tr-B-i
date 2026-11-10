package vn.edugamehub.game;

import com.google.cloud.storage.Blob;
import com.google.cloud.storage.Bucket;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

@Service
public class GameService {
    private static final long MAX_SIZE = 5L * 1024 * 1024;
    private final GameRepository repository;
    private final Bucket bucket;

    public GameService(GameRepository repository, Bucket bucket) {
        this.repository = repository;
        this.bucket = bucket;
    }

    public GameInfo upload(String title, String description, String category, MultipartFile file) throws IOException {
        title = text(title, "Tên game", 3, 100);
        description = text(description == null ? "" : description, "Mô tả", 0, 800);
        category = text(category == null ? "Khác" : category, "Danh mục", 1, 50);
        if (file == null || file.isEmpty() || file.getSize() > MAX_SIZE) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "File HTML phải có dung lượng từ 1 byte đến 5 MB.");
        }
        String original = file.getOriginalFilename();
        if (original == null || !original.toLowerCase(Locale.ROOT).endsWith(".html")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Phiên bản này chỉ nhận file .html đơn lẻ.");
        }
        byte[] bytes = file.getBytes();
        if (bytes.length > MAX_SIZE) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "File vượt quá 5 MB.");
        }
        validateHtml(bytes);
        String id = UUID.randomUUID().toString();
        String storagePath = "games/" + id + "/index.html";
        // Upload xong mới ghi Firestore để không tạo metadata trỏ đến file chưa tồn tại.
        bucket.create(storagePath, bytes, "text/html; charset=utf-8");
        GameInfo game = new GameInfo(id, title, description, category,
                safeFileName(original), bytes.length, true, System.currentTimeMillis(), storagePath);
        try {
            repository.save(game);
        } catch (RuntimeException ex) {
            Blob uploaded = bucket.get(storagePath);
            if (uploaded != null) uploaded.delete();
            throw ex;
        }
        return game;
    }

    public List<GameInfo> listPublic() { return repository.list(true); }
    public List<GameInfo> listAdmin() { return repository.list(false); }

    public GameInfo getPublished(String id) {
        GameInfo game = repository.find(id);
        if (!game.published()) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Game đang được ẩn.");
        return game;
    }

    public byte[] readPublished(String id) {
        GameInfo game = getPublished(id);
        Blob blob = bucket.get(game.storagePath());
        if (blob == null) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy file game.");
        return blob.getContent();
    }

    public GameInfo changePublished(String id, boolean published) {
        GameInfo old = repository.find(id);
        GameInfo updated = new GameInfo(old.id(), old.title(), old.description(), old.category(),
                old.originalFilename(), old.fileSize(), published, old.createdAt(), old.storagePath());
        repository.save(updated);
        return updated;
    }

    public void delete(String id) {
        GameInfo game = repository.find(id);
        // Ẩn ngay trước khi dọn file. Xóa bất đồng bộ lớn có thể bổ sung sau.
        changePublished(id, false);
        Blob uploaded = bucket.get(game.storagePath());
        if (uploaded != null && !uploaded.delete()) {
            throw new IllegalStateException("Không xóa được file Storage; game đã tạm ẩn để thử lại.");
        }
        repository.delete(id);
    }

    private static void validateHtml(byte[] bytes) {
        String html;
        try {
            html = StandardCharsets.UTF_8.newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(bytes)).toString().toLowerCase(Locale.ROOT);
        } catch (CharacterCodingException ex) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "File HTML phải mã hóa UTF-8.");
        }
        if (!html.contains("<html") || !html.contains("</html>")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "File thiếu cấu trúc HTML hoàn chỉnh.");
        }
        if (html.contains("<base ") || html.contains("<base>")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Không hỗ trợ thẻ <base> trong game HTML.");
        }
        // Chỉ Admin được đưa code HTML vào hệ thống. Việc kiểm tra này KHÔNG phải virus scanner.
        // Script game chạy trên origin riêng, tuyệt đối không đặt tại origin của giao diện đăng nhập.
    }

    private static String safeFileName(String original) {
        String normalized = original.replace('\\', '/');
        String name = normalized.substring(normalized.lastIndexOf('/') + 1);
        String cleaned = name.replaceAll("[^\\p{L}\\p{N}._ -]", "_");
        return cleaned.substring(0, Math.min(120, cleaned.length()));
    }

    private static String text(String value, String name, int min, int max) {
        if (value == null) value = "";
        String s = value.strip();
        if (s.length() < min || s.length() > max) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, name + " phải có từ " + min + " đến " + max + " ký tự.");
        }
        return s;
    }
}

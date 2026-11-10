package vn.edugamehub.api;

import vn.edugamehub.game.GameInfo;
import vn.edugamehub.game.GameService;
import vn.edugamehub.security.AdminGuard;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;

@RestController
public class GameController {
    private final GameService service;
    private final AdminGuard guard;
    private final String gameOrigin;
    private final String frontendOrigin;

    public GameController(GameService service, AdminGuard guard,
                          @Value("${app.game-origin}") String gameOrigin,
                          @Value("${app.frontend-origin}") String frontendOrigin) {
        this.service = service;
        this.guard = guard;
        this.gameOrigin = gameOrigin.strip().replaceAll("/+$", "");
        this.frontendOrigin = frontendOrigin.strip().replaceAll("/+$", "");
    }

    public record PublicGame(String id, String title, String description, String category,
                             long fileSize, long createdAt, String playUrl, String downloadUrl) {
    }
    public record VisibilityRequest(boolean published) { }

    private PublicGame publicGame(GameInfo g) {
        return new PublicGame(g.id(), g.title(), g.description(), g.category(),
                g.fileSize(), g.createdAt(),
                gameOrigin.isBlank() ? "" : gameOrigin + "/play/" + g.id(),
                "/api/v1/games/" + g.id() + "/download");
    }

    @GetMapping("/api/v1/health")
    public Map<String, String> health() { return Map.of("status", "ok", "service", "edugame-api"); }

    @GetMapping("/api/v1/games")
    public List<PublicGame> list() { return service.listPublic().stream().map(this::publicGame).toList(); }

    @GetMapping("/api/v1/games/{id}")
    public PublicGame get(@PathVariable String id) { return publicGame(service.getPublished(id)); }

    @GetMapping("/api/v1/games/{id}/download")
    public ResponseEntity<byte[]> download(@PathVariable String id) {
        GameInfo game = service.getPublished(id);
        String filename = game.originalFilename().replace("\"", "_").replace("\r", "").replace("\n", "");
        return ResponseEntity.ok()
                .cacheControl(CacheControl.noStore())
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"game.html\"; filename*=UTF-8''" +
                        java.net.URLEncoder.encode(filename, StandardCharsets.UTF_8).replace("+", "%20"))
                .header("X-Content-Type-Options", "nosniff")
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .body(service.readPublished(id));
    }

    /** Tuyệt đối KHÔNG rewrite /play/* vào Firebase Hosting chính; mở trên Cloud Run origin khác. */
    @GetMapping(value = "/play/{id}", produces = "text/html;charset=UTF-8")
    public ResponseEntity<byte[]> play(@PathVariable String id) {
        if (gameOrigin.isBlank()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Chưa cấu hình GAME_ORIGIN.");
        }
        // CSP được giới hạn theo nhu cầu game HTML mẫu. Không tin mã HTML chưa duyệt.
        String csp = "default-src 'none'; script-src 'self' 'unsafe-inline' https://cdn.tailwindcss.com; " +
                "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; " +
                "font-src https://fonts.gstatic.com data:; img-src 'self' data: blob: https:; " +
                "media-src 'self' data: blob:; connect-src 'none'; object-src 'none'; " +
                "base-uri 'none'; form-action 'none'; frame-ancestors " + frontendOrigin + ";";
        return ResponseEntity.ok()
                .header("Content-Security-Policy", csp)
                .header("X-Content-Type-Options", "nosniff")
                .header("Referrer-Policy", "no-referrer")
                .header("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
                .cacheControl(CacheControl.noStore())
                .contentType(MediaType.parseMediaType("text/html;charset=UTF-8"))
                .body(service.readPublished(id));
    }

    @GetMapping("/api/v1/admin/me")
    public Map<String, String> me(@RequestHeader(value = "Authorization", required = false) String auth) {
        return Map.of("uid", guard.requireAdmin(auth), "role", "ADMIN");
    }

    @GetMapping("/api/v1/admin/games")
    public List<GameInfo> adminList(@RequestHeader(value = "Authorization", required = false) String auth) {
        guard.requireAdmin(auth);
        return service.listAdmin();
    }

    @PostMapping(value = "/api/v1/admin/games", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<PublicGame> upload(@RequestHeader(value = "Authorization", required = false) String auth,
                                              @RequestParam String title,
                                              @RequestParam(required = false, defaultValue = "") String description,
                                              @RequestParam(defaultValue = "Khác") String category,
                                              @RequestPart("file") MultipartFile file) throws IOException {
        guard.requireAdmin(auth);
        GameInfo game = service.upload(title, description, category, file);
        return ResponseEntity.created(URI.create("/api/v1/games/" + game.id())).body(publicGame(game));
    }

    @PutMapping("/api/v1/admin/games/{id}/visibility")
    public GameInfo visibility(@RequestHeader(value = "Authorization", required = false) String auth,
                               @PathVariable String id,
                               @RequestBody VisibilityRequest req) {
        guard.requireAdmin(auth);
        return service.changePublished(id, req.published());
    }

    @DeleteMapping("/api/v1/admin/games/{id}")
    public ResponseEntity<Void> delete(@RequestHeader(value = "Authorization", required = false) String auth,
                                       @PathVariable String id) {
        guard.requireAdmin(auth);
        service.delete(id);
        return ResponseEntity.noContent().build();
    }
}

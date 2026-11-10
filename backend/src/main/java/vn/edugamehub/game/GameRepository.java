package vn.edugamehub.game;

import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.QueryDocumentSnapshot;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Repository;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutionException;

@Repository
public class GameRepository {
    private final Firestore db;
    public GameRepository(Firestore db) { this.db = db; }

    public void save(GameInfo game) {
        try {
            db.collection("games").document(game.id()).set(Map.of(
                    "title", game.title(), "description", game.description(),
                    "category", game.category(), "originalFilename", game.originalFilename(),
                    "fileSize", game.fileSize(), "published", game.published(),
                    "createdAt", game.createdAt(), "storagePath", game.storagePath())).get();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Tác vụ lưu game bị ngắt.", e);
        } catch (ExecutionException e) {
            throw new IllegalStateException("Không lưu được thông tin game.", e);
        }
    }

    public GameInfo find(String id) {
        try {
            DocumentSnapshot doc = db.collection("games").document(id).get().get();
            if (!doc.exists() || doc.getData() == null) {
                throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy trò chơi.");
            }
            return GameInfo.fromFirestore(doc.getId(), doc.getData());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Truy vấn bị ngắt.", e);
        } catch (ExecutionException e) {
            throw new IllegalStateException("Lỗi truy vấn Firestore.", e);
        }
    }

    public List<GameInfo> list(boolean onlyPublished) {
        try {
            List<QueryDocumentSnapshot> docs = onlyPublished
                    ? db.collection("games").whereEqualTo("published", true).limit(100).get().get().getDocuments()
                    : db.collection("games").limit(100).get().get().getDocuments();
            List<GameInfo> games = new ArrayList<>(docs.size());
            for (QueryDocumentSnapshot doc : docs) games.add(GameInfo.fromFirestore(doc.getId(), doc.getData()));
            games.sort(Comparator.comparingLong(GameInfo::createdAt).reversed());
            return games;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Truy vấn bị ngắt.", e);
        } catch (ExecutionException e) {
            throw new IllegalStateException("Lỗi truy vấn Firestore.", e);
        }
    }

    public void delete(String id) {
        try {
            db.collection("games").document(id).delete().get();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Xóa bị ngắt.", e);
        } catch (ExecutionException e) {
            throw new IllegalStateException("Không xóa được game.", e);
        }
    }
}

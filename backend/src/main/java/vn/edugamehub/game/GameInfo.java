package vn.edugamehub.game;

import java.util.Map;

public record GameInfo(String id, String title, String description, String category,
                       String originalFilename, long fileSize, boolean published,
                       long createdAt, String storagePath) {

    public static GameInfo fromFirestore(String id, Map<String, Object> map) {
        return new GameInfo(id,
                stringValue(map.get("title")), stringValue(map.get("description")),
                stringValue(map.get("category")), stringValue(map.get("originalFilename")),
                longValue(map.get("fileSize")), Boolean.TRUE.equals(map.get("published")),
                longValue(map.get("createdAt")), stringValue(map.get("storagePath")));
    }

    private static String stringValue(Object obj) { return obj instanceof String s ? s : ""; }
    private static long longValue(Object obj) { return obj instanceof Number n ? n.longValue() : 0L; }
}

package vn.edugamehub.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.cloud.firestore.Firestore;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.cloud.FirestoreClient;
import com.google.firebase.cloud.StorageClient;
import com.google.cloud.storage.Bucket;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.IOException;

@Configuration
public class FirebaseConfig {
    @Bean
    FirebaseApp firebaseApp(@Value("${app.firebase.project-id}") String projectId,
                            @Value("${app.firebase.storage-bucket}") String bucket) throws IOException {
        if (projectId.isBlank() || bucket.isBlank()) {
            throw new IllegalStateException("Chưa cấu hình FIREBASE_PROJECT_ID và STORAGE_BUCKET.");
        }
        GoogleCredentials credentials = GoogleCredentials.getApplicationDefault();
        FirebaseOptions options = FirebaseOptions.builder()
                .setCredentials(credentials)
                .setProjectId(projectId)
                .setStorageBucket(bucket)
                .build();
        return FirebaseApp.initializeApp(options);
    }

    @Bean
    Firestore firestore(FirebaseApp app) {
        return FirestoreClient.getFirestore(app);
    }

    @Bean
    FirebaseAuth firebaseAuth(FirebaseApp app) {
        return FirebaseAuth.getInstance(app);
    }

    @Bean
    Bucket bucket(FirebaseApp app) {
        Bucket bucket = StorageClient.getInstance(app).bucket();
        if (bucket == null) throw new IllegalStateException("Không tìm thấy bucket Storage.");
        return bucket;
    }
}

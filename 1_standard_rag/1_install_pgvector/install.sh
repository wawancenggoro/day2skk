# Build and push the image (use your own registry; set the same name in 04-deployment.yaml)
docker build -t wawancenggoro/pgvector-textsearch:pg17 .
docker push your-registry.example.com/pgvector-textsearch:pg17

# Deploy (edit the password in 01-secret.yaml first)
kubectl apply -f 01-secret.yaml
kubectl apply -f 02-configmap-init.yaml
kubectl apply -f 03-pvc.yaml
kubectl apply -f 04-deployment.yaml
kubectl apply -f 05-service.yaml

# Wait until ready, then verify both extensions
kubectl rollout status deployment/pgvector
kubectl exec deploy/pgvector -- psql -U raguser -d ragdb -c "SELECT extname, extversion FROM pg_extension WHERE extname IN ('vector','pg_textsearch');"

# The notebooks run inside the cluster, so they reach the database at the
# service DNS name "pgvector" (host: pgvector, port: 5432) - no port-forward needed.

# Replace <EXTERNAL-IP> with the value from: kubectl get svc qwen3-emb-4b
# Note: use http (not https), the service listens on port 80.

curl --request POST \
  --url http://103.125.91.66/v1/embeddings \
  --header 'Authorization: Bearer sk-dhU11z5FIjXQ8TLXpwDotpGetP21CQv3' \
  --header 'Content-Type: application/json' \
  --data '{
    "model": "Qwen/Qwen3-Embedding-4B",
    "input": [
      "The quick brown fox jumps over the lazy dog.",
      "Embedding models turn text into vectors."
    ]
  }'

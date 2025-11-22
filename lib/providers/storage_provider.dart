/// Storage provider type for marker assets
enum StorageProvider {
  ipfs, // Decentralized IPFS storage
  http, // Traditional HTTP/HTTPS hosting
  hybrid, // IPFS with HTTP gateway fallback
}

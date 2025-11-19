const axios = require('axios');
const FormData = require('form-data');
const logger = require('../utils/logger');

/**
 * Storage service with IPFS/HTTP abstraction
 * Easily switch between IPFS and HTTP storage via environment variable
 */
class StorageService {
  constructor() {
    this.provider = process.env.DEFAULT_STORAGE_PROVIDER || 'hybrid'; // 'ipfs', 'http', or 'hybrid'
    this.ipfsGateways = (process.env.IPFS_GATEWAY_URL || 'https://gateway.pinata.cloud/ipfs/').split(',');
    this.pinataApiKey = process.env.PINATA_API_KEY;
    this.pinataSecret = process.env.PINATA_SECRET;
    this.httpStoragePath = process.env.HTTP_STORAGE_PATH || './uploads';
    this.httpBaseUrl = process.env.HTTP_BASE_URL || 'http://localhost:3000/uploads';
    this.s3Enabled = process.env.S3_ENABLED === 'true';
  }

  /**
   * Upload file to storage (IPFS, HTTP, or both)
   */
  async uploadFile(fileBuffer, filename, metadata = {}) {
    const results = {};

    try {
      if (this.provider === 'ipfs' || this.provider === 'hybrid') {
        const ipfsResult = await this.uploadToIPFS(fileBuffer, filename, metadata);
        results.cid = ipfsResult.cid;
        results.ipfsUrl = ipfsResult.url;
        logger.info(`File uploaded to IPFS: ${results.cid}`);
      }

      if (this.provider === 'http' || this.provider === 'hybrid') {
        const httpResult = await this.uploadToHTTP(fileBuffer, filename, metadata);
        results.url = httpResult.url;
        results.path = httpResult.path;
        logger.info(`File uploaded to HTTP: ${results.url}`);
      }

      return results;
    } catch (error) {
      logger.error('Storage upload failed:', error);
      throw error;
    }
  }

  /**
   * Upload to IPFS via Pinata
   */
  async uploadToIPFS(fileBuffer, filename, metadata = {}) {
    if (!this.pinataApiKey || !this.pinataSecret) {
      throw new Error('Pinata API credentials not configured');
    }

    try {
      const formData = new FormData();
      formData.append('file', fileBuffer, { filename });

      // Add metadata
      const pinataMetadata = {
        name: filename,
        keyvalues: {
          ...metadata,
          uploadedAt: new Date().toISOString(),
        },
      };
      formData.append('pinataMetadata', JSON.stringify(pinataMetadata));

      const response = await axios.post(
        'https://api.pinata.cloud/pinning/pinFileToIPFS',
        formData,
        {
          headers: {
            'Content-Type': `multipart/form-data; boundary=${formData._boundary}`,
            'pinata_api_key': this.pinataApiKey,
            'pinata_secret_api_key': this.pinataSecret,
          },
          maxContentLength: Infinity,
          maxBodyLength: Infinity,
        }
      );

      const cid = response.data.IpfsHash;
      const url = `${this.ipfsGateways[0]}${cid}`;

      return { cid, url };
    } catch (error) {
      logger.error('IPFS upload failed:', error.response?.data || error.message);
      throw new Error(`IPFS upload failed: ${error.message}`);
    }
  }

  /**
   * Upload to HTTP storage (local or S3)
   */
  async uploadToHTTP(fileBuffer, filename, metadata = {}) {
    const fs = require('fs').promises;
    const path = require('path');
    const { v4: uuidv4 } = require('uuid');

    const uniqueFilename = `${uuidv4()}_${filename}`;
    // Support optional uploadFolder (e.g. 'profiles/avatars') so public URLs can be grouped
    const uploadFolder = metadata.uploadFolder ? String(metadata.uploadFolder).replace(/^\/+|\/+$/g, '') : '';
    const storageFolder = uploadFolder ? path.join(this.httpStoragePath, uploadFolder) : this.httpStoragePath;
    const filePath = uploadFolder ? path.join(storageFolder, uniqueFilename) : path.join(this.httpStoragePath, uniqueFilename);
    
    logger.info(`StorageService.uploadToHTTP: uploadFolder="${uploadFolder}", storageFolder="${storageFolder}", filePath="${filePath}"`);

    try {
      // Ensure upload directory exists
      await fs.mkdir(this.httpStoragePath, { recursive: true });

      // Ensure upload directory exists
      await fs.mkdir(storageFolder, { recursive: true });

      // Save file locally
      await fs.writeFile(filePath, fileBuffer);

      // If S3 is enabled, also upload to S3
      if (this.s3Enabled) {
        await this.uploadToS3(fileBuffer, uniqueFilename, metadata);
      }

      // Build public URL. If uploadFolder provided, include it in the public path.
      const publicPath = uploadFolder ? `${uploadFolder}/${uniqueFilename}` : uniqueFilename;
      const url = `${this.httpBaseUrl.replace(/\/$/, '')}/${publicPath}`;

      return { url, path: filePath };
    } catch (error) {
      logger.error('HTTP upload failed:', error);
      throw new Error(`HTTP upload failed: ${error.message}`);
    }
  }

  /**
   * Upload to S3-compatible storage
   */
  async uploadToS3(fileBuffer, filename, metadata = {}) {
    // S3 implementation would go here
    // Using AWS SDK or compatible library
    logger.info('S3 upload not implemented yet');
    return null;
  }

  /**
   * Get file from storage
   */
  async getFile(identifier, storageType = 'auto') {
    try {
      if (storageType === 'ipfs' || (storageType === 'auto' && identifier.startsWith('Qm'))) {
        return await this.getFromIPFS(identifier);
      } else {
        return await this.getFromHTTP(identifier);
      }
    } catch (error) {
      logger.error('File retrieval failed:', error);
      throw error;
    }
  }

  /**
   * Get file from IPFS
   */
  async getFromIPFS(cid) {
    // Try multiple gateways for redundancy
    for (const gateway of this.ipfsGateways) {
      try {
        const url = `${gateway}${cid}`;
        const response = await axios.get(url, {
          responseType: 'arraybuffer',
          timeout: 10000,
        });
        return response.data;
      } catch (error) {
        logger.warn(`Failed to retrieve from gateway ${gateway}: ${error.message}`);
        continue;
      }
    }
    throw new Error('Failed to retrieve file from all IPFS gateways');
  }

  /**
   * Get file from HTTP storage
   */
  async getFromHTTP(path) {
    const fs = require('fs').promises;
    try {
      return await fs.readFile(path);
    } catch (error) {
      throw new Error(`File not found: ${path}`);
    }
  }

  /**
   * Test IPFS gateway availability
   */
  async testIPFSGateway(gateway) {
    try {
      const testCid = 'QmTp2hEo8eXRp6wg7jXv1BLCMh5a4F3B2BSqPZ3bP3fzEr'; // Known test CID
      const response = await axios.head(`${gateway}${testCid}`, { timeout: 5000 });
      return response.status === 200;
    } catch (error) {
      return false;
    }
  }

  /**
   * Get storage statistics
   */
  async getStats() {
    const fs = require('fs').promises;
    const path = require('path');

    try {
      const files = await fs.readdir(this.httpStoragePath);
      let totalSize = 0;

      for (const file of files) {
        const stats = await fs.stat(path.join(this.httpStoragePath, file));
        totalSize += stats.size;
      }

      return {
        provider: this.provider,
        httpFiles: files.length,
        httpTotalSize: totalSize,
        httpStoragePath: this.httpStoragePath,
        ipfsGateways: this.ipfsGateways,
        s3Enabled: this.s3Enabled,
      };
    } catch (error) {
      logger.error('Failed to get storage stats:', error);
      return {
        provider: this.provider,
        error: error.message,
      };
    }
  }

  /**
   * Switch storage provider at runtime
   */
  setProvider(provider) {
    if (!['ipfs', 'http', 'hybrid'].includes(provider)) {
      throw new Error('Invalid storage provider. Must be: ipfs, http, or hybrid');
    }
    this.provider = provider;
    logger.info(`Storage provider switched to: ${provider}`);
  }

  /**
   * Get current provider
   */
  getProvider() {
    return this.provider;
  }
}

module.exports = new StorageService();

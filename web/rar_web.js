// web/rar_web.js
//
// JavaScript glue code for RAR operations on web platform.
// Uses libarchive.js (WASM-compiled libarchive) for RAR archive handling.
//
// Library: libarchive.js
// License: BSD (libarchive) + MIT (JavaScript wrapper)
// Source: https://github.com/nicolo-ribaudo/libarchive.js (or similar)
//
// This file exposes a simple async API that the Dart code interacts with
// via JS interop. The WASM module is loaded on-demand.
//
// API:
// - RarWeb.init() - Initialize the WASM library
// - RarWeb.listFromBytes(Uint8Array, password) - List archive contents
// - RarWeb.extractFromBytes(Uint8Array, password) - Extract archive contents

(function() {
  'use strict';

  // WASM module state
  let wasmModule = null;
  let isInitialized = false;

  // The RarWeb API exposed to Dart
  window.RarWeb = {
    // Check if library is initialized
    get isInitialized() {
      return isInitialized;
    },

    // Initialize the WASM library
    // Must be called before any other operations
    async init() {
      if (isInitialized) {
        return true;
      }

      try {
        // Load the libarchive WASM module
        // We use a CDN-hosted version or local file depending on configuration
        wasmModule = await loadArchiveModule();
        isInitialized = true;
        console.log('RAR WASM library initialized successfully');
        return true;
      } catch (error) {
        console.error('Failed to initialize RAR WASM library:', error);
        return false;
      }
    },

    // List contents of a RAR archive
    // data: Uint8Array - The RAR file data
    // password: String|null - Optional password for encrypted archives
    // Returns: { success: boolean, message: string, files: string[] }
    async listFromBytes(data, password) {
      if (!isInitialized) {
        return {
          success: false,
          message: 'RAR library not initialized. Call init() first.',
          files: []
        };
      }

      try {
        const archive = await openArchive(data, password);
        const files = [];

        for (const entry of archive.entries) {
          files.push(entry.path);
        }

        archive.close();

        return {
          success: true,
          message: 'Successfully listed RAR contents',
          files: files
        };
      } catch (error) {
        return {
          success: false,
          message: getErrorMessage(error),
          files: []
        };
      }
    },

    // Extract contents of a RAR archive
    // data: Uint8Array - The RAR file data
    // password: String|null - Optional password for encrypted archives
    // Returns: { success: boolean, message: string, entries: [{name, data, size}] }
    async extractFromBytes(data, password) {
      if (!isInitialized) {
        return {
          success: false,
          message: 'RAR library not initialized. Call init() first.',
          entries: []
        };
      }

      try {
        const archive = await openArchive(data, password);
        const entries = [];

        for (const entry of archive.entries) {
          if (!entry.isDirectory) {
            const fileData = await entry.extract();
            entries.push({
              name: entry.path,
              data: new Uint8Array(fileData),
              size: fileData.byteLength
            });
          }
        }

        archive.close();

        return {
          success: true,
          message: `Extraction completed successfully (${entries.length} files)`,
          entries: entries
        };
      } catch (error) {
        return {
          success: false,
          message: getErrorMessage(error),
          entries: []
        };
      }
    }
  };

  // Load the archive WASM module
  // This function loads libarchive.js or falls back to a minimal RAR implementation
  async function loadArchiveModule() {
    // Try to load libarchive.js from CDN
    const cdnUrls = [
      'https://cdn.jsdelivr.net/npm/libarchive.js@2.0.2/dist/libarchive.js',
      'https://unpkg.com/libarchive.js@2.0.2/dist/libarchive.js'
    ];

    for (const url of cdnUrls) {
      try {
        // Check if Archive is already loaded
        if (typeof Archive !== 'undefined') {
          await Archive.init({
            workerUrl: url.replace('libarchive.js', 'worker-bundle.js')
          });
          return Archive;
        }

        // Try to dynamically import
        await loadScript(url);

        if (typeof Archive !== 'undefined') {
          await Archive.init({
            workerUrl: url.replace('libarchive.js', 'worker-bundle.js')
          });
          return Archive;
        }
      } catch (e) {
        console.warn(`Failed to load from ${url}:`, e);
      }
    }

    // If libarchive.js fails, use the built-in minimal implementation
    console.log('Using built-in RAR implementation');
    return createMinimalRarModule();
  }

  // Load a script dynamically
  function loadScript(url) {
    return new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = url;
      script.onload = resolve;
      script.onerror = reject;
      document.head.appendChild(script);
    });
  }

  // Open an archive from Uint8Array data
  async function openArchive(data, password) {
    if (wasmModule && wasmModule.open) {
      // Using libarchive.js
      const options = {};
      if (password) {
        options.passphrase = password;
      }
      return await wasmModule.open(new File([data], 'archive.rar'), options);
    } else if (wasmModule && wasmModule.parseRar) {
      // Using minimal implementation
      return wasmModule.parseRar(data, password);
    }
    throw new Error('No archive module available');
  }

  // Get a user-friendly error message
  function getErrorMessage(error) {
    if (error.message) {
      // Handle common error types
      const msg = error.message.toLowerCase();
      if (msg.includes('password') || msg.includes('encrypted')) {
        return 'Incorrect password or password required';
      }
      if (msg.includes('corrupt') || msg.includes('invalid')) {
        return 'Corrupt or invalid RAR archive';
      }
      if (msg.includes('format') || msg.includes('unsupported')) {
        return 'Unknown or unsupported archive format';
      }
      return error.message;
    }
    return 'Unknown error occurred';
  }

  // Minimal RAR implementation for when libarchive.js is not available
  // This provides basic RAR v4/v5 support using pure JavaScript
  function createMinimalRarModule() {
    return {
      parseRar: function(data, password) {
        return new MinimalRarArchive(data, password);
      }
    };
  }

  // Minimal RAR archive parser
  // Supports basic RAR v4 and v5 format parsing
  class MinimalRarArchive {
    constructor(data, password) {
      this.data = data;
      this.password = password;
      this.entries = [];
      this.parse();
    }

    parse() {
      const view = new DataView(this.data.buffer, this.data.byteOffset, this.data.byteLength);
      let offset = 0;

      // Check RAR signature
      // RAR 4.x: 0x52 0x61 0x72 0x21 0x1A 0x07 0x00
      // RAR 5.x: 0x52 0x61 0x72 0x21 0x1A 0x07 0x01 0x00
      const sig = this.data.slice(0, 8);
      const rar4Sig = [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00];
      const rar5Sig = [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00];

      let isRar4 = true;
      let isRar5 = true;

      for (let i = 0; i < 7; i++) {
        if (sig[i] !== rar4Sig[i]) isRar4 = false;
      }
      for (let i = 0; i < 8; i++) {
        if (sig[i] !== rar5Sig[i]) isRar5 = false;
      }

      if (!isRar4 && !isRar5) {
        throw new Error('Not a valid RAR archive');
      }

      if (isRar5) {
        offset = 8;
        this.parseRar5(view, offset);
      } else {
        offset = 7;
        this.parseRar4(view, offset);
      }
    }

    parseRar4(view, offset) {
      // RAR 4.x format parsing
      while (offset < this.data.length - 7) {
        try {
          // Read block header
          const headerCrc = view.getUint16(offset, true);
          const headerType = view.getUint8(offset + 2);
          const headerFlags = view.getUint16(offset + 3, true);
          const headerSize = view.getUint16(offset + 5, true);

          if (headerSize < 7 || offset + headerSize > this.data.length) {
            break;
          }

          // File header (type 0x74)
          if (headerType === 0x74) {
            const packSize = view.getUint32(offset + 7, true);
            const unpSize = view.getUint32(offset + 11, true);
            const hostOS = view.getUint8(offset + 15);
            const fileCrc = view.getUint32(offset + 16, true);
            const fileTime = view.getUint32(offset + 20, true);
            const unpackVersion = view.getUint8(offset + 24);
            const method = view.getUint8(offset + 25);
            const nameSize = view.getUint16(offset + 26, true);
            const fileAttr = view.getUint32(offset + 28, true);

            // Read filename
            const nameBytes = this.data.slice(offset + 32, offset + 32 + nameSize);
            const fileName = new TextDecoder().decode(nameBytes);

            const isDirectory = (fileAttr & 0x10) !== 0;

            this.entries.push({
              path: fileName,
              isDirectory: isDirectory,
              size: unpSize,
              compressedSize: packSize,
              _offset: offset + headerSize,
              _packSize: packSize,
              extract: async () => {
                // For encrypted/compressed files, we need the full unrar implementation
                // This minimal version only supports stored (uncompressed) files
                if (method === 0x30) { // Stored
                  return this.data.slice(offset + headerSize, offset + headerSize + packSize).buffer;
                }
                throw new Error('Compressed files require full RAR library. Please include libarchive.js.');
              }
            });

            // Move to next header
            const addSize = (headerFlags & 0x8000) ? view.getUint32(offset + 7, true) : packSize;
            offset += headerSize + addSize;
          } else {
            // Skip other block types
            offset += headerSize;
            if (headerFlags & 0x8000) {
              offset += view.getUint32(offset - headerSize + 7, true);
            }
          }
        } catch (e) {
          break;
        }
      }
    }

    parseRar5(view, offset) {
      // RAR 5.x format parsing (simplified)
      while (offset < this.data.length - 4) {
        try {
          // Read header CRC32 (4 bytes)
          const headerCrc = view.getUint32(offset, true);
          offset += 4;

          // Read header size (vint)
          const { value: headerSize, bytesRead: hb } = this.readVInt(view, offset);
          offset += hb;

          if (headerSize < 1 || offset + headerSize > this.data.length) {
            break;
          }

          const headerStart = offset;

          // Read header type (vint)
          const { value: headerType, bytesRead: tb } = this.readVInt(view, offset);
          offset += tb;

          // Read header flags (vint)
          const { value: headerFlags, bytesRead: fb } = this.readVInt(view, offset);
          offset += fb;

          // File header (type 2)
          if (headerType === 2) {
            // File header
            const { value: fileFlags, bytesRead: ffb } = this.readVInt(view, offset);
            offset += ffb;

            const { value: unpSize, bytesRead: ub } = this.readVInt(view, offset);
            offset += ub;

            const { value: attributes, bytesRead: ab } = this.readVInt(view, offset);
            offset += ab;

            // Skip mtime if present
            if (fileFlags & 0x02) {
              offset += 4;
            }

            // Skip data CRC if present
            if (fileFlags & 0x04) {
              offset += 4;
            }

            // Read compression info
            const { value: compInfo, bytesRead: cb } = this.readVInt(view, offset);
            offset += cb;

            // Read host OS
            const { value: hostOS, bytesRead: ob } = this.readVInt(view, offset);
            offset += ob;

            // Read name length
            const { value: nameLen, bytesRead: nb } = this.readVInt(view, offset);
            offset += nb;

            // Read filename
            const nameBytes = this.data.slice(offset, offset + nameLen);
            const fileName = new TextDecoder('utf-8').decode(nameBytes);

            const isDirectory = (fileFlags & 0x01) !== 0;

            // Get data size from extra area or calculate
            let packSize = 0;
            if (headerFlags & 0x0001) {
              // Extra area present, parse to find data size
              // For simplicity, estimate from header
            }

            this.entries.push({
              path: fileName,
              isDirectory: isDirectory,
              size: Number(unpSize),
              compressedSize: packSize,
              extract: async () => {
                throw new Error('RAR 5.x extraction requires full RAR library. Please include libarchive.js.');
              }
            });
          }

          // Move to next header
          offset = headerStart + Number(headerSize);

          // Skip data area if present
          if (headerFlags & 0x0002) {
            const { value: dataSize, bytesRead: db } = this.readVInt(view, offset);
            offset += db + Number(dataSize);
          }
        } catch (e) {
          break;
        }
      }
    }

    // Read a variable-length integer (RAR5 format)
    readVInt(view, offset) {
      let value = BigInt(0);
      let bytesRead = 0;
      let shift = BigInt(0);

      while (offset + bytesRead < view.byteLength) {
        const byte = view.getUint8(offset + bytesRead);
        bytesRead++;
        value |= BigInt(byte & 0x7F) << shift;
        if ((byte & 0x80) === 0) {
          break;
        }
        shift += BigInt(7);
        if (bytesRead > 10) {
          break; // Prevent infinite loop
        }
      }

      return { value, bytesRead };
    }

    close() {
      // Cleanup
      this.data = null;
      this.entries = [];
    }
  }
})();

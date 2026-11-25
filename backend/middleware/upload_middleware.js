const multer = require('multer');

const ALLOWED_MIME_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
  'audio/mpeg',
  'audio/mp3',
  'audio/wav',
  'audio/ogg',
  'audio/mp4',
  'audio/aac',
  'audio/webm',
]);

const uploadQuestionFile = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 20 * 1024 * 1024,
    files: 1,
  },
  fileFilter: (req, file, callback) => {
    const mimeType = file.mimetype.toLowerCase();

    if (!ALLOWED_MIME_TYPES.has(mimeType)) {
      return callback(
        new Error('Định dạng file không được hỗ trợ')
      );
    }

    callback(null, true);
  },
});

module.exports = uploadQuestionFile;

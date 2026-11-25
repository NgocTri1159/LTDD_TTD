const { randomUUID } = require('crypto');
const supabase = require('../config/supabase');

const BUCKET_NAME = 'question-media';

const MIME_EXTENSIONS = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/gif': '.gif',
  'audio/mpeg': '.mp3',
  'audio/mp3': '.mp3',
  'audio/wav': '.wav',
  'audio/ogg': '.ogg',
  'audio/mp4': '.m4a',
  'audio/aac': '.aac',
  'audio/webm': '.webm',
};

const uploadQuestionMedia = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng chọn file cần upload',
      });
    }

    const mimeType = req.file.mimetype.toLowerCase();
    const extension = MIME_EXTENSIONS[mimeType];

    if (!extension) {
      return res.status(400).json({
        success: false,
        message: 'Định dạng file không được hỗ trợ',
      });
    }

    const category = mimeType.startsWith('image/')
      ? 'images'
      : 'audios';

    const filePath = `questions/${category}/${randomUUID()}${extension}`;

    const { data, error } = await supabase.storage
      .from(BUCKET_NAME)
      .upload(filePath, req.file.buffer, {
        contentType: mimeType,
        cacheControl: '3600',
        upsert: false,
      });

    if (error) {
      console.error('Supabase Storage upload error:', error.message);

      return res.status(500).json({
        success: false,
        message: 'Không thể upload file lên Supabase Storage',
      });
    }

    const { data: publicData } = supabase.storage
      .from(BUCKET_NAME)
      .getPublicUrl(data.path);

    return res.status(201).json({
      success: true,
      message: 'Upload file thành công',
      file: {
        path: data.path,
        fullPath: data.fullPath,
        url: publicData.publicUrl,
        mimeType,
        size: req.file.size,
      },
    });
  } catch (error) {
    console.error('Upload question media error:', error.message);

    return res.status(500).json({
      success: false,
      message: 'Lỗi máy chủ khi upload file',
    });
  }
};

const deleteQuestionMedia = async (req, res) => {
  try {
    const { path: filePath } = req.body || {};

    if (
      typeof filePath !== 'string' ||
      !/^questions\/(images|audios)\/[a-f0-9-]+\.(jpg|png|webp|gif|mp3|wav|ogg|m4a|aac|webm)$/i.test(filePath)
    ) {
      return res.status(400).json({
        success: false,
        message: 'Đường dẫn file không hợp lệ',
      });
    }

    const { error } = await supabase.storage
      .from(BUCKET_NAME)
      .remove([filePath]);

    if (error) {
      console.error('Supabase Storage delete error:', error.message);

      return res.status(500).json({
        success: false,
        message: 'Không thể xóa file khỏi Storage',
      });
    }

    return res.json({
      success: true,
      message: 'Xóa file thành công',
      path: filePath,
    });
  } catch (error) {
    console.error('Delete question media error:', error.message);

    return res.status(500).json({
      success: false,
      message: 'Lỗi máy chủ khi xóa file',
    });
  }
};

module.exports = {
  uploadQuestionMedia,
  deleteQuestionMedia,
};

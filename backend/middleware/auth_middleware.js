const { getAuth } = require('firebase-admin/auth');
const supabase = require('../config/supabase');

// ==========================================
// 1. XÁC THỰC FIREBASE ID TOKEN
// ==========================================

const verifyFirebaseToken = async (req, res, next) => {
  const authHeader = req.headers.authorization || '';
  const match = authHeader.match(/^Bearer (.+)$/);

  if (!match) {
    return res.status(401).json({
      success: false,
      message: 'Missing or invalid Authorization header',
    });
  }

  try {
    const decodedToken = await getAuth().verifyIdToken(
      match[1],
      true
    );

    req.auth = {
      uid: decodedToken.uid,
      email: decodedToken.email || null,
    };

    next();
  } catch (error) {
    console.error('Firebase token verification failed:', error.code);

    return res.status(401).json({
      success: false,
      message: 'Invalid, expired or revoked Firebase ID Token',
      errorCode: error.code || 'auth/invalid-token',
    });
  }
};

// ==========================================
// 2. KIỂM TRA THÔNG TIN VÀ TRẠNG THÁI USER
// ==========================================

const verifyUserStatus = async (req, res, next) => {
  try {
    if (!req.auth || !req.auth.uid) {
      return res.status(401).json({
        success: false,
        message: 'User authentication required',
      });
    }

    const { data: user, error } = await supabase
      .from('nguoi_dung')
      .select('id, email, ho_ten, vai_tro, trang_thai')
      .eq('id', req.auth.uid)
      .maybeSingle();

    if (error) {
      console.error('Supabase user lookup failed:', error.code);

      return res.status(503).json({
        success: false,
        message: 'Unable to verify user account',
      });
    }

    if (!user) {
      return res.status(403).json({
        success: false,
        message: 'User profile does not exist',
      });
    }

    if (user.trang_thai !== true) {
      return res.status(403).json({
        success: false,
        message: 'Your account has been disabled',
      });
    }

    // Chỉ sử dụng thông tin lấy từ Supabase
    req.user = {
      id: user.id,
      email: user.email,
      hoTen: user.ho_ten,
      vaiTro: user.vai_tro,
    };

    next();
  } catch (error) {
    console.error('User status verification error:', error.message);

    return res.status(500).json({
      success: false,
      message: 'Internal server error while verifying user',
    });
  }
};

// ==========================================
// 3. KIỂM TRA QUYỀN ADMIN
// ==========================================

const requireAdmin = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      success: false,
      message: 'Authentication required',
    });
  }

  const allowedRoles = ['admin', 'super_admin'];

  if (!allowedRoles.includes(req.user.vaiTro)) {
    return res.status(403).json({
      success: false,
      message: 'You do not have permission to access this resource',
    });
  }

  next();
};

module.exports = {
  verifyFirebaseToken,
  verifyUserStatus,
  requireAdmin,
};

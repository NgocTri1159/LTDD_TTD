const express = require('express');
const cors = require('cors');
const nodemailer = require('nodemailer');

const {
  initializeApp,
  applicationDefault,
} = require('firebase-admin/app');

const { getAuth } = require('firebase-admin/auth');

// ==========================================
// 1. NẠP BIẾN MÔI TRƯỜNG
// ==========================================

require('dotenv').config();

// ==========================================
// 2. IMPORT SUPABASE VÀ MIDDLEWARE
// ==========================================

const supabase = require('./config/supabase');

const {
  verifyFirebaseToken,
  verifyUserStatus,
  requireAdmin,
} = require('./middleware/auth_middleware');

// ==========================================
// 3. KHỞI TẠO FIREBASE ADMIN
// ==========================================

initializeApp({
  credential: applicationDefault(),
  projectId: process.env.FIREBASE_PROJECT_ID || 'ltdd-appquizz-master',
});

const auth = getAuth();

// ==========================================
// 4. KHỞI TẠO EXPRESS & MAILER
// ==========================================

const app = express();

app.use(cors());
app.use(express.json());

const otpStore = new Map();

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.SMTP_EMAIL,
    pass: process.env.SMTP_PASSWORD,
  },
});

async function isAdminAccount(email) {
  const { data, error } = await supabase
    .from('nguoi_dung')
    .select('vai_tro')
    .ilike('email', email)
    .maybeSingle();

  if (error || !data) return false;
  return data.vai_tro === 'admin' || data.vai_tro === 'super_admin';
}

// ==========================================
// 5.5. ĐĂNG KÝ ROUTER SUBJECT
// ==========================================
const subjectRoutes = require('./routes/subject.routes');
app.use('/api/subjects', subjectRoutes);

// Question and Storage API
const questionRoutes = require('./routes/question.routes');
app.use('/api/questions', questionRoutes);

// Quiz and Attempt API
const quizRoutes = require('./routes/quiz.routes');
app.use('/api/quiz', quizRoutes);

// ==========================================
// 5. KIỂM TRA BACKEND
// ==========================================

app.get('/', (req, res) => {
  return res.json({
    success: true,
    message: 'QuizMaster Backend is running!',
    status: 'success',
  });
});

// ==========================================
// 6. KIỂM TRA KẾT NỐI SUPABASE
// ==========================================

app.get('/health/supabase', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('mon_hoc')
      .select('id')
      .limit(1);

    if (error) {
      console.error(
        'Supabase health check failed:',
        error.code,
        error.message
      );

      return res.status(503).json({
        success: false,
        message: 'Supabase connection failed',
      });
    }

    return res.json({
      success: true,
      message: 'Supabase connection is healthy',
      table: 'mon_hoc',
      rowsReturned: data.length,
    });
  } catch (error) {
    console.error('Supabase health check error:', error.message);

    return res.status(503).json({
      success: false,
      message: 'Supabase service unavailable',
    });
  }
});

// ==========================================
// 7. CẤP CUSTOM CLAIM AUTHENTICATED
// ==========================================

app.post('/auth/provision-role', async (req, res) => {
  const authHeader = req.headers.authorization || '';
  const match = authHeader.match(/^Bearer (.+)$/);

  if (!match) {
    return res.status(401).json({
      success: false,
      message: 'Missing Firebase ID Token',
    });
  }

  try {
    const decodedToken = await auth.verifyIdToken(match[1]);
    const user = await auth.getUser(decodedToken.uid);

    await auth.setCustomUserClaims(decodedToken.uid, {
      ...(user.customClaims || {}),
      role: 'authenticated',
    });

    const updatedUser = await auth.getUser(decodedToken.uid);

    console.log('========== FIREBASE CUSTOM CLAIM ==========');
    console.log('UID:', decodedToken.uid);
    console.log('ROLE:', updatedUser.customClaims?.role);
    console.log('===========================================');

    return res.json({
      success: true,
      message: 'Cap quyen thanh cong',
      role: updatedUser.customClaims?.role ?? null,
    });
  } catch (error) {
    console.error('========== FIREBASE AUTH ERROR ==========');
    console.error('ERROR CODE:', error.code);
    console.error('ERROR MESSAGE:', error.message);
    console.error('==========================================');

    return res.status(401).json({
      success: false,
      message: error.message || 'Firebase token khong hop le',
      errorCode: error.code || 'unknown',
    });
  }
});

// ==========================================
// 7.5. API GỬI OTP & ĐẶT LẠI MẬT KHẨU QUA EMAIL
// ==========================================

app.post('/api/auth/send-reset-otp', async (req, res) => {
  try {
    const email = (req.body.email || '').trim().toLowerCase();
    if (!email) {
      return res.status(400).json({ success: false, message: 'Vui lòng nhập email.' });
    }

    if (await isAdminAccount(email)) {
      return res.status(403).json({
        success: false,
        message: 'Tài khoản Quản trị viên không được phép đổi hoặc đặt lại mật khẩu.',
      });
    }

    // Kiểm tra email có tồn tại trên Firebase Auth
    await auth.getUserByEmail(email);

    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    otpStore.set(email, {
      otp,
      expiresAt: Date.now() + 5 * 60 * 1000, // Hết hạn sau 5 phút
    });

    await transporter.sendMail({
      from: `"Fhasarid - QuizMaster" <${process.env.SMTP_EMAIL}>`,
      to: email,
      subject: 'Mã xác nhận đặt lại mật khẩu',
      html: `
        <div style="font-family: Arial, sans-serif; padding: 20px; color: #1A1D3B;">
          <h2>Đặt lại mật khẩu tài khoản</h2>
          <p>Mã xác nhận gồm 4 chữ số của bạn là:</p>
          <div style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #565CEB; margin: 16px 0;">
            ${otp}
          </div>
          <p>Mã có hiệu lực trong <b>5 phút</b>. Vui lòng không chia sẻ mã này cho bất kỳ ai.</p>
        </div>
      `,
    });

    return res.json({
      success: true,
      message: 'Đã gửi mã xác nhận gồm 4 chữ số tới email.',
    });
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      return res.status(404).json({
        success: false,
        message: 'Email này chưa được đăng ký tài khoản.',
      });
    }
    console.error('SEND OTP ERROR:', error);
    return res.status(500).json({
      success: false,
      message: 'Không thể gửi email: ' + error.message,
    });
  }
});

app.post('/api/auth/verify-reset-otp', (req, res) => {
  const email = (req.body.email || '').trim().toLowerCase();
  const otp = (req.body.otp || '').trim();

  const record = otpStore.get(email);
  if (!record) {
    return res.status(400).json({
      success: false,
      message: 'Bạn chưa yêu cầu gửi mã hoặc mã đã hết hạn.',
    });
  }
  if (Date.now() > record.expiresAt) {
    otpStore.delete(email);
    return res.status(400).json({
      success: false,
      message: 'Mã xác nhận đã hết hạn. Vui lòng gửi lại mã mới.',
    });
  }
  if (record.otp !== otp) {
    return res.status(400).json({
      success: false,
      message: 'Mã xác nhận không chính xác.',
    });
  }

  return res.json({
    success: true,
    message: 'Xác thực mã thành công.',
  });
});

app.post('/api/auth/reset-password-with-otp', async (req, res) => {
  try {
    const email = (req.body.email || '').trim().toLowerCase();
    const otp = (req.body.otp || '').trim();
    const newPassword = req.body.newPassword || '';

    if (await isAdminAccount(email)) {
      return res.status(403).json({
        success: false,
        message: 'Tài khoản Quản trị viên không được phép đổi hoặc đặt lại mật khẩu.',
      });
    }

    const record = otpStore.get(email);
    if (!record || Date.now() > record.expiresAt || record.otp !== otp) {
      return res.status(400).json({
        success: false,
        message: 'Phiên xác thực không hợp lệ hoặc đã hết hạn.',
      });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Mật khẩu mới phải có ít nhất 6 ký tự.',
      });
    }

    const userRecord = await auth.getUserByEmail(email);
    await auth.updateUser(userRecord.uid, { password: newPassword });

    otpStore.delete(email);

    return res.json({
      success: true,
      message: 'Đặt lại mật khẩu thành công!',
    });
  } catch (error) {
    console.error('RESET PASSWORD ERROR:', error);
    return res.status(500).json({
      success: false,
      message: 'Lỗi cập nhật mật khẩu: ' + error.message,
    });
  }
});

// ==========================================
// 8. API KIỂM TRA THÔNG TIN NGƯỜI DÙNG
// ==========================================

app.get(
  '/api/auth/me',
  verifyFirebaseToken,
  verifyUserStatus,
  (req, res) => {
    return res.json({
      success: true,
      message: 'User authenticated successfully',
      user: req.user,
    });
  }
);

// ==========================================
// 9. API KIỂM TRA QUYỀN ADMIN
// ==========================================

app.get(
  '/api/auth/admin-check',
  verifyFirebaseToken,
  verifyUserStatus,
  requireAdmin,
  (req, res) => {
    return res.json({
      success: true,
      message: 'Admin authorization successful',
      user: req.user,
    });
  }
);

// ==========================================
// 10. KHỞI ĐỘNG SERVER
// ==========================================

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log('==========================================');
  console.log(`QuizMaster Backend running on port ${PORT}`);
  console.log('Firebase Admin: Initialized');
  console.log('Supabase Client: Initialized');
  console.log('Authentication Middleware: Loaded');
  console.log('==========================================');
});
const express = require('express');
const cors = require('cors');

const {
  initializeApp,
  applicationDefault,
} = require('firebase-admin/app');

const { getAuth } = require('firebase-admin/auth');

// ==========================================
// 1. Náº P BIáº¾N MÃ”I TRÆ¯á»œNG
// ==========================================

require('dotenv').config();

// ==========================================
// 2. IMPORT SUPABASE VÃ€ MIDDLEWARE
// ==========================================

const supabase = require('./config/supabase');

const {
  verifyFirebaseToken,
  verifyUserStatus,
  requireAdmin,
} = require('./middleware/auth_middleware');

// ==========================================
// 3. KHá»žI Táº O FIREBASE ADMIN
// ==========================================

initializeApp({
  credential: applicationDefault(),
  projectId: process.env.FIREBASE_PROJECT_ID || 'ltdd-appquizz-master',
});

const auth = getAuth();

// ==========================================
// 4. KHá»žI Táº O EXPRESS
// ==========================================

const app = express();

app.use(cors());
app.use(express.json());

// ==========================================
// 5.5. ÄÄ‚NG KÃ ROUTER SUBJECT
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
// 5. KIá»‚M TRA BACKEND
// ==========================================

app.get('/', (req, res) => {
  return res.json({
    success: true,
    message: 'QuizMaster Backend is running!',
    status: 'success',
  });
});

// ==========================================
// 6. KIá»‚M TRA Káº¾T Ná»I SUPABASE
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
// 7. Cáº¤P CUSTOM CLAIM AUTHENTICATED
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
    // XÃ¡c thá»±c Firebase ID Token
    const decodedToken = await auth.verifyIdToken(match[1]);

    // Láº¥y thÃ´ng tin tÃ i khoáº£n
    const user = await auth.getUser(decodedToken.uid);

    // Cáº¥p Custom Claim authenticated
    await auth.setCustomUserClaims(decodedToken.uid, {
      ...(user.customClaims || {}),
      role: 'authenticated',
    });

    // Äá»c láº¡i tÃ i khoáº£n Ä‘á»ƒ kiá»ƒm tra
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
// 8. API KIá»‚M TRA THÃ”NG TIN NGÆ¯á»œI DÃ™NG
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
// 9. API KIá»‚M TRA QUYá»€N ADMIN
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
// 10. KHá»žI Äá»˜NG SERVER
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

